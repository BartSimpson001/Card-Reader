import 'dart:convert';
import 'dart:typed_data';

class SafeP2pMessage {
  final String message;
  final String deviceName;
  final int timestamp;

  const SafeP2pMessage({
    required this.message,
    required this.deviceName,
    required this.timestamp,
  });
}

class P2pPacket {
  final String message;
  final String deviceName;
  final int timestamp;

  P2pPacket({
    required this.message,
    required this.deviceName,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

  static final Uint8List p2pAid = Uint8List.fromList([
    0xF0, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06
  ]);

  /// Builds the ISO 7816 SELECT AID APDU command sent by the Receiver phone:
  /// 00 A4 04 00 07 F0 01 02 03 04 05 06 00
  static Uint8List buildSelectAidApdu() {
    final apdu = Uint8List(5 + p2pAid.length + 1);
    apdu[0] = 0x00;
    apdu[1] = 0xA4;
    apdu[2] = 0x04;
    apdu[3] = 0x00;
    apdu[4] = p2pAid.length;
    apdu.setRange(5, 5 + p2pAid.length, p2pAid);
    apdu[apdu.length - 1] = 0x00;
    return apdu;
  }

  /// Packs the packet payload with ISO status word 90 00 (Success) for the Sender phone:
  static Uint8List buildApduResponse(P2pPacket packet) {
    final payload = packet.toBytes();
    final response = Uint8List(payload.length + 2);
    response.setRange(0, payload.length, payload);
    response[payload.length] = 0x90;
    response[payload.length + 1] = 0x00;
    return response;
  }

  /// Encodes into TLV binary format:
  /// Tag 0x01 = Device Name
  /// Tag 0x02 = Message
  /// Tag 0x03 = Timestamp (8 bytes big-endian)
  Uint8List toBytes() {
    final builder = BytesBuilder();

    // Tag 0x01: Device Name
    final nameBytes = utf8.encode(deviceName);
    builder.addByte(0x01);
    builder.addByte(nameBytes.length);
    builder.add(nameBytes);

    // Tag 0x02: Message
    final msgBytes = utf8.encode(message);
    builder.addByte(0x02);
    builder.addByte(msgBytes.length);
    builder.add(msgBytes);

    // Tag 0x03: Timestamp (8 bytes Big-Endian)
    final timeBytes = Uint8List(8);
    final bdata = ByteData.sublistView(timeBytes);
    bdata.setUint64(0, timestamp, Endian.big);
    builder.addByte(0x03);
    builder.addByte(8);
    builder.add(timeBytes);

    return builder.toBytes();
  }

  /// Decodes binary bytes received from NFC back into P2pPacket
  static P2pPacket fromBytes(Uint8List bytes) {
    String deviceName = '';
    String message = '';
    int timestamp = 0;
    var cursor = 0;

    while (cursor < bytes.length) {
      final tag = bytes[cursor++];
      if (cursor >= bytes.length) break;

      final len = bytes[cursor++];
      if (cursor + len > bytes.length) {
        throw FormatException('Malformed TLV packet: length exceeds buffer');
      }

      final valBytes = bytes.sublist(cursor, cursor + len);

      switch (tag) {
        case 0x01:
          deviceName = utf8.decode(valBytes);
          break;
        case 0x02:
          message = utf8.decode(valBytes);
          break;
        case 0x03:
          if (len == 8) {
            final bdata = ByteData.sublistView(valBytes);
            timestamp = bdata.getUint64(0, Endian.big);
          }
          break;
      }

      cursor += len;
    }

    return P2pPacket(
      message: message,
      deviceName: deviceName,
      timestamp: timestamp,
    );
  }
}
