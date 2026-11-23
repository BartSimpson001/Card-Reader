import 'package:flutter/material.dart';

import '../../data/models/safe_card_model.dart';

class CardMetadataBadges extends StatelessWidget {
  final SafeCardModel card;

  const CardMetadataBadges({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _infoChip(Icons.account_balance, card.issuerBank),
        _infoChip(
          Icons.nfc,
          card.supportsQsparc ? 'RuPay qSPARC / EMV' : 'EMV Contactless',
        ),
        _infoChip(
          Icons.location_on_outlined,
          card.isDomesticOnly ? 'Domestic (India)' : 'International',
        ),
      ],
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF58A6FF)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
