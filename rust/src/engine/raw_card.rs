use zeroize::{Zeroize, ZeroizeOnDrop};
use crate::api::models::{CardNetwork, SafeCardModel};

/// Internal sensitive model: Automatically wipes PAN from RAM when dropped
#[derive(Zeroize, ZeroizeOnDrop)]
pub struct RawEmvCard {
    #[zeroize(skip)]
    pub network: CardNetwork,
    #[zeroize(skip)]
    pub aid: String,
    #[zeroize(skip)]
    pub app_label: String,
    pub pan: String,
    pub cardholder_name: Option<String>,
    pub valid_from: Option<String>,
    pub expiry_date: String,
    pub service_code: Option<String>,
    pub is_domestic_only: bool,
}

impl RawEmvCard {
    pub fn to_safe(&self, issuer_bank: String, supports_qsparc: bool) -> SafeCardModel {
        let last_four = if self.pan.len() >= 4 {
            self.pan[self.pan.len() - 4..].to_string()
        } else {
            "****".to_string()
        };

        let first_four = if self.pan.len() >= 4 {
            &self.pan[0..4]
        } else {
            "****"
        };

        let masked_pan = format!("{} •••• •••• {}", first_four, last_four);

        let cardholder_name = match &self.cardholder_name {
            Some(name) if name.trim().is_empty() || name.trim() == "/" => "CARDHOLDER".to_string(),
            Some(name) => name.trim().to_string(),
            None => "CARDHOLDER".to_string(),
        };

        SafeCardModel {
            network: self.network.clone(),
            issuer_bank,
            app_label: self.app_label.clone(),
            masked_pan,
            last_four,
            cardholder_name,
            valid_from: self.valid_from.clone(),
            expiry_date: self.expiry_date.clone(),
            is_domestic_only: self.is_domestic_only,
            supports_qsparc,
        }
    }
}
