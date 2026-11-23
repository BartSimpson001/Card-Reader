import 'package:flutter/material.dart';
import '../../data/models/safe_card_model.dart';

class VirtualCardWidget extends StatelessWidget {
  final SafeCardModel card;

  const VirtualCardWidget({
    super.key,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('virtual_card'),
      height: 215,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A3D62), Color(0xFF1E5F9E), Color(0xFF0C2461)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E5F9E).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row: Restriction Tag & Bank Name
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                card.isDomesticOnly ? 'For Use Only In India' : 'International Card',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.85),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.orangeAccent, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    card.issuerBank.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Middle Row: EMV Chip + Contactless Wave + App Label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5C158),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade800),
                    ),
                    child: const Icon(
                      Icons.memory,
                      size: 20,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.wifi, color: Colors.white70, size: 22),
                ],
              ),
              Text(
                card.appLabel.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.8,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          // Masked PAN
          Text(
            card.maskedPan,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: Colors.white,
              fontFamily: 'monospace',
            ),
          ),

          // Bottom Row: Cardholder Name, Expiry, Network Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.cardholderName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (card.validFrom != null && card.validFrom!.isNotEmpty) ...[
                    _buildExpiryColumn('VALID FROM', card.validFrom!),
                    const SizedBox(width: 12),
                  ],
                  _buildExpiryColumn('VALID THRU', card.expiryDate),
                ],
              ),
              Text(
                _getNetworkName(card.network),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getNetworkName(CardNetworkType network) {
    switch (network) {
      case CardNetworkType.ruPay:
        return 'RuPay';
      case CardNetworkType.visa:
        return 'VISA';
      case CardNetworkType.mastercard:
        return 'Mastercard';
      case CardNetworkType.unknown:
        return 'Card';
    }
  }

  Widget _buildExpiryColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 7, color: Colors.white.withOpacity(0.75)),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
