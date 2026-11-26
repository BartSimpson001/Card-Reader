import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../p2p/bloc/p2p_bloc.dart';
import '../../../p2p/bloc/p2p_event.dart';
import '../../../p2p/bloc/p2p_state.dart';
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'NFC Connect',
            style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),

          bottom: const TabBar(
            indicatorColor: Color(0xFF1F6FEB),
            tabs: [
              Tab(icon: Icon(Icons.credit_card), text: 'Card Reader'),
              Tab(icon: Icon(Icons.sync_alt_rounded), text: 'P2P Share'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Card Reader
            BlocConsumer<CardScannerBloc, CardScannerState>(
              listener: (context, state) {
                if (state is CardScannerSuccess) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.greenAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${state.card.issuerBank} card read successfully!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF161B22),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.greenAccent.withOpacity(0.4)),
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                } else if (state is CardScannerFailure) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              state.errorMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF2A1515),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
                      ),
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
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade400,
                          ),
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
                                context.read<CardScannerBloc>().add(
                                  StopCardScan(),
                                );
                              } else if (isDetected) {
                                context.read<CardScannerBloc>().add(
                                  ResetCardScan(),
                                );
                              } else {
                                context.read<CardScannerBloc>().add(
                                  StartCardScan(),
                                );
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

            // Tab 2: P2P Share
            DefaultTabController(
              length: 2, // 2 sub-tabs: Send & Receive
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // Inner Sub-TabBar (Pill / Segmented style)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: TabBar(
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: const Color(0xFF1F6FEB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey,
                      tabs: const [
                        Tab(icon: Icon(Icons.upload_rounded), text: 'Send'),
                        Tab(
                          icon: Icon(Icons.download_rounded),
                          text: 'Receive',
                        ),
                      ],
                    ),
                  ),

                  // Inner TabBarView
                  const Expanded(
                    child: TabBarView(
                      children: [
                        // Sub-Tab 1: Send View (Phone / Text input)
                        P2PSendView(),

                        // Sub-Tab 2: Receive View (NFC Reader for incoming phone tap)
                        P2PReceiveView(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ==========================================
/// SUB-TAB 1: P2P SEND VIEW (Broadcaster)
/// ==========================================
class P2PSendView extends StatefulWidget {
  const P2PSendView({super.key});

  @override
  State<P2PSendView> createState() => _P2PSendViewState();
}

class _P2PSendViewState extends State<P2PSendView> {
  late final TextEditingController _msgController;

  @override
  void initState() {
    super.initState();
    final p2pState = context.read<P2pBloc>().state;
    final initialText = p2pState is P2pBroadcasting ? p2pState.message : '';
    _msgController = TextEditingController(text: initialText);
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<P2pBloc, P2pState>(
      listener: (context, state) {
        if (state is P2pBroadcasting) {
          if (_msgController.text != state.message) {
            _msgController.text = state.message;
          }
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.sensors_rounded,
                    color: Colors.greenAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Broadcasting "${state.message}" via NFC on tap!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF161B22),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.greenAccent.withOpacity(0.4)),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (state is P2pFailure) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.errorMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF2A1515),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final isBroadcasting = state is P2pBroadcasting;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Preview Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: isBroadcasting
                        ? [const Color(0xFF0F382A), const Color(0xFF1E5B40)]
                        : [const Color(0xFF161B22), const Color(0xFF21262D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: isBroadcasting
                        ? Colors.greenAccent.withOpacity(0.4)
                        : Colors.white10,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isBroadcasting
                              ? Icons.sensors_rounded
                              : Icons.nfc_rounded,
                          color: isBroadcasting
                              ? Colors.greenAccent
                              : Colors.blueAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isBroadcasting
                              ? 'NFC BROADCASTING ACTIVE'
                              : 'P2P TAP BROADCASTER',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: isBroadcasting
                                ? Colors.greenAccent
                                : Colors.blueAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _msgController,
                      builder: (context, value, _) {
                        final text = state is P2pBroadcasting
                            ? state.message
                            : value.text.trim();
                        return Text(
                          text.isEmpty ? 'Type data below to share...' : text,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: text.isEmpty ? Colors.grey : Colors.white,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isBroadcasting
                          ? 'Ready! Tap back of other phone to transmit.'
                          : 'Will be sent when another phone taps back-to-back',
                      style: TextStyle(
                        fontSize: 11,
                        color: isBroadcasting
                            ? Colors.greenAccent.withOpacity(0.8)
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Text Field Input
              TextField(
                controller: _msgController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Phone Number or Text',
                  hintText: 'e.g. +91 9876543210 or your message',
                  prefixIcon: const Icon(
                    Icons.edit_note_rounded,
                    color: Colors.blueAccent,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF161B22),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1F6FEB)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Action Button
              FilledButton.icon(
                onPressed: () {
                  final payload = _msgController.text.trim();
                  if (payload.isEmpty) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.amberAccent,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Please enter a phone number or text first',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: const Color(0xFF261D10),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.amberAccent.withOpacity(0.4)),
                        ),
                      ),
                    );
                    return;
                  }
                  // Dispatch BLoC event to encode in Rust & configure HCE
                  context.read<P2pBloc>().add(
                    SetBroadcastPayload(message: payload),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: isBroadcasting
                      ? const Color(0xFF238636)
                      : const Color(0xFF1F6FEB),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  isBroadcasting
                      ? Icons.check_circle_outline_rounded
                      : Icons.sensors_rounded,
                ),
                label: Text(
                  isBroadcasting
                      ? 'Broadcasting on Tap (Update)'
                      : 'Set as NFC Tap Payload',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ==========================================
/// SUB-TAB 2: P2P RECEIVE VIEW (Reader)
/// ==========================================
class P2PReceiveView extends StatelessWidget {
  const P2PReceiveView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<P2pBloc, P2pState>(
      listener: (context, state) {
        if (state is P2pReceiveSuccess) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.greenAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Received from ${state.data.deviceName}: "${state.data.message}"',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF161B22),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.greenAccent.withOpacity(0.4)),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        } else if (state is P2pFailure) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.errorMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF2A1515),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final isReceiving = state is P2pReceiving;
        final isSuccess = state is P2pReceiveSuccess;

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),

              // 1. Success Card
              if (isSuccess) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.greenAccent.withOpacity(0.4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent.withOpacity(0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.greenAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'FROM: ${state.data.deviceName.toUpperCase()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.copy_rounded,
                              size: 18,
                              color: Colors.white70,
                            ),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: state.data.message),
                              );
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline_rounded,
                                        color: Colors.lightBlueAccent,
                                        size: 20,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Copied to clipboard!',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF13233A),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: Colors.lightBlueAccent.withOpacity(0.4),
                                    ),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 20),
                      Text(
                        state.data.message,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Default Radar / Prompt
                Center(
                  child: Column(
                    children: [
                      Icon(
                        isReceiving
                            ? Icons.sensors_rounded
                            : Icons.contactless_outlined,
                        size: 72,
                        color: isReceiving
                            ? Colors.greenAccent
                            : Colors.blueAccent,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isReceiving
                            ? 'Hold phones back-to-back...'
                            : 'Ready to Receive Data',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isReceiving ? 'Keep the devices touching steadily' : 'Tap below and touch the other phone to receive its message',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(flex: 2),

              // Action Button
              FilledButton.icon(
                onPressed: () {
                  if (isReceiving) {
                    context.read<P2pBloc>().add(const StopP2pReceive());
                  } else if (isSuccess) {
                    context.read<P2pBloc>().add(const ResetP2pState());
                  } else {
                    context.read<P2pBloc>().add(const StartP2pReceive());
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: isSuccess
                      ? const Color(0xFF21262D)
                      : isReceiving
                      ? const Color(0xFF8B0000)
                      : const Color(0xFF1F6FEB),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  isSuccess
                      ? Icons.refresh_rounded
                      : isReceiving
                      ? Icons.close_rounded
                      : Icons.download_rounded,
                ),
                label: Text(
                  isSuccess
                      ? 'Clear & Receive Again'
                      : isReceiving
                      ? 'Cancel Listening'
                      : 'Tap to Receive Data',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
