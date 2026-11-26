import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:card_reader/core/emv/bin_db.dart';
import 'package:card_reader/core/emv/tlv_parser.dart';
import 'package:card_reader/core/p2p/p2p_packet.dart';
import 'package:card_reader/features/scanner/data/models/safe_card_model.dart';

void main() {
  group('BIN Database Tests', () {
    test('Bank of India RuPay BIN 607947', () {
      final (bank, net) = resolveBankAndNetwork('6079470172480418');
      expect(bank, 'Bank of India');
      expect(net, CardNetworkType.ruPay);
    });

    test('Bank of India RuPay BIN 6074', () {
      final (bank, net) = resolveBankAndNetwork('6074123456781418');
      expect(bank, 'Bank of India');
      expect(net, CardNetworkType.ruPay);
    });

    test('State Bank of India RuPay BIN 6070', () {
      final (bank, net) = resolveBankAndNetwork('6070123456789999');
      expect(bank, 'State Bank of India');
      expect(net, CardNetworkType.ruPay);
    });

    test('Visa Issuer Bank BIN 4', () {
      final (bank, net) = resolveBankAndNetwork('4123456789012345');
      expect(bank, 'Visa Issuer Bank');
      expect(net, CardNetworkType.visa);
    });
  });

  group('P2P Packet Tests', () {
    test('P2P Packet Roundtrip with custom timestamp', () {
      final original = P2pPacket(
        message: '+91 9876543210',
        deviceName: 'Samsung Galaxy A35',
        timestamp: 1700000000,
      );
      final bytes = original.toBytes();
      final decoded = P2pPacket.fromBytes(bytes);

      expect(decoded.message, original.message);
      expect(decoded.deviceName, original.deviceName);
      expect(decoded.timestamp, original.timestamp);
    });

    test('P2P SELECT AID APDU format', () {
      final apdu = P2pPacket.buildSelectAidApdu();
      expect(
        apdu,
        Uint8List.fromList([
          0x00, 0xA4, 0x04, 0x00, 0x07, 0xF0, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x00
        ]),
      );
    });

    test('P2P Response Status Word 90 00', () {
      final packet = P2pPacket(message: 'Hello', deviceName: 'Device');
      final resp = P2pPacket.buildApduResponse(packet);
      expect(resp.length, greaterThanOrEqualTo(2));
      expect(resp.sublist(resp.length - 2), Uint8List.fromList([0x90, 0x00]));
    });
  });

  group('TLV Parser Tests', () {
    test('Parse Track 2 Data', () {
      // 6079470172480418D3103...
      final raw = Uint8List.fromList([
        0x60, 0x79, 0x47, 0x01, 0x72, 0x48, 0x04, 0x18,
        0xD3, 0x10, 0x32, 0x20, 0x00, 0x00, 0x00, 0x00
      ]);
      final parsed = parseTrack2(raw);
      expect(parsed, isNotNull);
      expect(parsed!.$1, '6079470172480418');
      expect(parsed.$2, '03/31');
    });
  });
}
