import 'package:flutter/material.dart';

class CardRadarWidget extends StatelessWidget {
  final bool isScanning;

  const CardRadarWidget({
    super.key,
    required this.isScanning,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 215,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isScanning
              ? const Color(0xFF1F6FEB)
              : Colors.white.withOpacity(0.08),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isScanning
                      ? const Color(0xFF1F6FEB)
                      : Colors.grey.shade800)
                  .withOpacity(0.25),
            ),
            child: Icon(
              Icons.contactless_outlined,
              size: 52,
              color: isScanning
                  ? const Color(0xFF58A6FF)
                  : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isScanning ? 'READING EMV CHIP...' : 'TAP CARD ON BACK',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: isScanning
                  ? const Color(0xFF58A6FF)
                  : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
