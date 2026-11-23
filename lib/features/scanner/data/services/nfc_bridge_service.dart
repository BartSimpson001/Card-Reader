import 'dart:typed_data';

import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

class NfcBridgeService {
  /// Polls the phone's NFC antenna for an ISO 7816-4 contactless card
  Future<NFCTag> startNfcPolling() async {
    final availability = await FlutterNfcKit.nfcAvailability;
    if (availability != NFCAvailability.available) {
      throw Exception('NFC is disabled or not available on this device.');
    }

    final tag = await FlutterNfcKit.poll(
      timeout: const Duration(seconds: 15),
      androidCheckNDEF: false,
      readIso14443A: true,
      readIso14443B: true,
      readIso18092: false,
      readIso15693: false,
      iosAlertMessage: 'Hold your RuPay or EMV card against the phone',
    );

    if (tag.type != NFCTagType.iso7816) {
      await finishSession(errorMessage: 'Non-payment card detected');
      throw Exception('Not a contactless payment card (ISO-DEP required).');
    }

    return tag;
  }

  /// Sends an APDU command to the physical card chip and returns the card response
  Future<Uint8List> transceive(Uint8List apdu) async {
    return await FlutterNfcKit.transceive(apdu);
  }

  /// Always release the NFC antenna hardware when done
  Future<void> finishSession({String? errorMessage}) async {
    await FlutterNfcKit.finish(iosErrorMessage: errorMessage);
  }
}
