import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:skio_usb_serial/skio_usb_serial.dart';

/// The only serial reader used by registration and attendance. Widgets only
/// subscribe to its broadcast streams, so they never compete for the port.
enum RfidConnectionStatus {
  disconnected,
  connecting,
  connected,
  unsupported,
  error,
}

String normalizeRfidUid(String value) =>
    value.toUpperCase().replaceAll(RegExp(r'[\s:\-]'), '');

class RfidMessage {
  const RfidMessage(this.data);
  final Map<String, dynamic> data;

  String get type => data['type'] as String? ?? '';
  String get uid => normalizeRfidUid(data['uid'] as String? ?? '');
  String get scanId => data['scanId'] as String? ?? '';
  String get purpose => data['purpose'] as String? ?? 'attendance';
  String get sessionId => data['sessionId'] as String? ?? '';
  String get eventId => data['eventId'] as String? ?? '';

  factory RfidMessage.fromLine(String line) {
    final decoded = jsonDecode(line);
    if (decoded is! Map)
      throw const FormatException('Serial message is not JSON object');
    return RfidMessage(Map<String, dynamic>.from(decoded));
  }
}

/// Five-second app-side scan throttle. This is deliberately independent of
/// firmware's two-second physical-card cooldown.
class RfidScanDebouncer {
  RfidScanDebouncer({this.cooldown = const Duration(seconds: 5)});
  final Duration cooldown;
  final Map<String, DateTime> _lastAccepted = {};

  bool accept(String uid, {DateTime? now}) {
    final normalized = normalizeRfidUid(uid);
    if (normalized.isEmpty) return false;
    final instant = now ?? DateTime.now();
    final previous = _lastAccepted[normalized];
    if (previous != null && instant.difference(previous) < cooldown)
      return false;
    _lastAccepted[normalized] = instant;
    return true;
  }
}

abstract class RfidService {
  Stream<String> get uidStream;
  Stream<RfidMessage> get messages;
  Stream<RfidConnectionStatus> get connectionStatuses;
  RfidConnectionStatus get status;
  bool get isConnected;

  Future<void> connect();
  Future<void> disconnect();
  Future<void> reconnect();
  Future<void> send(Map<String, dynamic> message);

  Future<void> startRegistration({
    required String sessionId,
    required String childId,
    required String childName,
  }) => send({
    'type': 'REGISTER_START',
    'sessionId': sessionId,
    'childId': childId,
    'childName': childName,
  });

  Future<void> cancelRegistration(String sessionId) =>
      send({'type': 'REGISTER_CANCEL', 'sessionId': sessionId});

  Future<void> sendResult(Map<String, dynamic> result) =>
      send({'type': 'RESULT', ...result});

  Future<void> notifyManualAttendance(Map<String, dynamic> event) =>
      send({'type': 'MANUAL_ATTENDANCE', ...event});

  Future<void> dispose();
}

/// Runtime singleton. Android uses USB OTG; Chrome/Edge uses Web Serial and
/// opens the browser's port picker from the Connect Reader button.
class RfidServiceProvider {
  RfidServiceProvider._();
  static final RfidService instance = UsbSerialRfidService();
}

class SimulatedRfidService extends RfidService {
  final _uidController = StreamController<String>.broadcast();
  final _messageController = StreamController<RfidMessage>.broadcast();
  final _statusController = StreamController<RfidConnectionStatus>.broadcast();
  RfidConnectionStatus _status = RfidConnectionStatus.disconnected;

  @override
  Stream<String> get uidStream => _uidController.stream;
  @override
  Stream<RfidMessage> get messages => _messageController.stream;
  @override
  Stream<RfidConnectionStatus> get connectionStatuses =>
      _statusController.stream;
  @override
  RfidConnectionStatus get status => _status;
  @override
  bool get isConnected => _status == RfidConnectionStatus.connected;

  @override
  Future<void> connect() async => _setStatus(RfidConnectionStatus.connected);
  @override
  Future<void> disconnect() async =>
      _setStatus(RfidConnectionStatus.disconnected);
  @override
  Future<void> reconnect() async {
    await disconnect();
    await connect();
  }

  @override
  Future<void> send(Map<String, dynamic> message) async {}

  void emitScan(
    String uid, {
    String purpose = 'attendance',
    String? scanId,
    String? sessionId,
  }) {
    final normalized = normalizeRfidUid(uid);
    final message = RfidMessage({
      'type': 'SCAN',
      'uid': normalized,
      'purpose': purpose,
      'scanId': scanId ?? 'sim-${DateTime.now().microsecondsSinceEpoch}',
      if (sessionId != null) 'sessionId': sessionId,
    });
    _uidController.add(normalized);
    _messageController.add(message);
  }

  void emitMessage(Map<String, dynamic> message) =>
      _messageController.add(RfidMessage(message));
  void _setStatus(RfidConnectionStatus value) {
    _status = value;
    _statusController.add(value);
  }

  @override
  Future<void> dispose() async {
    await _uidController.close();
    await _messageController.close();
    await _statusController.close();
  }
}

class UsbSerialRfidService extends RfidService {
  final _uidController = StreamController<String>.broadcast();
  final _messageController = StreamController<RfidMessage>.broadcast();
  final _statusController = StreamController<RfidConnectionStatus>.broadcast();
  final Set<String> _manualNotificationIds = <String>{};
  UsbSerialPort? _port;
  StreamSubscription<String>? _lineSubscription;
  RfidConnectionStatus _status = RfidConnectionStatus.disconnected;

  @override
  Stream<String> get uidStream => _uidController.stream;
  @override
  Stream<RfidMessage> get messages => _messageController.stream;
  @override
  Stream<RfidConnectionStatus> get connectionStatuses =>
      _statusController.stream;
  @override
  RfidConnectionStatus get status => _status;
  @override
  bool get isConnected => _status == RfidConnectionStatus.connected;

  @override
  Future<void> connect() async {
    if (isConnected || _status == RfidConnectionStatus.connecting) return;
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
      _setStatus(RfidConnectionStatus.unsupported);
      throw UnsupportedError(
        'USB RFID is supported in Chrome/Edge Web or on Android with OTG. '
        'The native Windows desktop target cannot open the ESP32 serial port.',
      );
    }
    _setStatus(RfidConnectionStatus.connecting);
    try {
      dynamic device;
      if (UsbSerialPort.requiresUserSelection) {
        // Web Serial requires this method to run from the user's tap on
        // "Connect RFID Reader" so Chrome/Edge may show the COM-port picker.
        device = await UsbSerialPort.request();
        if (device == null) throw StateError('No serial port was selected.');
      } else {
        final devices = await UsbSerialPort.list();
        if (devices.isEmpty) {
          throw StateError(
            'No USB serial device found. Connect the ESP32 and allow USB access.',
          );
        }
        device = devices.first;
      }
      // On Web Serial, request() above is both the user-mediated picker and
      // permission grant. Calling Android's access prompt again can be blocked
      // by the browser as a non-user-initiated popup.
      if (!kIsWeb) {
        final access = await UsbSerialPort.access.requestAccess(device);
        if (!access.isUsable) {
          throw StateError('USB serial access was not granted.');
        }
      }
      final port = await UsbSerialPort.open(
        device,
        config: const SerialConfig(baudRate: 115200, dtr: false, rts: false),
        // USB-UART control lines can reset an ESP32 as the port opens. The
        // supplied firmware needs about 1100 ms before it can receive JSON.
        openDelay: const Duration(milliseconds: 1400),
      );
      _port = port;
      _lineSubscription = port.input
          .transform(const LineReader())
          .listen(
            _handleLine,
            onError: _handleError,
            onDone: _handleDisconnect,
          );
      _setStatus(RfidConnectionStatus.connected);
      // Sent exactly once per genuine port-open; firmware deduplicates it too.
      await send({'type': 'CONNECTED'});
      await send({'type': 'MODE', 'mode': 'attendance'});
      // A few USB-UART adapters reset ESP32 boards after the serial port has
      // already opened. Retry only MODE once after the reset window. MODE has
      // no buzzer trigger in the supplied firmware, but it can restore the
      // attendance state if the first command arrived during boot.
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (isConnected) {
        await send({'type': 'MODE', 'mode': 'attendance'});
      }
    } catch (_) {
      await _closePort(sendDisconnect: false);
      _setStatus(RfidConnectionStatus.error);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    await _closePort(sendDisconnect: true);
    _setStatus(RfidConnectionStatus.disconnected);
  }

  @override
  Future<void> reconnect() async {
    await disconnect();
    await connect();
  }

  @override
  Future<void> send(Map<String, dynamic> message) async {
    final eventId = message['eventId'] as String?;
    if (message['type'] == 'MANUAL_ATTENDANCE' && eventId != null) {
      if (!_manualNotificationIds.add(eventId)) return;
    }
    final port = _port;
    if (port == null || !isConnected)
      throw StateError('RFID reader is not connected.');
    await port.write(utf8.encode('${jsonEncode(message)}\n'));
  }

  void _handleLine(String line) {
    if (line.trim().isEmpty) return;
    try {
      final message = RfidMessage.fromLine(line);
      if (message.type == 'SCAN' && message.uid.isNotEmpty)
        _uidController.add(message.uid);
      _messageController.add(message);
    } catch (_) {
      // Firmware may reset during a USB open. Ignore non-protocol boot noise.
    }
  }

  void _handleError(Object _) {
    _setStatus(RfidConnectionStatus.error);
  }

  void _handleDisconnect() {
    unawaited(_closePort(sendDisconnect: false));
    _setStatus(RfidConnectionStatus.disconnected);
  }

  Future<void> _closePort({required bool sendDisconnect}) async {
    final port = _port;
    _port = null;
    if (sendDisconnect && port != null && isConnected) {
      try {
        await port.write(utf8.encode('{"type":"DISCONNECTED"}\n'));
      } catch (_) {}
    }
    await _lineSubscription?.cancel();
    _lineSubscription = null;
    await port?.close();
  }

  void _setStatus(RfidConnectionStatus value) {
    _status = value;
    _statusController.add(value);
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _uidController.close();
    await _messageController.close();
    await _statusController.close();
  }
}
