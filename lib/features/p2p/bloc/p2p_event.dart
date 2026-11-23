import 'package:equatable/equatable.dart';
import '../../../src/rust/api/p2p.dart';

abstract class P2pEvent extends Equatable {
  const P2pEvent();

  @override
  List<Object?> get props => [];
}

/// Check for previously saved payload on app launch
class LoadSavedPayload extends P2pEvent {
  const LoadSavedPayload();
}

/// Set payload for HCE Broadcaster (Sender)
class SetBroadcastPayload extends P2pEvent {
  final String message;
  final String deviceName;

  const SetBroadcastPayload({
    required this.message,
    this.deviceName = 'Android Phone',
  });

  @override
  List<Object?> get props => [message, deviceName];
}

/// Start listening as Receiver
class StartP2pReceive extends P2pEvent {
  const StartP2pReceive();
}

/// Stop listening as Receiver
class StopP2pReceive extends P2pEvent {
  const StopP2pReceive();
}

/// Reset state to initial
class ResetP2pState extends P2pEvent {
  const ResetP2pState();
}

/// Internal: P2P Receive Succeeded
class P2pReceiveCompleted extends P2pEvent {
  final SafeP2pMessage message;

  const P2pReceiveCompleted(this.message);

  @override
  List<Object?> get props => [message];
}

/// Internal: P2P Receive Failed
class P2pReceiveFailed extends P2pEvent {
  final String errorMessage;

  const P2pReceiveFailed(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
