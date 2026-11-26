import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/emv/emv_engine.dart';
import '../data/services/nfc_bridge_service.dart';
import 'card_scanner_event.dart';
import 'card_scanner_state.dart';

class CardScannerBloc extends Bloc<CardScannerEvent, CardScannerState> {
  final NfcBridgeService _nfcService;

  CardScannerBloc({NfcBridgeService? nfcService})
    : _nfcService = nfcService ?? NfcBridgeService(),
      super(const CardScannerInitial()) {
    on<StartCardScan>(_onStartScan);
    on<StopCardScan>(_onStopScan);
    on<ResetCardScan>(_onResetScan);
    on<CardScanCompleted>(_onScanCompleted);
    on<CardScanFailed>(_onScanFailed);
  }

  Future<void> _onStartScan(
    StartCardScan event,
    Emitter<CardScannerState> emit,
  ) async {
    emit(const CardScannerScanning());

    try {
      // 1. Poll for contactless card
      await _nfcService.startNfcPolling();

      // 2. Pure Dart EMV Engine state machine
      final engine = EmvEngine((apdu) async {
        return await _nfcService.transceive(apdu);
      });

      final safeCard = await engine.executeSession();

      // 3. Close the physical NFC session cleanly
      await _nfcService.finishSession();

      emit(CardScannerSuccess(safeCard));
    } catch (e) {
      await _nfcService.finishSession(errorMessage: e.toString());
      emit(CardScannerFailure(_toUserFriendlyMessage(e)));
    }
  }

  String _toUserFriendlyMessage(Object error) {
    final msg = error.toString().toLowerCase();

    if (msg.contains('out of date') ||
        msg.contains('tag was lost') ||
        msg.contains('tag is lost') ||
        msg.contains('transceive fail') ||
        msg.contains('connection lost')) {
      return 'Card moved too quickly. Hold it steady against the back.';
    }

    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'Scanning timed out. Tap your card against the phone to scan.';
    }

    if (msg.contains('not enabled') || msg.contains('disabled')) {
      return 'NFC is turned off. Please turn on NFC in Settings.';
    }

    if (msg.contains('no readable payment') ||
        msg.contains('aid not found') ||
        msg.contains('not supported')) {
      return 'Card not recognized as a supported EMV chip.';
    }

    if (msg.contains('cancel') || msg.contains('stop')) {
      return 'Scanning stopped.';
    }

    return 'Could not read card. Please align it near the camera and try again.';
  }

  Future<void> _onStopScan(
    StopCardScan event,
    Emitter<CardScannerState> emit,
  ) async {
    await _nfcService.finishSession();
    emit(const CardScannerInitial());
  }

  Future<void> _onResetScan(
    ResetCardScan event,
    Emitter<CardScannerState> emit,
  ) async {
    await _nfcService.finishSession();
    emit(const CardScannerInitial());
  }

  void _onScanCompleted(
    CardScanCompleted event,
    Emitter<CardScannerState> emit,
  ) {
    emit(CardScannerSuccess(event.card));
  }

  void _onScanFailed(CardScanFailed event, Emitter<CardScannerState> emit) {
    emit(CardScannerFailure(event.errorMessage));
  }
}
