enum CardNetworkType { ruPay, visa, mastercard, unknown }

class SafeCardModel {
  final CardNetworkType network;
  final String issuerBank;
  final String appLabel;
  final String maskedPan;
  final String cardholderName;
  final String? validFrom;
  final String expiryDate;
  final bool isDomesticOnly;
  final bool supportsQsparc;

  const SafeCardModel({
    required this.network,
    required this.issuerBank,
    required this.appLabel,
    required this.maskedPan,
    required this.cardholderName,
    this.validFrom,
    required this.expiryDate,
    this.isDomesticOnly = true,
    this.supportsQsparc = false,
  });
}
