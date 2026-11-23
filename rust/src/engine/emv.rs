use std::collections::HashMap;
use std::future::Future;
use crate::api::models::{CardNetwork, SafeCardModel};
use crate::engine::bin_db::resolve_bank_and_network;
use crate::engine::raw_card::RawEmvCard;
use crate::engine::tlv::{format_bcd_date, parse_tlv, parse_track_2, EmvTag};

const RUPAY_DEBIT_AID: &[u8] = &[0xA0, 0x00, 0x00, 0x05, 0x24, 0x10, 0x10];
const RUPAY_QSPARC_AID: &[u8] = &[0xA0, 0x00, 0x00, 0x05, 0x24, 0x10, 0x11];
const VISA_AID: &[u8] = &[0xA0, 0x00, 0x00, 0x00, 0x03, 0x10, 0x10];
const MASTERCARD_AID: &[u8] = &[0xA0, 0x00, 0x00, 0x00, 0x04, 0x10, 0x10];
const PPSE_NAME: &[u8] = b"2PAY.SYS.DDF01";

pub struct EmvEngine<F> {
    transceiver: F,
}

impl<F, Fut> EmvEngine<F>
where
    F: Fn(Vec<u8>) -> Fut,
    Fut: Future<Output = Vec<u8>>,
{
    pub fn new(transceiver: F) -> Self {
        Self { transceiver }
    }

    /// Smart transceiver that automatically handles ISO 7816 status words:
    /// - 6C xx: Resends command with correct Le = xx
    /// - 61 xx: Sends GET RESPONSE (00 C0 00 00 xx) to fetch available payload
    async fn transceive_apdu(&self, mut apdu: Vec<u8>) -> Vec<u8> {
        let resp = (self.transceiver)(apdu.clone()).await;
        if resp.len() < 2 {
            return resp;
        }

        let sw1 = resp[resp.len() - 2];
        let sw2 = resp[resp.len() - 1];

        // 6C xx: Wrong length -> card asks to resend with Le = sw2
        if sw1 == 0x6C && !apdu.is_empty() {
            *apdu.last_mut().unwrap() = sw2;
            return (self.transceiver)(apdu).await;
        }

        // 61 xx: Response bytes available -> fetch with GET RESPONSE
        if sw1 == 0x61 {
            let get_resp_apdu = vec![0x00, 0xC0, 0x00, 0x00, sw2];
            let full_resp = (self.transceiver)(get_resp_apdu).await;
            if full_resp.len() >= 2 && is_success(&full_resp) {
                return full_resp;
            }
        }

        resp
    }

    pub async fn execute_session(&self) -> Result<SafeCardModel, String> {
        let mut aids_to_try = Vec::new();

        // Step 1: SELECT PPSE
        if let Ok(aid) = self.select_ppse().await {
            aids_to_try.push(aid.clone());
            if aid == RUPAY_DEBIT_AID {
                aids_to_try.push(RUPAY_QSPARC_AID.to_vec());
            }
        } else {
            aids_to_try.push(RUPAY_DEBIT_AID.to_vec());
            aids_to_try.push(RUPAY_QSPARC_AID.to_vec());
            aids_to_try.push(VISA_AID.to_vec());
            aids_to_try.push(MASTERCARD_AID.to_vec());
        }

        let mut last_err = String::from("No readable payment record found");

        for aid in aids_to_try {
            match self.execute_session_for_aid(&aid).await {
                Ok(card) => return Ok(card),
                Err(e) => last_err = e,
            }
        }

        Err(last_err)
    }

    async fn execute_session_for_aid(&self, aid: &[u8]) -> Result<SafeCardModel, String> {
        // Step 2: SELECT AID
        let (fci_tlv, selected_aid) = self.select_aid(aid).await?;

        let mut app_label = String::from("Contactless Card");
        if let Some(label_bytes) = fci_tlv.get(&EmvTag(vec![0x50])) {
            if let Ok(label) = String::from_utf8(label_bytes.clone()) {
                app_label = label.trim().to_string();
            }
        }

        let mut collected_tlv = HashMap::new();
        collected_tlv.extend(fci_tlv.clone());

        // Step 3: GET PROCESSING OPTIONS (GPO)
        match self.get_processing_options(&fci_tlv).await {
            Ok(gpo_response) => {
                let gpo_tlv = parse_tlv(&gpo_response);
                collected_tlv.extend(gpo_tlv.clone());

                // Step 4: Read AFL Records
                if let Some(afl_bytes) = gpo_tlv.get(&EmvTag(vec![0x94])) {
                    let _ = self.read_afl_records(afl_bytes, &mut collected_tlv).await;
                } else if let Some(resp_80) = gpo_tlv.get(&EmvTag(vec![0x80])) {
                    if resp_80.len() > 2 {
                        let _ = self.read_afl_records(&resp_80[2..], &mut collected_tlv).await;
                    }
                } else {
                    self.read_default_records(&mut collected_tlv).await;
                }
            }
            Err(_) => {
                // If GPO was rejected by card, gracefully fallback to probing default public records
                self.read_default_records(&mut collected_tlv).await;
            }
        }

        // Step 5: Build Raw Card from collected records
        let raw_card = self.build_raw_card(selected_aid, app_label, &collected_tlv)?;
        let (issuer_bank, network) = resolve_bank_and_network(&raw_card.pan);
        let supports_qsparc = raw_card.aid.contains("A0000005241011")
            || raw_card.app_label.to_lowercase().contains("qsparc");

        let mut safe_card = raw_card.to_safe(issuer_bank, supports_qsparc);
        if safe_card.network == CardNetwork::Unknown {
            safe_card.network = network;
        }

        Ok(safe_card)
    }

    async fn select_ppse(&self) -> Result<Vec<u8>, String> {
        let mut apdu = vec![0x00, 0xA4, 0x04, 0x00, PPSE_NAME.len() as u8];
        apdu.extend_from_slice(PPSE_NAME);
        apdu.push(0x00);

        let response = self.transceive_apdu(apdu).await;
        if response.len() < 2 || !is_success(&response) {
            return Err("PPSE not found".to_string());
        }

        let tlv = parse_tlv(&response);
        if let Some(aid) = tlv.get(&EmvTag(vec![0x4F])) {
            return Ok(aid.clone());
        }

        Err("No AID in PPSE".to_string())
    }

    async fn select_aid(&self, aid: &[u8]) -> Result<(HashMap<EmvTag, Vec<u8>>, Vec<u8>), String> {
        let mut apdu = vec![0x00, 0xA4, 0x04, 0x00, aid.len() as u8];
        apdu.extend_from_slice(aid);
        apdu.push(0x00);

        let response = self.transceive_apdu(apdu).await;
        if response.len() < 2 || !is_success(&response) {
            for fallback in [RUPAY_DEBIT_AID, RUPAY_QSPARC_AID, VISA_AID, MASTERCARD_AID] {
                let mut fallback_apdu = vec![0x00, 0xA4, 0x04, 0x00, fallback.len() as u8];
                fallback_apdu.extend_from_slice(fallback);
                fallback_apdu.push(0x00);

                let resp = self.transceive_apdu(fallback_apdu).await;
                if is_success(&resp) {
                    return Ok((parse_tlv(&resp), fallback.to_vec()));
                }
            }
            return Err("Failed to select payment AID".to_string());
        }

        Ok((parse_tlv(&response), aid.to_vec()))
    }

    async fn get_processing_options(
        &self,
        fci_tlv: &HashMap<EmvTag, Vec<u8>>,
    ) -> Result<Vec<u8>, String> {
        let mut pdol_data = Vec::new();
        if let Some(pdol) = fci_tlv.get(&EmvTag(vec![0x9F, 0x38])) {
            pdol_data = self.construct_pdol_data(pdol, false);
        }

        // Try standard GPO with Le = 0x00
        let mut apdu = vec![0x80, 0xA8, 0x00, 0x00];
        let len = (pdol_data.len() + 2) as u8;
        apdu.push(len);
        apdu.push(0x83);
        apdu.push(pdol_data.len() as u8);
        apdu.extend_from_slice(&pdol_data);
        apdu.push(0x00);

        let mut response = self.transceive_apdu(apdu.clone()).await;

        // Fallback 1: If rejected (e.g. 6987), retry with alternative RuPay DF3A
        if response.len() < 2 || !is_success(&response) {
            if let Some(pdol) = fci_tlv.get(&EmvTag(vec![0x9F, 0x38])) {
                let alt_data = self.construct_pdol_data(pdol, true);
                let mut alt_apdu = vec![0x80, 0xA8, 0x00, 0x00];
                alt_apdu.push((alt_data.len() + 2) as u8);
                alt_apdu.push(0x83);
                alt_apdu.push(alt_data.len() as u8);
                alt_apdu.extend_from_slice(&alt_data);
                alt_apdu.push(0x00);
                let resp_alt = self.transceive_apdu(alt_apdu).await;
                if resp_alt.len() >= 2 && is_success(&resp_alt) {
                    response = resp_alt;
                }
            }
        }

        // Fallback 2: Retry without trailing Le byte if card rejected Le = 0x00
        if response.len() < 2 || !is_success(&response) {
            let mut apdu_no_le = apdu;
            apdu_no_le.pop();
            let resp2 = self.transceive_apdu(apdu_no_le).await;
            if resp2.len() >= 2 && is_success(&resp2) {
                response = resp2;
            }
        }

        // Fallback 3: Retry with empty GPO (80 A8 00 00 02 83 00 00)
        if response.len() < 2 || !is_success(&response) {
            let empty_gpo = vec![0x80, 0xA8, 0x00, 0x00, 0x02, 0x83, 0x00, 0x00];
            let resp3 = self.transceive_apdu(empty_gpo).await;
            if resp3.len() >= 2 && is_success(&resp3) {
                response = resp3;
            }
        }

        if response.len() < 2 || !is_success(&response) {
            let sw = if response.len() >= 2 {
                format!("{:02X}{:02X}", response[response.len() - 2], response[response.len() - 1])
            } else {
                "NO_DATA".to_string()
            };
            return Err(format!("GPO failed (SW: {})", sw));
        }

        Ok(response)
    }

    fn construct_pdol_data(&self, pdol: &[u8], alt_mode: bool) -> Vec<u8> {
        let mut result = Vec::new();
        let mut cursor = 0;

        while cursor < pdol.len() {
            let tag_first = pdol[cursor];
            cursor += 1;

            let mut tag_bytes = vec![tag_first];
            if (tag_first & 0x1F) == 0x1F {
                while cursor < pdol.len() {
                    let next = pdol[cursor];
                    cursor += 1;
                    tag_bytes.push(next);
                    if (next & 0x80) == 0 {
                        break;
                    }
                }
            }

            if cursor >= pdol.len() {
                break;
            }

            let len = pdol[cursor] as usize;
            cursor += 1;

            let tag_hex = EmvTag(tag_bytes).hex();
            match tag_hex.as_str() {
                "9F40" => {
                    // Additional Terminal Capabilities (ATC)
                    let mut val = vec![0x60, 0x00, 0xF0, 0xA0, 0x01];
                    val.resize(len, 0x00);
                    result.extend_from_slice(&val);
                }
                "9F33" => {
                    // Terminal Capabilities (Terminal type 22, offline/online chip, PIN/signature)
                    let mut val = vec![0xE0, 0xF8, 0xC8];
                    val.resize(len, 0x00);
                    result.extend_from_slice(&val);
                }
                "DF3A" => {
                    // RuPay Additional Terminal Capabilities Extension
                    let mut val = if alt_mode {
                        vec![0x00, 0x00, 0x00, 0x00, 0x00]
                    } else {
                        vec![0x20, 0x00, 0x00, 0x00, 0x00]
                    };
                    val.resize(len, 0x00);
                    result.extend_from_slice(&val);
                }
                "DF16" => {
                    // RuPay Service ID
                    let mut val = vec![0x00, 0x00];
                    val.resize(len, 0x00);
                    result.extend_from_slice(&val);
                }
                "9F09" => {
                    // Application Version Number
                    let mut val = vec![0x00, 0x02];
                    val.resize(len, 0x00);
                    result.extend_from_slice(&val);
                }
                "9F15" => {
                    // Merchant Category Code
                    let mut val = vec![0x60, 0x11];
                    val.resize(len, 0x00);
                    result.extend_from_slice(&val);
                }
                "9F21" => {
                    // Transaction Time HHMMSS
                    result.extend_from_slice(&[0x12, 0x00, 0x00]);
                }
                "9F1C" => {
                    // Terminal Identification (IFD Serial Number - 8 bytes ASCII)
                    let mut val = b"12345678".to_vec();
                    val.resize(len, 0x30);
                    result.extend_from_slice(&val);
                }
                "9F66" => {
                    // Terminal Transaction Qualifiers (TTQ) - Contactless EMV mode
                    let mut val = vec![0x20, 0x00, 0x00, 0x00];
                    val.resize(len, 0x00);
                    result.extend_from_slice(&val);
                }
                "9F02" | "9F03" => {
                    result.resize(result.len() + len, 0x00);
                }
                "9F1A" | "5F2A" => {
                    let mut val = vec![0x03, 0x56];
                    val.resize(len, 0x00);
                    result.extend_from_slice(&val);
                }
                "9A" => {
                    result.extend_from_slice(&[0x26, 0x11, 0x23]);
                }
                "9C" => {
                    result.push(0x00);
                }
                "9F37" => {
                    let mut rand = [0u8; 4];
                    let _ = getrandom::fill(&mut rand);
                    result.extend_from_slice(&rand);
                }
                _ => {
                    result.resize(result.len() + len, 0x00);
                }
            }
        }

        result
    }

    async fn read_afl_records(
        &self,
        afl: &[u8],
        collected: &mut HashMap<EmvTag, Vec<u8>>,
    ) -> Result<(), String> {
        let mut cursor = 0;
        while cursor + 4 <= afl.len() {
            let sfi_byte = afl[cursor];
            let start_rec = afl[cursor + 1];
            let end_rec = afl[cursor + 2];
            cursor += 4;

            let sfi = (sfi_byte >> 3) & 0x1F;
            for rec in start_rec..=end_rec {
                let apdu = vec![0x00, 0xB2, rec, (sfi << 3) | 0x04, 0x00];
                let resp = self.transceive_apdu(apdu).await;
                if is_success(&resp) {
                    let parsed = parse_tlv(&resp);
                    collected.extend(parsed);
                }
            }
        }
        Ok(())
    }

    async fn read_default_records(&self, collected: &mut HashMap<EmvTag, Vec<u8>>) {
        // Search across SFIs 1 to 4, records 1 to 10
        for sfi in 1..=4 {
            for rec in 1..=10 {
                let apdu = vec![0x00, 0xB2, rec, (sfi << 3) | 0x04, 0x00];
                let resp = self.transceive_apdu(apdu).await;
                if is_success(&resp) {
                    let parsed = parse_tlv(&resp);
                    collected.extend(parsed);
                }
            }
        }
    }

    fn build_raw_card(
        &self,
        aid_bytes: Vec<u8>,
        app_label: String,
        tlv: &HashMap<EmvTag, Vec<u8>>,
    ) -> Result<RawEmvCard, String> {
        let mut pan = String::new();
        let mut expiry_date = String::from("MM/YY");
        let mut service_code = None;

        // 1. Tag 57: Track 2 Equivalent Data
        if let Some(track2_bytes) = tlv.get(&EmvTag(vec![0x57])) {
            if let Some((t2_pan, t2_exp, sc)) = parse_track_2(track2_bytes) {
                pan = t2_pan;
                expiry_date = t2_exp;
                service_code = sc;
            }
        }

        // 2. Tag 9F6B: Contactless Track 2 Data
        if pan.is_empty() {
            if let Some(track2_bytes) = tlv.get(&EmvTag(vec![0x9F, 0x6B])) {
                if let Some((t2_pan, t2_exp, sc)) = parse_track_2(track2_bytes) {
                    pan = t2_pan;
                    expiry_date = t2_exp;
                    service_code = sc;
                }
            }
        }

        // 3. Tag 5A: Application Primary Account Number (PAN)
        if pan.is_empty() {
            if let Some(pan_bytes) = tlv.get(&EmvTag(vec![0x5A])) {
                let hex_pan: String = pan_bytes.iter().map(|b| format!("{:02X}", b)).collect();
                pan = hex_pan.trim_end_matches('F').to_string();
            }
        }

        // 4. Tag 56: Track 1 Data
        if pan.is_empty() {
            if let Some(t1_bytes) = tlv.get(&EmvTag(vec![0x56])) {
                let s = String::from_utf8_lossy(t1_bytes);
                if let Some(idx) = s.find('^') {
                    let candidate = s[..idx].trim_start_matches(|c: char| !c.is_ascii_digit());
                    if candidate.len() >= 12 && candidate.len() <= 19 {
                        pan = candidate.to_string();
                    }
                }
            }
        }

        if pan.is_empty() {
            let tags_found: Vec<String> = tlv.keys().map(|t| t.hex()).collect();
            return Err(format!(
                "Card read successfully, but no PAN tag found. Available tags: {:?}",
                tags_found
            ));
        }

        if expiry_date == "MM/YY" {
            if let Some(exp_bytes) = tlv.get(&EmvTag(vec![0x5F, 0x24])) {
                if let Some(formatted) = format_bcd_date(exp_bytes) {
                    expiry_date = formatted;
                }
            }
        }

        let cardholder_name = tlv.get(&EmvTag(vec![0x5F, 0x20])).and_then(|bytes| {
            String::from_utf8(bytes.clone())
                .ok()
                .map(|s| s.trim().to_string())
        });

        let valid_from = tlv
            .get(&EmvTag(vec![0x5F, 0x25]))
            .and_then(|b| format_bcd_date(b));

        let is_domestic_only = tlv.get(&EmvTag(vec![0x5F, 0x28])).map_or(true, |c| {
            c == &[0x03, 0x56] || c == &[0x35, 0x60]
        });

        let aid_hex: String = aid_bytes.iter().map(|b| format!("{:02X}", b)).collect();

        Ok(RawEmvCard {
            network: CardNetwork::RuPay,
            aid: aid_hex,
            app_label,
            pan,
            cardholder_name,
            valid_from,
            expiry_date,
            service_code,
            is_domestic_only,
        })
    }
}

fn is_success(response: &[u8]) -> bool {
    if response.len() < 2 {
        return false;
    }
    let sw1 = response[response.len() - 2];
    let sw2 = response[response.len() - 1];
    (sw1 == 0x90 && sw2 == 0x00) || sw1 == 0x61 || sw1 == 0x6C
}
