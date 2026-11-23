import 'package:equatable/equatable.dart';
import '../data/models/safe_card_model.dart';

abstract class CardScannerEvent extends Equatable {
  const CardScannerEvent();

  @override
  List<Object?> get props => [];
}

class StartCardScan extends CardScannerEvent {
  const StartCardScan();
}

class StopCardScan extends CardScannerEvent{}

class ResetCardScan extends CardScannerEvent {
  const ResetCardScan();
}

class CardScanCompleted extends CardScannerEvent {
  final SafeCardModel card;

  const CardScanCompleted(this.card);

  @override
  List<Object?> get props => [card];
}

class CardScanFailed extends CardScannerEvent {
  final String errorMessage;

  const CardScanFailed(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
