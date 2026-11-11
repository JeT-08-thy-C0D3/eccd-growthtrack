import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/utils/audit_logger.dart';
import '../../shared/models/child_model.dart';
import '../child_profile/data/child_repository.dart';
import 'rfid_service.dart';

Future<ChildModel?> showRfidVerificationDialog({
  required BuildContext context,
  required ChildModel child,
  required ChildRepository repository,
  RfidService? service,
}) => showDialog<ChildModel>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _RfidVerificationDialog(
    child: child,
    repository: repository,
    service: service ?? RfidServiceProvider.instance,
  ),
);

class _RfidVerificationDialog extends StatefulWidget {
  const _RfidVerificationDialog({
    required this.child,
    required this.repository,
    required this.service,
  });
  final ChildModel child;
  final ChildRepository repository;
  final RfidService service;

  @override
  State<_RfidVerificationDialog> createState() =>
      _RfidVerificationDialogState();
}

class _RfidVerificationDialogState extends State<_RfidVerificationDialog> {
  late final String _sessionId;
  StreamSubscription<RfidMessage>? _subscription;
  String _message = 'Connecting to RFID reader…';
  bool _working = true;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _sessionId =
        'reg-${widget.child.childId}-${DateTime.now().microsecondsSinceEpoch}';
    _subscription = widget.service.messages.listen(_onMessage);
    if (kIsWeb && !widget.service.isConnected) {
      // The Web Serial chooser may only open from a direct button click.
      _working = false;
      _message = 'Click Connect Reader, then select the ESP32 COM port.';
    } else {
      unawaited(_start());
    }
  }

  Future<void> _start() async {
    try {
      if (!widget.service.isConnected) await widget.service.connect();
      if (!widget.service.isConnected) {
        throw StateError('RFID reader is not connected.');
      }
      await _armRegistration();
      if (mounted)
        setState(() {
          _working = false;
          _message = 'Scan RFID Card to Verify Registration';
        });
    } catch (error) {
      // A new child is provisional until a reader/card verifies it.  Treat a
      // connection failure the same as cancelling verification so the calling
      // registration page can discard the provisional profile instead of
      // leaving a pending child behind.
      _cancelled = true;
      // Release a partially opened local port before the teacher tries again
      // from the pending child's Link RFID Card control.
      try {
        await widget.service.disconnect();
      } catch (_) {}
      if (!mounted) return;
      final text = _connectionFailureText(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), backgroundColor: Colors.red),
      );
      Navigator.of(context).pop();
    }
  }

  String _connectionFailureText(Object error) {
    final detail = error.toString();
    final normalized = detail.toLowerCase();
    if (normalized.contains('busy') || normalized.contains('in use')) {
      return 'ESP32 COM port is busy. Close Arduino Serial Monitor/Plotter and every other serial app, then tap Link RFID Card again.';
    }
    if (normalized.contains('no serial port was selected') ||
        normalized.contains('notfounderror')) {
      return 'No ESP32 port was selected. Tap Link RFID Card again, choose the ESP32/CH340/CP210x port, and approve it.';
    }
    if (normalized.contains('unsupported') || normalized.contains('windows')) {
      return 'RFID USB needs Chrome or Edge Web Serial, not the native Windows Flutter app.';
    }
    return kIsWeb
        ? 'Unable to open the serial port. Registration was not saved. $detail'
        : 'Reader unavailable. Registration was not saved: $detail';
  }

  Future<void> _onMessage(RfidMessage message) async {
    if (_cancelled) return;
    if (message.type == 'REG_STATUS' && message.sessionId == _sessionId) {
      final code = message.data['code'] as String? ?? '';
      if (code == 'READY' && mounted && !_working) {
        setState(() => _message = 'Scan RFID Card to Verify Registration');
      }
      return;
    }
    if (_cancelled ||
        message.type != 'SCAN' ||
        message.purpose != 'register' ||
        message.sessionId != _sessionId ||
        _working)
      return;
    setState(() {
      _working = true;
      _message = 'Verifying RFID card…';
    });
    try {
      final linked = await widget.repository.linkRfidCard(
        widget.child,
        message.uid,
      );
      await widget.service.sendResult({
        'scanId': message.scanId,
        'sessionId': _sessionId,
        'ok': true,
        'code': 'REG_DONE',
        'childName': '${linked.firstName} ${linked.lastName}'.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(linked);
    } on DuplicateRfidCardException {
      await _rejectDuplicateAndRearm(message);
    } on OfflineRfidVerificationException {
      await _rejectAndClose(
        message,
        'REG_OFFLINE',
        'Internet is required to verify that this card is unique.',
      );
    } catch (error) {
      await _rejectAndClose(
        message,
        'REG_ERROR',
        'Unable to verify card: $error',
      );
    }
  }

  /// The ESP32 exits registration mode after a rejected RESULT. A duplicate
  /// card is not a failed child registration: keep the dialog open, re-arm
  /// the same saved child, and let the teacher scan a different card.
  Future<void> _rejectDuplicateAndRearm(RfidMessage message) async {
    try {
      await widget.service.sendResult({
        'scanId': message.scanId,
        'sessionId': _sessionId,
        'ok': false,
        'code': 'REG_DUPLICATE',
      });
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await _armRegistration();
      if (!mounted) return;
      setState(() {
        _working = false;
        _message = 'RFID Card Already Registered. Scan a different card.';
      });
    } catch (error) {
      await _rejectAndClose(
        message,
        'REG_ERROR',
        'Unable to re-arm RFID verification: $error',
      );
    }
  }

  Future<void> _armRegistration() async {
    Future<void> start() => widget.service.startRegistration(
      sessionId: _sessionId,
      childId: widget.child.childId,
      childName: '${widget.child.firstName} ${widget.child.lastName}'.trim(),
    );

    await start();
    // The firmware treats a matching session ID as an idempotent retry. This
    // second message is not a new connection/beep; it protects verification
    // if an ESP32 USB-UART reset swallowed the first registration command.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!_cancelled && widget.service.isConnected) await start();
  }

  Future<void> _rejectAndClose(
    RfidMessage message,
    String code,
    String text,
  ) async {
    await AuditLogger.log(
      action: 'RFID Registration Rejected',
      module: 'Child Registration',
      description: '$code for child ID ${widget.child.childId}.',
    );
    try {
      await widget.service.sendResult({
        'scanId': message.scanId,
        'sessionId': _sessionId,
        'ok': false,
        'code': code,
      });
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text), backgroundColor: Colors.red));
    Navigator.of(context).pop();
  }

  Future<void> _cancel() async {
    _cancelled = true;
    try {
      await widget.service.cancelRegistration(_sessionId);
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Scan RFID Card to Verify Registration'),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.contactless_rounded,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(_message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            'Child ID: ${widget.child.childId}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_working)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    ),
    actions: [
      if (!_working)
        TextButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.usb_rounded),
          label: const Text('Connect Reader'),
        ),
      TextButton(onPressed: _cancel, child: const Text('Verify Later')),
    ],
  );
}
