use std::collections::HashMap;

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct EmvTag(pub Vec<u8>);

impl EmvTag {
    pub fn hex(&self) -> String {
        self.0.iter().map(|b| format!("{:02X}", b)).collect()
    }
}

pub fn parse_tlv(data: &[u8]) -> HashMap<EmvTag, Vec<u8>> {
    let mut map = HashMap::new();
    let mut cursor = 0;

    while cursor < data.len() {
        if data[cursor] == 0x00 || data[cursor] == 0xFF {
            cursor += 1;
            continue;
        }

        let _tag_start = cursor;
        let first_byte = data[cursor];
        cursor += 1;

        let is_constructed = (first_byte & 0x20) != 0;

        let mut tag_bytes = vec![first_byte];
        if (first_byte & 0x1F) == 0x1F {
            while cursor < data.len() {
                let next_byte = data[cursor];
                cursor += 1;
                tag_bytes.push(next_byte);
                if (next_byte & 0x80) == 0 {
                    break;
                }
            }
        }
        let tag = EmvTag(tag_bytes);

        if cursor >= data.len() {
            break;
        }

        let len_byte = data[cursor];
        cursor += 1;

        let length = if (len_byte & 0x80) == 0 {
            len_byte as usize
        } else {
            let num_octets = (len_byte & 0x7F) as usize;
            if cursor + num_octets > data.len() {
                break;
            }
            let mut val: usize = 0;
            for _ in 0..num_octets {
                val = (val << 8) | (data[cursor] as usize);
                cursor += 1;
            }
            val
        };

        if cursor + length > data.len() {
            break;
        }

        let value = data[cursor..cursor + length].to_vec();
        cursor += length;

        if is_constructed {
            let nested = parse_tlv(&value);
            map.extend(nested);
        }

        map.insert(tag, value);
    }

    map
}

pub fn parse_track_2(data: &[u8]) -> Option<(String, String, Option<String>)> {
    let hex_str: String = data.iter().map(|b| format!("{:02X}", b)).collect();
    
    // Track 2 uses 'D', 'd', or '=' as delimiter between PAN and Expiry
    let parts: Vec<&str> = hex_str.split(|c| c == 'D' || c == 'd' || c == '=').collect();
    if parts.len() < 2 {
        return None;
    }

    let pan: String = parts[0].chars().filter(|c| c.is_ascii_digit()).collect();
    if pan.len() < 12 {
        return None;
    }

    let rest = parts[1];
    let mut expiry = String::from("MM/YY");
    let mut service_code = None;

    if rest.len() >= 4 {
        let yy = &rest[0..2];
        let mm = &rest[2..4];
        expiry = format!("{}/{}", mm, yy);
    }

    if rest.len() >= 7 {
        service_code = Some(rest[4..7].to_string());
    }

    Some((pan, expiry, service_code))
}

pub fn format_bcd_date(data: &[u8]) -> Option<String> {
    if data.len() < 2 {
        return None;
    }
    let hex: String = data.iter().map(|b| format!("{:02X}", b)).collect();
    if hex.len() >= 4 {
        let yy = &hex[0..2];
        let mm = &hex[2..4];
        Some(format!("{}/{}", mm, yy))
    } else {
        None
    }
}
