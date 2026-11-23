import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/card_scanner_bloc.dart';
import '../../bloc/card_scanner_event.dart';
import '../../bloc/card_scanner_state.dart';
import '../widgets/card_metadata_badges.dart';
import '../widgets/card_radar_widget.dart';
import '../widgets/virtual_card_widget.dart';

class CardScannerScreen extends StatelessWidget {
  const CardScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'NFC Card Reader',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: Colors.greenAccent,
                ),
                SizedBox(width: 4),
                Text(
                  'RAM Safe',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: BlocConsumer<CardScannerBloc, CardScannerState>(
        listener: (context, state) {
          if (state is CardScannerFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        builder: (context, state) {
          final isScanning = state is CardScannerScanning;
          final isDetected = state is CardScannerSuccess;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                children: [
                  const Spacer(flex: 1),

                  // 1. Virtual Card Preview / Radar Area (Static, No Animation)
                  isDetected
                      ? VirtualCardWidget(card: state.card)
                      : CardRadarWidget(isScanning: isScanning),

                  const SizedBox(height: 32),

                  // 2. Status Text & Subtitle
                  Text(
                    isDetected
                        ? 'Card Verified via ISO-DEP'
                        : isScanning
                        ? 'Hold card steady against back of phone...'
                        : 'Ready to Scan Contactless Card',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isDetected
                        ? 'Sensitive PAN masked & zeroized from native memory'
                        : 'Supports RuPay, qSPARC, Visa & Mastercard EMV chips',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  ),

                  if (isDetected) ...[
                    const SizedBox(height: 24),
                    CardMetadataBadges(card: state.card),
                  ],

                  const Spacer(flex: 2),

                  // 3. Primary Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (isScanning) {
                          context.read<CardScannerBloc>().add(StopCardScan());
                        } else if (isDetected) {
                          context.read<CardScannerBloc>().add(ResetCardScan());
                        } else {
                          context.read<CardScannerBloc>().add(StartCardScan());
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: isDetected
                            ? const Color(0xFF21262D)
                            : const Color(0xFF1F6FEB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: Icon(
                        isDetected
                            ? Icons.refresh_rounded
                            : isScanning
                            ? Icons.sensors_rounded
                            : Icons.contactless_rounded,
                      ),
                      label: Text(
                        isDetected
                            ? 'Clear & Scan Another Card'
                            : isScanning
                            ? 'Stop Scanning'
                            : 'Tap to Scan Card',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
