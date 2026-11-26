import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../../features/scanner/data/models/safe_card_model.dart';
import 'bin_db.dart';
import 'tlv_parser.dart';

final Uint8List rupayDebitAid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x05, 0x24, 0x10, 0x10]);
final Uint8List rupayQsparcAid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x05, 0x24, 0x10, 0x11]);
final Uint8List visaAid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x00, 0x03, 0x10, 0x10]);
final Uint8List mastercardAid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x00, 0x04, 0x10, 0x10]);
final Uint8List ppseName = Uint8List.fromList(utf8.encode('2PAY.SYS.DDF01'));

class EmvEngine {
  final Future<Uint8List> Function(Uint8List) transceiver;

  EmvEngine(this.transceiver);

  /// Smart transceiver that automatically handles ISO 7816 status words:
  /// - 6C xx: Resends command with correct Le = xx
  /// - 61 xx: Sends GET RESPONSE (00 C0 00 00 xx) to fetch available payload
  Future<Uint8List> transceiveApdu(Uint8List apdu) async {
    var cmd = Uint8List.fromList(apdu);
    var resp = await transceiver(cmd);
    if (resp.length < 2) return resp;

    var sw1 = resp[resp.length - 2];
    var sw2 = resp[resp.length - 1];

    // 6C xx: Wrong length -> resend with Le = sw2
    if (sw1 == 0x6C && cmd.isNotEmpty) {
      cmd[cmd.length - 1] = sw2;
      return await transceiver(cmd);
    }

    // 61 xx: Bytes available -> fetch with GET RESPONSE
    if (sw1 == 0x61) {
      final getRespApdu = Uint8List.fromList([0x00, 0xC0, 0x00, 0x00, sw2]);
      final fullResp = await transceiver(getRespApdu);
      if (fullResp.length >= 2 && _isSuccess(fullResp)) {
        return fullResp;
      }
    }

    return resp;
  }

  Future<SafeCardModel> executeSession() async {
    final aidsToTry = <Uint8List>[];

    // Step 1: SELECT PPSE
    try {
      final aid = await _selectPpse();
      aidsToTry.add(aid);
      if (_areEqual(aid, rupayDebitAid)) {
        aidsToTry.add(rupayQsparcAid);
      }
    } catch (_) {
      aidsToTry.addAll([rupayDebitAid, rupayQsparcAid, visaAid, mastercardAid]);
    }

    String lastErr = 'No readable payment record found';

    for (final aid in aidsToTry) {
      try {
        return await _executeSessionForAid(aid);
      } catch (e) {
        lastErr = e.toString();
      }
    }

    throw Exception(lastErr);
  }

  Future<SafeCardModel> _executeSessionForAid(Uint8List aid) async {
    // Step 2: SELECT AID
    final selectResult = await _selectAid(aid);
    final fciTlv = selectResult.tlv;
    final selectedAid = selectResult.aid;

    var appLabel = 'Contactless Card';
    if (fciTlv.containsKey('50')) {
      try {
        appLabel = utf8.decode(fciTlv['50']!).trim();
      } catch (_) {}
    }

    final collectedTlv = Map<String, Uint8List>.from(fciTlv);

    // Step 3: GET PROCESSING OPTIONS (GPO)
    try {
      final gpoResponse = await _getProcessingOptions(fciTlv);
      final gpoTlv = parseTlv(gpoResponse);
      collectedTlv.addAll(gpoTlv);

      // Step 4: Read AFL Records
      if (gpoTlv.containsKey('94')) {
        await _readAflRecords(gpoTlv['94']!, collectedTlv);
      } else if (gpoTlv.containsKey('80') && gpoTlv['80']!.length > 2) {
        await _readAflRecords(
          Uint8List.fromList(gpoTlv['80']!.sublist(2)),
          collectedTlv,
        );
      } else {
        await _readDefaultRecords(collectedTlv);
      }
    } catch (_) {
      await _readDefaultRecords(collectedTlv);
    }

    // Step 5: Build Raw Card from collected records
    return _buildCard(selectedAid, appLabel, collectedTlv);
  }

  Future<Uint8List> _selectPpse() async {
    final apdu = Uint8List(5 + ppseName.length + 1);
    apdu[0] = 0x00;
    apdu[1] = 0xA4;
    apdu[2] = 0x04;
    apdu[3] = 0x00;
    apdu[4] = ppseName.length;
    apdu.setRange(5, 5 + ppseName.length, ppseName);
    apdu[apdu.length - 1] = 0x00;

    final response = await transceiveApdu(apdu);
    if (response.length < 2 || !_isSuccess(response)) {
      throw Exception('PPSE not found');
    }

    final tlv = parseTlv(response);
    if (tlv.containsKey('4F')) {
      return tlv['4F']!;
    }

    throw Exception('No AID in PPSE');
  }

  Future<({Map<String, Uint8List> tlv, Uint8List aid})> _selectAid(Uint8List aid) async {
    final apdu = Uint8List(5 + aid.length + 1);
    apdu[0] = 0x00;
    apdu[1] = 0xA4;
    apdu[2] = 0x04;
    apdu[3] = 0x00;
    apdu[4] = aid.length;
    apdu.setRange(5, 5 + aid.length, aid);
    apdu[apdu.length - 1] = 0x00;

    final response = await transceiveApdu(apdu);
    if (response.length >= 2 && _isSuccess(response)) {
      return (tlv: parseTlv(response), aid: aid);
    }

    for (final fallback in [rupayDebitAid, rupayQsparcAid, visaAid, mastercardAid]) {
      final fApdu = Uint8List(5 + fallback.length + 1);
      fApdu[0] = 0x00;
      fApdu[1] = 0xA4;
      fApdu[2] = 0x04;
      fApdu[3] = 0x00;
      fApdu[4] = fallback.length;
      fApdu.setRange(5, 5 + fallback.length, fallback);
      fApdu[fApdu.length - 1] = 0x00;

      final resp = await transceiveApdu(fApdu);
      if (resp.length >= 2 && _isSuccess(resp)) {
        return (tlv: parseTlv(resp), aid: fallback);
      }
    }

    throw Exception('Failed to select payment AID');
  }

  Future<Uint8List> _getProcessingOptions(Map<String, Uint8List> fciTlv) async {
    var pdolData = Uint8List(0);
    if (fciTlv.containsKey('9F38')) {
      pdolData = _constructPdolData(fciTlv['9F38']!, false);
    }

    // Try standard GPO with Le = 0x00
    var apdu = BytesBuilder();
    apdu.add([0x80, 0xA8, 0x00, 0x00, pdolData.length + 2, 0x83, pdolData.length]);
    apdu.add(pdolData);
    apdu.addByte(0x00);

    var response = await transceiveApdu(apdu.toBytes());

    // Fallback 1: RuPay DF3A alternative
    if (response.length < 2 || !_isSuccess(response)) {
      if (fciTlv.containsKey('9F38')) {
        final altData = _constructPdolData(fciTlv['9F38']!, true);
        final altApdu = BytesBuilder();
        altApdu.add([0x80, 0xA8, 0x00, 0x00, altData.length + 2, 0x83, altData.length]);
        altApdu.add(altData);
        altApdu.addByte(0x00);
        final respAlt = await transceiveApdu(altApdu.toBytes());
        if (respAlt.length >= 2 && _isSuccess(respAlt)) {
          response = respAlt;
        }
      }
    }

    // Fallback 2: Without Le byte
    if (response.length < 2 || !_isSuccess(response)) {
      final noLe = BytesBuilder();
      noLe.add([0x80, 0xA8, 0x00, 0x00, pdolData.length + 2, 0x83, pdolData.length]);
      noLe.add(pdolData);
      final resp2 = await transceiveApdu(noLe.toBytes());
      if (resp2.length >= 2 && _isSuccess(resp2)) {
        response = resp2;
      }
    }

    // Fallback 3: Empty GPO
    if (response.length < 2 || !_isSuccess(response)) {
      final emptyGpo = Uint8List.fromList([0x80, 0xA8, 0x00, 0x00, 0x02, 0x83, 0x00, 0x00]);
      final resp3 = await transceiveApdu(emptyGpo);
      if (resp3.length >= 2 && _isSuccess(resp3)) {
        response = resp3;
      }
    }

    if (response.length < 2 || !_isSuccess(response)) {
      throw Exception('GPO failed');
    }

    return response;
  }

  Uint8List _constructPdolData(Uint8List pdol, bool altMode) {
    final builder = BytesBuilder();
    var cursor = 0;

    while (cursor < pdol.length) {
      final tagFirst = pdol[cursor++];
      final tagBytes = [tagFirst];

      if ((tagFirst & 0x1F) == 0x1F) {
        while (cursor < pdol.length) {
          final next = pdol[cursor++];
          tagBytes.add(next);
          if ((next & 0x80) == 0) break;
        }
      }

      if (cursor >= pdol.length) break;
      final len = pdol[cursor++];

      final tagHex = tagBytes
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join();

      switch (tagHex) {
        case '9F40': // Additional Terminal Capabilities
          final val = [0x60, 0x00, 0xF0, 0xA0, 0x01];
          builder.add(_pad(val, len));
          break;
        case '9F33': // Terminal Capabilities
          final val = [0xE0, 0xF8, 0xC8];
          builder.add(_pad(val, len));
          break;
        case 'DF3A': // RuPay ATC Extension
          final val = altMode ? [0x00, 0x00, 0x00, 0x00, 0x00] : [0x20, 0x00, 0x00, 0x00, 0x00];
          builder.add(_pad(val, len));
          break;
        case 'DF16': // RuPay Service ID
          builder.add(_pad([0x00, 0x00], len));
          break;
        case '9F09': // App Version
          builder.add(_pad([0x00, 0x02], len));
          break;
        case '9F15': // Merchant Category Code
          builder.add(_pad([0x60, 0x11], len));
          break;
        case '9F21': // Transaction Time
          builder.add([0x12, 0x00, 0x00]);
          break;
        case '9F1C': // IFD Serial Number
          final val = utf8.encode('12345678');
          builder.add(_pad(val, len, padByte: 0x30));
          break;
        case '9F66': // Terminal Transaction Qualifiers
          builder.add(_pad([0x20, 0x00, 0x00, 0x00], len));
          break;
        case '9F02':
        case '9F03':
          builder.add(List.filled(len, 0x00));
          break;
        case '9F1A':
        case '5F2A':
          builder.add(_pad([0x03, 0x56], len));
          break;
        case '9A':
          builder.add([0x26, 0x11, 0x24]);
          break;
        case '9C':
          builder.addByte(0x00);
          break;
        case '9F37': // Unpredictable Number
          final rng = Random();
          final bytes = List.generate(4, (_) => rng.nextInt(256));
          builder.add(bytes);
          break;
        default:
          builder.add(List.filled(len, 0x00));
      }
    }

    return builder.toBytes();
  }

  List<int> _pad(List<int> bytes, int len, {int padByte = 0x00}) {
    if (bytes.length >= len) return bytes.sublist(0, len);
    return [...bytes, ...List.filled(len - bytes.length, padByte)];
  }

  Future<void> _readAflRecords(Uint8List afl, Map<String, Uint8List> collected) async {
    var cursor = 0;
    while (cursor + 4 <= afl.length) {
      final sfiByte = afl[cursor];
      final startRec = afl[cursor + 1];
      final endRec = afl[cursor + 2];
      cursor += 4;

      final sfi = (sfiByte >> 3) & 0x1F;
      for (var rec = startRec; rec <= endRec; rec++) {
        final apdu = Uint8List.fromList([0x00, 0xB2, rec, (sfi << 3) | 0x04, 0x00]);
        final resp = await transceiveApdu(apdu);
        if (_isSuccess(resp)) {
          collected.addAll(parseTlv(resp));
        }
      }
    }
  }

  Future<void> _readDefaultRecords(Map<String, Uint8List> collected) async {
    for (var sfi = 1; sfi <= 4; sfi++) {
      for (var rec = 1; rec <= 10; rec++) {
        final apdu = Uint8List.fromList([0x00, 0xB2, rec, (sfi << 3) | 0x04, 0x00]);
        final resp = await transceiveApdu(apdu);
        if (_isSuccess(resp)) {
          collected.addAll(parseTlv(resp));
        }
      }
    }
  }

  SafeCardModel _buildCard(Uint8List aidBytes, String appLabel, Map<String, Uint8List> tlv) {
    String pan = '';
    String expiryDate = 'MM/YY';

    // 1. Tag 57: Track 2
    if (tlv.containsKey('57')) {
      final t2 = parseTrack2(tlv['57']!);
      if (t2 != null) {
        pan = t2.$1;
        expiryDate = t2.$2;
      }
    }

    // 2. Tag 9F6B: Contactless Track 2
    if (pan.isEmpty && tlv.containsKey('9F6B')) {
      final t2 = parseTrack2(tlv['9F6B']!);
      if (t2 != null) {
        pan = t2.$1;
        expiryDate = t2.$2;
      }
    }

    // 3. Tag 5A: PAN
    if (pan.isEmpty && tlv.containsKey('5A')) {
      final hexPan = tlv['5A']!
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join();
      pan = hexPan.replaceAll(RegExp(r'F+$'), '');
    }

    // 4. Tag 56: Track 1
    if (pan.isEmpty && tlv.containsKey('56')) {
      final s = String.fromCharCodes(tlv['56']!);
      final idx = s.indexOf('^');
      if (idx != -1) {
        final candidate = s.substring(0, idx).replaceAll(RegExp(r'^\D+'), '');
        if (candidate.length >= 12 && candidate.length <= 19) {
          pan = candidate;
        }
      }
    }

    if (pan.isEmpty) {
      throw Exception('Card read successfully, but no PAN tag found');
    }

    if (expiryDate == 'MM/YY' && tlv.containsKey('5F24')) {
      expiryDate = formatBcdDate(tlv['5F24']!) ?? 'MM/YY';
    }

    String? cardholderName;
    if (tlv.containsKey('5F20')) {
      try {
        cardholderName = utf8.decode(tlv['5F20']!).trim();
      } catch (_) {}
    }

    String? validFrom;
    if (tlv.containsKey('5F25')) {
      validFrom = formatBcdDate(tlv['5F25']!);
    }

    var isDomesticOnly = true;
    if (tlv.containsKey('5F28')) {
      final c = tlv['5F28']!;
      isDomesticOnly = (c.length == 2 && c[0] == 0x03 && c[1] == 0x56) ||
          (c.length == 2 && c[0] == 0x35 && c[1] == 0x60);
    }

    final (bankName, network) = resolveBankAndNetwork(pan);

    final aidHex = aidBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join();

    final supportsQsparc = aidHex.contains('A0000005241011') ||
        appLabel.toLowerCase().contains('qsparc');

    // Build masked PAN: 6079 •••• •••• 0418
    final cleanPan = pan.replaceAll(RegExp(r'\D'), '');
    final String maskedPan;
    if (cleanPan.length >= 10) {
      final prefix = cleanPan.substring(0, 4);
      final suffix = cleanPan.substring(cleanPan.length - 4);
      maskedPan = '$prefix •••• •••• $suffix';
    } else {
      maskedPan = '•••• •••• •••• ••••';
    }

    return SafeCardModel(
      network: network,
      issuerBank: bankName,
      appLabel: appLabel,
      maskedPan: maskedPan,
      cardholderName: cardholderName ?? 'VALUED CUSTOMER',
      validFrom: validFrom,
      expiryDate: expiryDate,
      isDomesticOnly: isDomesticOnly,
      supportsQsparc: supportsQsparc,
    );
  }

  bool _isSuccess(Uint8List resp) {
    if (resp.length < 2) return false;
    final sw1 = resp[resp.length - 2];
    final sw2 = resp[resp.length - 1];
    return (sw1 == 0x90 && sw2 == 0x00) || sw1 == 0x61 || sw1 == 0x6C;
  }

  bool _areEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
