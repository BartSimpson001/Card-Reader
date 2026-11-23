import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

import '../../../src/rust/api/p2p.dart';
import 'p2p_event.dart';
import 'p2p_state.dart';

class P2pBloc extends Bloc<P2pEvent, P2pState> {
  static const MethodChannel _hceChannel =
      MethodChannel('com.example.card_reader/hce');

  P2pBloc() : super(const P2pInitial()) {
    on<LoadSavedPayload>(_onLoadSavedPayload);
    on<SetBroadcastPayload>(_onSetBroadcastPayload);
    on<StartP2pReceive>(_onStartReceive);
    on<StopP2pReceive>(_onStopReceive);
    on<ResetP2pState>(_onResetState);
    on<P2pReceiveCompleted>((event, emit) => emit(P2pReceiveSuccess(event.message)));
    on<P2pReceiveFailed>((event, emit) => emit(P2pFailure(event.errorMessage)));

    // Load any previously saved payload from disk on startup
    add(const LoadSavedPayload());
  }

  /// 0. Load previously saved payload from disk
  Future<void> _onLoadSavedPayload(
    LoadSavedPayload event,
    Emitter<P2pState> emit,
  ) async {
    try {
      final Uint8List? bytes =
          await _hceChannel.invokeMethod<Uint8List>('getSavedPayload');
      if (bytes != null && bytes.isNotEmpty) {
        String devName = 'Android Phone';
        String msg = '';
        var idx = 0;
        while (idx < bytes.length) {
          final tag = bytes[idx++];
          if (idx >= bytes.length) break;
          final len = bytes[idx++];
          if (idx + len > bytes.length) break;
          final val = String.fromCharCodes(bytes.sublist(idx, idx + len));
          if (tag == 0x01) devName = val;
          if (tag == 0x02) msg = val;
          idx += len;
        }
        if (msg.isNotEmpty) {
          emit(P2pBroadcasting(message: msg, deviceName: devName));
        }
      }
    } catch (_) {}
  }

  /// Helper to convert byte list to hex string
  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Helper to convert hex string to byte list
  static Uint8List _hexToBytes(String hexStr) {
    final clean = hexStr.replaceAll(' ', '');
    final result = Uint8List(clean.length ~/ 2);
    for (var i = 0; i < clean.length; i += 2) {
      result[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  /// 1. Sender: Uses Rust to encode payload, then sets it into Android HCE
  Future<void> _onSetBroadcastPayload(
    SetBroadcastPayload event,
    Emitter<P2pState> emit,
  ) async {
    try {
      // 1. Rust encodes message & device name into binary TLV bytes
      final Uint8List payloadBytes = await encodeP2PPayload(
        message: event.message,
        deviceName: event.deviceName,
      );

      // 2. Pass bytes to Android HCE service
      await _hceChannel.invokeMethod('setPayload', {'payload': payloadBytes});

      emit(P2pBroadcasting(
        message: event.message,
        deviceName: event.deviceName,
      ));
    } catch (e) {
      emit(P2pFailure('Failed to configure NFC broadcast: $e'));
    }
  }

  /// 2. Receiver: Polls NFC and calls Rust's receiveP2PMessage with retry
  Future<void> _onStartReceive(
    StartP2pReceive event,
    Emitter<P2pState> emit,
  ) async {
    emit(const P2pReceiving());

    try {
      // Start NFC hardware polling (ISO-DEP)
      await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 30),
        androidCheckNDEF: false,
        iosAlertMessage: 'Hold near sending phone',
      );

      // Rust transceiver state machine with auto-retry
      final SafeP2pMessage received = await receiveP2PMessage(
        transceiver: (Uint8List apdu) async {
          final String hexCmd = _bytesToHex(apdu);

          String? hexRes;
          Object? lastError;

          // Attempt up to 3 times in case of transient RF contact bounce
          for (var attempt = 1; attempt <= 3; attempt++) {
            try {
              hexRes = await FlutterNfcKit.transceive(
                hexCmd,
                timeout: const Duration(seconds: 4),
              );
              break;
            } catch (err) {
              lastError = err;
              if (attempt < 3) {
                await Future.delayed(const Duration(milliseconds: 150));
              }
            }
          }

          if (hexRes == null) {
            throw lastError ?? Exception('NFC transceive failed after retries');
          }

          return _hexToBytes(hexRes);
        },
      );

      add(P2pReceiveCompleted(received));
    } catch (e) {
      add(P2pReceiveFailed(_toUserFriendlyP2pMessage(e)));
    } finally {
      try {
        await FlutterNfcKit.finish();
      } catch (_) {}
    }
  }

  String _toUserFriendlyP2pMessage(Object error) {
    final msg = error.toString().toLowerCase();

    if (msg.contains('out of date') ||
        msg.contains('tag was lost') ||
        msg.contains('tag is lost') ||
        msg.contains('timeout') ||
        msg.contains('timed out') ||
        msg.contains('transceive fail')) {
      return 'Phones moved too quickly. Hold them touching steadily for 1-2 seconds.';
    }

    if (msg.contains('not enabled') || msg.contains('disabled')) {
      return 'NFC is turned off. Please turn on NFC in Settings.';
    }

    if (msg.contains('rejected') || msg.contains('sw=')) {
      return 'Transfer rejected by the other device.';
    }

    if (msg.contains('cancel') || msg.contains('stop')) {
      return 'Transfer stopped.';
    }

    return 'Connection lost. Please tap the phones back-to-back again.';
  }

  Future<void> _onStopReceive(
    StopP2pReceive event,
    Emitter<P2pState> emit,
  ) async {
    try {
      await FlutterNfcKit.finish();
    } catch (_) {}
    emit(const P2pInitial());
  }

  void _onResetState(
    ResetP2pState event,
    Emitter<P2pState> emit,
  ) {
    emit(const P2pInitial());
  }
}
