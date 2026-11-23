use std::time::SystemTime;

#[derive(Debug, Clone, PartialEq)]
pub struct P2pPacket {
    pub message: String,
    pub device_name: String,
    pub timestamp: u64,
}

impl P2pPacket {
    /// Constructor that automatically captures the current Unix timestamp
    pub fn new(message: impl Into<String>, device_name: impl Into<String>) -> Self {
        let timestamp = SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0);

        Self {
            message: message.into(),
            device_name: device_name.into(),
            timestamp,
        }
    }

    /// Constructor with an explicit timestamp (useful for reproducible tests)
    pub fn with_timestamp(
        message: impl Into<String>,
        device_name: impl Into<String>,
        timestamp: u64,
    ) -> Self {
        Self {
            message: message.into(),
            device_name: device_name.into(),
            timestamp,
        }
    }

    /// Encode to binary bytes for NFC transmission (TLV Format)
    /// Tag 0x01 = Device Name
    /// Tag 0x02 = Message / Phone Number
    /// Tag 0x03 = Timestamp (8 bytes Big-Endian)
    pub fn to_bytes(&self) -> Vec<u8> {
        let mut buffer = Vec::new();

        // Tag 0x01: Device Name
        let name_bytes = self.device_name.as_bytes();
        buffer.push(0x01);
        buffer.push(name_bytes.len() as u8);
        buffer.extend_from_slice(name_bytes);

        // Tag 0x02: Message
        let msg_bytes = self.message.as_bytes();
        buffer.push(0x02);
        buffer.push(msg_bytes.len() as u8);
        buffer.extend_from_slice(msg_bytes);

        // Tag 0x03: Timestamp (8 bytes Big-Endian)
        let time_bytes = self.timestamp.to_be_bytes();
        buffer.push(0x03);
        buffer.push(time_bytes.len() as u8);
        buffer.extend_from_slice(&time_bytes);

        buffer
    }

    /// Decode binary bytes received from NFC back into P2pPacket
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, String> {
        let mut device_name = String::new();
        let mut message = String::new();
        let mut timestamp: u64 = 0;
        let mut cursor = 0;

        while cursor < bytes.len() {
            let tag = bytes[cursor];
            cursor += 1;

            if cursor >= bytes.len() {
                break;
            }

            let len = bytes[cursor] as usize;
            cursor += 1;

            if cursor + len > bytes.len() {
                return Err("Malformed TLV packet: length exceeds buffer".to_string());
            }

            let value_str = String::from_utf8_lossy(&bytes[cursor..cursor + len]).to_string();

            match tag {
                0x01 => device_name = value_str,
                0x02 => message = value_str,
                0x03 => {
                    if len == 8 {
                        timestamp = u64::from_be_bytes(
                            bytes[cursor..cursor + 8]
                                .try_into()
                                .map_err(|_| "Invalid timestamp length".to_string())?,
                        );
                    }
                }
                _ => {} // Ignore unknown tags for forward compatibility
            }

            cursor += len;
        }

        Ok(Self {
            message,
            device_name,
            timestamp,
        })
    }
}

/// The proprietary AID used for phone-to-phone tap: F0010203040506
pub const P2P_AID: &[u8] = &[0xF0, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06];

/// Builds the ISO 7816 SELECT AID APDU command sent by the Receiver phone:
/// 00 A4 04 00 07 [F0 01 02 03 04 05 06] 00
pub fn build_select_aid_apdu() -> Vec<u8> {
    let mut apdu = vec![0x00, 0xA4, 0x04, 0x00, P2P_AID.len() as u8];
    apdu.extend_from_slice(P2P_AID);
    apdu.push(0x00); // Le byte
    apdu
}

/// Packs the packet payload with ISO status word 90 00 (Success) for the Sender phone:
pub fn build_apdu_response(packet: &P2pPacket) -> Vec<u8> {
    let mut response = packet.to_bytes();
    response.extend_from_slice(&[0x90, 0x00]); // SW_OK
    response
}
