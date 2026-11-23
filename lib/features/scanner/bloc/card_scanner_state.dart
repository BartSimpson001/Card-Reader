import 'package:equatable/equatable.dart';

import '../data/models/safe_card_model.dart';

abstract class CardScannerState extends Equatable {
  const CardScannerState();

  @override
  List<Object?> get props => [];
}

class CardScannerInitial extends CardScannerState {
  const CardScannerInitial();
}

class CardScannerScanning extends CardScannerState {
  const CardScannerScanning();
}

class CardScannerSuccess extends CardScannerState {
  final SafeCardModel card;

  const CardScannerSuccess(this.card);

  @override
  List<Object?> get props => [card];
}

class CardScannerFailure extends CardScannerState {
  final String errorMessage;

  const CardScannerFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
