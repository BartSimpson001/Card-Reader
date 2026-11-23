use crate::api::models::CardNetwork;

/// Resolves the Issuer Bank name and Card Network using the card's PAN prefix (BIN)
pub fn resolve_bank_and_network(pan: &str) -> (String, CardNetwork) {
    let clean_pan: String = pan.chars().filter(|c| c.is_ascii_digit()).collect();

    // Determine Network first
    let network = if clean_pan.starts_with('4') {
        CardNetwork::Visa
    } else if clean_pan.starts_with("51")
        || clean_pan.starts_with("52")
        || clean_pan.starts_with("53")
        || clean_pan.starts_with("54")
        || clean_pan.starts_with("55")
        || (clean_pan.len() >= 4
            && clean_pan[..4].parse::<u32>().map_or(false, |v| (2221..=2720).contains(&v)))
    {
        CardNetwork::Mastercard
    } else if clean_pan.starts_with("60")
        || clean_pan.starts_with("65")
        || clean_pan.starts_with("81")
        || clean_pan.starts_with("82")
        || clean_pan.starts_with("508")
    {
        CardNetwork::RuPay
    } else {
        CardNetwork::Unknown
    };

    // Determine Issuer Bank from BIN prefix
    let bank_name = if clean_pan.starts_with("6074") || clean_pan.starts_with("607947") || clean_pan.starts_with("607948") {
        "Bank of India".to_string()
    } else if clean_pan.starts_with("6070") || clean_pan.starts_with("6071") {
        "State Bank of India".to_string()
    } else if clean_pan.starts_with("6521") || clean_pan.starts_with("6522") {
        "HDFC Bank".to_string()
    } else if clean_pan.starts_with("6072") {
        "ICICI Bank".to_string()
    } else if clean_pan.starts_with("6073") {
        "Punjab National Bank".to_string()
    } else if clean_pan.starts_with("6075") {
        "Canara Bank".to_string()
    } else if clean_pan.starts_with("6076") {
        "Union Bank of India".to_string()
    } else if clean_pan.starts_with("6077") {
        "Bank of Baroda".to_string()
    } else if clean_pan.starts_with("6078") {
        "Axis Bank".to_string()
    } else if clean_pan.starts_with("6079") {
        "Kotak Mahindra Bank".to_string()
    } else if clean_pan.starts_with("6080") {
        "Indian Bank".to_string()
    } else if clean_pan.starts_with("6081") {
        "Central Bank of India".to_string()
    } else {
        match network {
            CardNetwork::RuPay => "RuPay Member Bank".to_string(),
            CardNetwork::Visa => "Visa Issuer Bank".to_string(),
            CardNetwork::Mastercard => "Mastercard Issuer Bank".to_string(),
            CardNetwork::Unknown => "Unknown Bank".to_string(),
        }
    };

    (bank_name, network)
}
