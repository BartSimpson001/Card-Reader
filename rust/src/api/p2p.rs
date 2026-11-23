use crate::engine::p2p::{build_select_aid_apdu, P2pPacket};
use flutter_rust_bridge::DartFnFuture;

#[derive(Debug, Clone, PartialEq)]
pub struct SafeP2pMessage {
    pub message: String,
    pub device_name: String,
}

/// Encodes message and device name into TLV bytes for HCE transmission.
pub fn encode_p2p_payload(message: String, device_name: String) -> Vec<u8> {
    let packet = P2pPacket::new(message, device_name);
    packet.to_bytes()
}

/// Transceives the SELECT AID APDU with the sender phone and returns the parsed message.
pub async fn receive_p2p_message(
    transceiver: impl Fn(Vec<u8>) -> DartFnFuture<Vec<u8>>,
) -> Result<SafeP2pMessage, String> {
    let apdu = build_select_aid_apdu();
    let response = transceiver(apdu).await;

    if response.len() < 2 {
        return Err("NFC Response too short".to_string());
    }

    let status_word = &response[response.len() - 2..];
    if status_word != [0x90, 0x00] {
        return Err(format!(
            "P2P Device rejected SELECT AID: SW={:02X}{:02X}",
            status_word[0], status_word[1]
        ));
    }

    let payload_bytes = &response[..response.len() - 2];
    let packet = P2pPacket::from_bytes(payload_bytes)?;

    Ok(SafeP2pMessage {
        message: packet.message,
        device_name: packet.device_name,
    })
}
