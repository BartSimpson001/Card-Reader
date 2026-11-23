#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CardNetwork {
    RuPay,
    Visa,
    Mastercard,
    Unknown,
}

/// Safe UI Data Model passed across FFI to Flutter
#[derive(Debug, Clone)]
pub struct SafeCardModel {
    pub network: CardNetwork,
    pub issuer_bank: String,
    pub app_label: String,
    pub masked_pan: String,
    pub last_four: String,
    pub cardholder_name: String,
    pub valid_from: Option<String>,
    pub expiry_date: String,
    pub is_domestic_only: bool,
    pub supports_qsparc: bool,
}
