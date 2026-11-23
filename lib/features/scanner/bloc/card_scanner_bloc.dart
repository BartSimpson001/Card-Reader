import 'package:flutter_bloc/flutter_bloc.dart';

import 'card_scanner_event.dart';
import 'card_scanner_state.dart';

class CardScannerBloc extends Bloc<CardScannerEvent, CardScannerState> {
  CardScannerBloc() : super(const CardScannerInitial()) {
    on<StartCardScan>(_onStartScan);
    on<StopCardScan>(_onStopScan);
    on<ResetCardScan>(_onResetScan);
    on<CardScanCompleted>(_onScanCompleted);
    on<CardScanFailed>(_onScanFailed);
  }

  void _onStartScan(StartCardScan event, Emitter<CardScannerState> emit) {
    emit(const CardScannerScanning());
  }

  void _onStopScan(StopCardScan event, Emitter<CardScannerState> emit) {
    emit(const CardScannerInitial());
  }

  void _onResetScan(ResetCardScan event, Emitter<CardScannerState> emit) {
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
