import '../../features/scanner/data/models/safe_card_model.dart';

/// Resolves the Issuer Bank name and Card Network using the card's PAN prefix (BIN)
(String bankName, CardNetworkType network) resolveBankAndNetwork(String pan) {
  final cleanPan = pan.replaceAll(RegExp(r'\D'), '');

  // Determine Network first
  CardNetworkType network;
  if (cleanPan.startsWith('4')) {
    network = CardNetworkType.visa;
  } else if (cleanPan.startsWith('51') ||
      cleanPan.startsWith('52') ||
      cleanPan.startsWith('53') ||
      cleanPan.startsWith('54') ||
      cleanPan.startsWith('55') ||
      (cleanPan.length >= 4 &&
          int.tryParse(cleanPan.substring(0, 4)) != null &&
          int.parse(cleanPan.substring(0, 4)) >= 2221 &&
          int.parse(cleanPan.substring(0, 4)) <= 2720)) {
    network = CardNetworkType.mastercard;
  } else if (cleanPan.startsWith('60') ||
      cleanPan.startsWith('65') ||
      cleanPan.startsWith('81') ||
      cleanPan.startsWith('82') ||
      cleanPan.startsWith('508')) {
    network = CardNetworkType.ruPay;
  } else {
    network = CardNetworkType.unknown;
  }

  // Determine Issuer Bank from BIN prefix
  String bankName;
  if (cleanPan.startsWith('6074') ||
      cleanPan.startsWith('607947') ||
      cleanPan.startsWith('607948')) {
    bankName = 'Bank of India';
  } else if (cleanPan.startsWith('6070') || cleanPan.startsWith('6071')) {
    bankName = 'State Bank of India';
  } else if (cleanPan.startsWith('6521') || cleanPan.startsWith('6522')) {
    bankName = 'HDFC Bank';
  } else if (cleanPan.startsWith('6072')) {
    bankName = 'ICICI Bank';
  } else if (cleanPan.startsWith('6073')) {
    bankName = 'Punjab National Bank';
  } else if (cleanPan.startsWith('6075')) {
    bankName = 'Canara Bank';
  } else if (cleanPan.startsWith('6076')) {
    bankName = 'Union Bank of India';
  } else if (cleanPan.startsWith('6077')) {
    bankName = 'Bank of Baroda';
  } else if (cleanPan.startsWith('6078')) {
    bankName = 'Axis Bank';
  } else if (cleanPan.startsWith('6079')) {
    bankName = 'Kotak Mahindra Bank';
  } else if (cleanPan.startsWith('6080')) {
    bankName = 'Indian Bank';
  } else if (cleanPan.startsWith('6081')) {
    bankName = 'Central Bank of India';
  } else {
    switch (network) {
      case CardNetworkType.ruPay:
        bankName = 'RuPay Member Bank';
        break;
      case CardNetworkType.visa:
        bankName = 'Visa Issuer Bank';
        break;
      case CardNetworkType.mastercard:
        bankName = 'Mastercard Issuer Bank';
        break;
      case CardNetworkType.unknown:
        bankName = 'Unknown Bank';
        break;
    }
  }

  return (bankName, network);
}
