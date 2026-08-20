import '../models/remote_models.dart';
import 'remote_transport.dart';

typedef RemoteSendErrorHandler = void Function(Object error);
typedef RemoteSendResultHandler =
    void Function(RelayEnvelope message, RemoteEnvelopeSendResult result);
typedef RemoteSendCurrentChecker = bool Function();

enum RemoteEnvelopeSendResult { delivered, droppedWhileDisconnected, rejected }

class RemoteEnvelopeSendQueue {
  int _seq = 0;
  Future<void> _chain = Future<void>.value();

  void reset({int? seed}) {
    _seq = seed ?? 0;
    _chain = Future<void>.value();
  }

  Future<void> send({
    required RelayEnvelope message,
    required RemoteTransport transport,
    required bool Function() connected,
    StoredDevice? activeDevice,
    bool terminalStream = false,
    RemoteSendCurrentChecker? isCurrent,
    RemoteSendErrorHandler? onError,
    RemoteSendResultHandler? onResult,
  }) {
    final seq = activeDevice == null ? null : ++_seq;
    final previous = _chain.catchError((_) {});
    final task = previous
        .then((_) async {
          // A queued send belongs to the transport/generation it was created
          // for. `connected == true` is not enough here: a reconnect can make
          // the app connected again while this old queue item is still
          // waiting behind another send. Without this fence it gets written
          // through the old transport and its late result can tear down the
          // freshly reconnected link.
          if (!connected() || (isCurrent != null && !isCurrent())) {
            onResult?.call(
              message,
              RemoteEnvelopeSendResult.droppedWhileDisconnected,
            );
            return;
          }
          final outgoing = _attachDeviceIdentity(message, activeDevice, seq);
          final envelope = outgoing.toJson();
          late final bool sent;
          try {
            sent = terminalStream
                ? await transport.sendTerminal(envelope)
                : await transport.send(envelope);
          } catch (error) {
            if (isCurrent != null && !isCurrent()) {
              onResult?.call(
                message,
                RemoteEnvelopeSendResult.droppedWhileDisconnected,
              );
              return;
            }
            onResult?.call(message, RemoteEnvelopeSendResult.rejected);
            onError?.call(error);
            return;
          }
          // The transport may have closed while the native send was in
          // flight. Do not report that old result to the new connection.
          if (isCurrent != null && !isCurrent()) {
            onResult?.call(
              message,
              RemoteEnvelopeSendResult.droppedWhileDisconnected,
            );
            return;
          }
          onResult?.call(
            message,
            sent
                ? RemoteEnvelopeSendResult.delivered
                : RemoteEnvelopeSendResult.rejected,
          );
        })
        .catchError((Object error) {
          onError?.call(error);
        });
    _chain = task;
    return task;
  }

  RelayEnvelope _attachDeviceIdentity(
    RelayEnvelope message,
    StoredDevice? activeDevice,
    int? seq,
  ) {
    if (activeDevice == null) {
      return seq == null ? message : message.copyWith(seq: seq);
    }
    return message.copyWith(
      hostId: activeDevice.hostId,
      deviceId: activeDevice.deviceId,
      seq: seq,
    );
  }
}
