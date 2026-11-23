use rust_card_reader::engine::p2p::{build_apdu_response, build_select_aid_apdu, P2pPacket};

#[test]
fn test_p2p_packet_roundtrip() {
    let original = P2pPacket::with_timestamp("+91 9876543210", "Samsung Galaxy A35", 1700000000);
    let bytes = original.to_bytes();
    let decoded = P2pPacket::from_bytes(&bytes).expect("Failed to parse bytes");

    assert_eq!(original, decoded);
    assert_eq!(decoded.message, "+91 9876543210");
    assert_eq!(decoded.device_name, "Samsung Galaxy A35");
    assert_eq!(decoded.timestamp, 1700000000);
}

#[test]
fn test_p2p_packet_auto_timestamp() {
    let packet = P2pPacket::new("Auto Timestamp Message", "Pixel 8");
    assert!(packet.timestamp > 0);

    let bytes = packet.to_bytes();
    let decoded = P2pPacket::from_bytes(&bytes).expect("Failed to parse bytes");
    assert_eq!(packet, decoded);
}

#[test]
fn test_select_aid_apdu_format() {
    let apdu = build_select_aid_apdu();
    assert_eq!(
        apdu,
        vec![
            0x00, 0xA4, 0x04, 0x00, 0x07, 0xF0, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x00
        ]
    );
}

#[test]
fn test_apdu_response_status_word() {
    let packet = P2pPacket::new("Test Message", "Pixel 8");
    let response = build_apdu_response(&packet);
    let len = response.len();
    assert!(len >= 2);
    assert_eq!(&response[len - 2..], &[0x90, 0x00]);
}
