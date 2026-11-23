use rust_card_reader::api::models::CardNetwork;
use rust_card_reader::engine::bin_db::resolve_bank_and_network;

#[test]
fn test_boi_rupay() {
    let (bank1, net1) = resolve_bank_and_network("6074123456781418");
    assert_eq!(bank1, "Bank of India");
    assert_eq!(net1, CardNetwork::RuPay);

    let (bank2, net2) = resolve_bank_and_network("6079470172480418");
    assert_eq!(bank2, "Bank of India");
    assert_eq!(net2, CardNetwork::RuPay);
}

#[test]
fn test_sbi_rupay() {
    let (bank, net) = resolve_bank_and_network("6070123456789999");
    assert_eq!(bank, "State Bank of India");
    assert_eq!(net, CardNetwork::RuPay);
}

#[test]
fn test_visa() {
    let (bank, net) = resolve_bank_and_network("4123456789012345");
    assert_eq!(bank, "Visa Issuer Bank");
    assert_eq!(net, CardNetwork::Visa);
}
