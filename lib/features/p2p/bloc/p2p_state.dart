import 'package:equatable/equatable.dart';
import '../../../src/rust/api/p2p.dart';

abstract class P2pState extends Equatable {
  const P2pState();

  @override
  List<Object?> get props => [];
}

/// Initial Idle State
class P2pInitial extends P2pState {
  const P2pInitial();
}

/// Sender: Actively broadcasting payload via HCE on tap
class P2pBroadcasting extends P2pState {
  final String message;
  final String deviceName;

  const P2pBroadcasting({required this.message, required this.deviceName});

  @override
  List<Object?> get props => [message, deviceName];
}

/// Receiver: NFC polling active, waiting for phone tap
class P2pReceiving extends P2pState {
  const P2pReceiving();
}

/// Receiver: Data successfully received from other phone
class P2pReceiveSuccess extends P2pState {
  final SafeP2pMessage data;

  const P2pReceiveSuccess(this.data);

  @override
  List<Object?> get props => [data];
}

/// Failure State (Error during transmit or receive)
class P2pFailure extends P2pState {
  final String errorMessage;

  const P2pFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
