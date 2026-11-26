import 'dart:typed_data';

class EmvTag {
  final Uint8List bytes;

  EmvTag(this.bytes);

  String get hex =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmvTag &&
          runtimeType == other.runtimeType &&
          hex == other.hex;

  @override
  int get hashCode => hex.hashCode;

  @override
  String toString() => hex;
}

/// Parses raw binary BER-TLV stream into a Tag -> Value map
Map<String, Uint8List> parseTlv(Uint8List data) {
  final Map<String, Uint8List> map = {};
  var cursor = 0;

  while (cursor < data.length) {
    if (data[cursor] == 0x00 || data[cursor] == 0xFF) {
      cursor++;
      continue;
    }

    final firstByte = data[cursor];
    cursor++;

    final isConstructed = (firstByte & 0x20) != 0;
    final List<int> tagBytes = [firstByte];

    if ((firstByte & 0x1F) == 0x1F) {
      while (cursor < data.length) {
        final nextByte = data[cursor];
        cursor++;
        tagBytes.add(nextByte);
        if ((nextByte & 0x80) == 0) {
          break;
        }
      }
    }

    final tagHex = tagBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join();

    if (cursor >= data.length) break;

    final lenByte = data[cursor];
    cursor++;

    int length;
    if ((lenByte & 0x80) == 0) {
      length = lenByte;
    } else {
      final numOctets = lenByte & 0x7F;
      if (cursor + numOctets > data.length) break;
      var val = 0;
      for (var i = 0; i < numOctets; i++) {
        val = (val << 8) | data[cursor];
        cursor++;
      }
      length = val;
    }

    if (cursor + length > data.length) break;

    final value = Uint8List.fromList(data.sublist(cursor, cursor + length));
    cursor += length;

    if (isConstructed) {
      final nested = parseTlv(value);
      map.addAll(nested);
    }

    map[tagHex] = value;
  }

  return map;
}

/// Extracts PAN, Expiry (MM/YY), and Service Code from Track 2 equivalent data (Tag 57 or 9F6B)
(String pan, String expiry, String? serviceCode)? parseTrack2(Uint8List data) {
  final hexStr = data
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join();

  // Track 2 uses 'D', 'd', or '=' as delimiter
  final parts = hexStr.split(RegExp(r'[Dd=]'));
  if (parts.length < 2) return null;

  final pan = parts[0].replaceAll(RegExp(r'\D'), '');
  if (pan.length < 12) return null;

  final rest = parts[1];
  var expiry = 'MM/YY';
  String? serviceCode;

  if (rest.length >= 4) {
    final yy = rest.substring(0, 2);
    final mm = rest.substring(2, 4);
    expiry = '$mm/$yy';
  }

  if (rest.length >= 7) {
    serviceCode = rest.substring(4, 7);
  }

  return (pan, expiry, serviceCode);
}

/// Formats BCD date bytes (YYMMDD) into MM/YY string
String? formatBcdDate(Uint8List data) {
  if (data.length < 2) return null;
  final hex = data
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join();
  if (hex.length >= 4) {
    final yy = hex.substring(0, 2);
    final mm = hex.substring(2, 4);
    return '$mm/$yy';
  }
  return null;
}
