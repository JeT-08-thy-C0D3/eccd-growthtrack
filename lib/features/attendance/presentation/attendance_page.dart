import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/utils/audit_logger.dart';
import '../../../shared/models/child_model.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../../child_profile/data/child_repository.dart';
import '../../rfid/rfid_service.dart';
import '../data/attendance_repository.dart';
import '../domain/attendance_model.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final AttendanceRepository _repository = AttendanceRepositoryImpl();
  final ChildRepository _childRepository = ChildRepositoryImpl();
  final RfidService _rfid = RfidServiceProvider.instance;
  final RfidScanDebouncer _scanDebouncer = RfidScanDebouncer();
  final Set<String> _processingScanIds = <String>{};
  List<ChildModel> _children = [];
  ChildModel? _selectedChild;
  ChildSection? _selectedRfidSection;
  String? _openedAttendanceDate;
  bool _isLoading = true;
  RfidConnectionStatus _rfidStatus = RfidConnectionStatus.disconnected;
  StreamSubscription<RfidMessage>? _rfidSubscription;
  StreamSubscription<RfidConnectionStatus>? _statusSubscription;
  String? _rfidFeedback;

  @override
  void initState() {
    super.initState();
    _loadChildren();
    _rfidStatus = _rfid.status;
    _rfidSubscription = _rfid.messages.listen(_onRfidMessage);
    _statusSubscription = _rfid.connectionStatuses.listen((status) {
      if (mounted) setState(() => _rfidStatus = status);
    });
  }

  @override
  void dispose() {
    _rfidSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadChildren() async {
    final teacher = await AuthRepositoryImpl().getCurrentUser();
    final data = teacher == null
        ? <ChildModel>[]
        : await DatabaseHelper.instance.readChildrenByTeacher(teacher.uid);
    if (!mounted) return;
    setState(() {
      _children = data;
      _selectedChild = data.isEmpty ? null : data.first;
      _isLoading = false;
    });
  }

  Future<void> _markAttendance(String status) async {
    if (!_isAttendanceOpenToday) {
      _showOpenDailyAttendanceMessage();
      return;
    }
    if (_selectedChild == null) return;
    final now = _manilaNow();
    final saved = await _repository.recordAttendance(
      AttendanceModel(
        childId: _selectedChild!.childId,
        attendanceDate: DateFormat('yyyy-MM-dd').format(now),
        attendanceTime: DateFormat('HH:mm:ss').format(now),
        status: status,
        updatedAt: now.toIso8601String(),
        attendanceMethod: 'manual',
        eventTimestampUtc: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    if (!saved.alreadyPresent) {
      try {
        await _rfid.notifyManualAttendance({
          'eventId': saved.attendance.attendanceEventId,
          'childId': _selectedChild!.childId,
          'childName':
              '${_selectedChild!.firstName} ${_selectedChild!.lastName}'.trim(),
          'status': status.toUpperCase(),
          'source': 'manual',
          'localDate': saved.attendance.attendanceDate,
          'localTime': saved.attendance.attendanceTime,
        });
      } catch (_) {
        // Reader feedback is optional; it never blocks manual local saving.
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved.alreadyPresent
              ? 'Already Present Today — original Time In was preserved.'
              : 'Attendance recorded: ${_selectedChild!.firstName} is $status',
        ),
        backgroundColor: saved.alreadyPresent
            ? Colors.orange
            : status == 'Present'
            ? Colors.green
            : Colors.red,
      ),
    );
  }

  DateTime _manilaNow() => DateTime.now().toUtc().add(const Duration(hours: 8));

  String get _todayAttendanceDate =>
      DateFormat('yyyy-MM-dd').format(_manilaNow());

  bool get _isAttendanceOpenToday =>
      _openedAttendanceDate == _todayAttendanceDate;

  bool get _isSchoolWeekday {
    final weekday = _manilaNow().weekday;
    return weekday >= DateTime.monday && weekday <= DateTime.friday;
  }

  Future<void> _openTodayAttendance() async {
    if (!_isSchoolWeekday) {
      if (mounted) {
        setState(
          () => _rfidFeedback =
              'Daily attendance is available Monday to Friday only.',
        );
      }
      return;
    }
    final now = _manilaNow();
    final localDate = DateFormat('yyyy-MM-dd').format(now);
    setState(() {
      _openedAttendanceDate = localDate;
      _rfidFeedback =
          '${DateFormat('EEEE').format(now)} attendance is open. Select an RFID section, then scan a card.';
    });
    await AuditLogger.log(
      action: 'Open Daily Attendance',
      module: 'Attendance',
      description:
          'Teacher opened ${DateFormat('EEEE').format(now)} attendance for $localDate.',
    );
  }

  void _showOpenDailyAttendanceMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Open today\'s Daily Attendance first.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _connectReader() async {
    try {
      await _rfid.connect();
      if (!_rfid.isConnected) {
        throw StateError(
          'The selected app target does not support USB serial. Use Chrome or Edge on this laptop, or Android with OTG.',
        );
      }
      if (mounted) {
        setState(
          () => _rfidFeedback = 'RFID reader connected. Wait 2 seconds, open today\'s attendance, select a section, then scan a card.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _rfidFeedback = _readerConnectionErrorMessage(error));
      }
    }
  }

  String _readerConnectionErrorMessage(Object error) {
    final message = error.toString();
    final normalized = message.toLowerCase();
    if (normalized.contains('busy') || normalized.contains('in use')) {
      return 'ESP32 port is busy. Close Arduino Serial Monitor, other browser tabs, and any serial app, then press Connect again.';
    }
    if (normalized.contains('unsupported') || normalized.contains('windows')) {
      return 'This app target cannot use USB serial. Run the app in Chrome or Edge (localhost/HTTPS), not Flutter Windows desktop.';
    }
    if (normalized.contains('no serial port was selected') ||
        normalized.contains('notfounderror')) {
      return 'No ESP32 port was selected. Press Connect and choose the ESP32/CH340/CP210x COM device.';
    }
    return 'Reader connection failed: $message';
  }

  Future<void> _disconnectReader() async {
    try {
      await _rfid.disconnect();
      if (mounted) {
        setState(
          () => _rfidFeedback = 'RFID reader disconnected. Manual attendance stays available after opening Daily Attendance.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _rfidFeedback = 'Reader disconnect failed: $error');
      }
    }
  }

  Future<void> _onRfidMessage(RfidMessage message) async {
    if (message.type != 'SCAN' || message.purpose == 'register') return;
    final scanId = message.scanId;
    if (scanId.isNotEmpty && !_processingScanIds.add(scanId)) return;
    if (!_isAttendanceOpenToday) {
      await _sendScanResult(message, ok: false, code: 'ATTENDANCE_NOT_OPEN');
      if (mounted) {
        setState(
          () => _rfidFeedback =
              'Open today\'s Daily Attendance before scanning RFID cards.',
        );
      }
      return;
    }
    final uid = message.uid;
    if (!_scanDebouncer.accept(uid)) {
      await _sendScanResult(message, ok: false, code: 'SCAN_DEBOUNCED');
      if (mounted)
        setState(() => _rfidFeedback = 'Repeated RFID scan ignored.');
      return;
    }
    final allowedSection = _selectedRfidSection;
    if (allowedSection == null) {
      await _sendScanResult(message, ok: false, code: 'SECTION_NOT_SELECTED');
      if (mounted) {
        setState(
          () => _rfidFeedback = 'Select an RFID attendance section first.',
        );
      }
      return;
    }
    final child = await _childRepository.findVerifiedChildByRfidUid(uid);
    if (child == null || !child.isActive) {
      await AuditLogger.log(
        action: 'RFID Attendance Rejected',
        module: 'Attendance',
        description: 'NOT_REGISTERED RFID scan received.',
      );
      await _sendScanResult(message, ok: false, code: 'NOT_REGISTERED');
      if (mounted) setState(() => _rfidFeedback = 'RFID Card Not Registered');
      return;
    }
    if (child.section != allowedSection) {
      await AuditLogger.log(
        action: 'RFID Attendance Rejected',
        module: 'Attendance',
        description:
            'SECTION_NOT_ALLOWED scan for child ID ${child.childId}; selected section ${allowedSection.label}.',
      );
      await _sendScanResult(
        message,
        ok: false,
        code: 'SECTION_NOT_ALLOWED',
        childName: '${child.firstName} ${child.lastName}'.trim(),
      );
      if (mounted) {
        setState(() {
          _rfidFeedback =
              '${child.firstName} belongs to ${child.section.label}. Select that section to record RFID attendance.';
        });
      }
      return;
    }
    final now = _manilaNow();
    final saved = await _repository.recordAttendance(
      AttendanceModel(
        childId: child.childId,
        attendanceDate: DateFormat('yyyy-MM-dd').format(now),
        attendanceTime: DateFormat('HH:mm:ss').format(now),
        status: 'Present',
        updatedAt: now.toIso8601String(),
        attendanceMethod: 'rfid',
        eventTimestampUtc: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    final savedAttendance = saved.attendance;
    await _sendScanResult(
      message,
      ok: !saved.alreadyPresent,
      code: saved.alreadyPresent ? 'ALREADY_PRESENT' : 'PRESENT',
      childName: '${child.firstName} ${child.lastName}'.trim(),
      localDate: savedAttendance.attendanceDate,
      localTime: savedAttendance.attendanceTime,
    );
    if (mounted) {
      setState(
        () => _rfidFeedback = saved.alreadyPresent
            ? 'Already Present Today — ${child.firstName}\'s original Time In is ${savedAttendance.attendanceTime}.'
            : '${child.firstName} Present — ${savedAttendance.attendanceDate} ${savedAttendance.attendanceTime} (RFID)',
      );
    }
  }

  Future<void> _sendScanResult(
    RfidMessage message, {
    required bool ok,
    required String code,
    String? childName,
    String? localDate,
    String? localTime,
  }) async {
    try {
      await _rfid.sendResult({
        'scanId': message.scanId,
        'ok': ok,
        'code': code,
        if (childName != null) 'childName': childName,
        if (localDate != null) 'localDate': localDate,
        if (localTime != null) 'localTime': localTime,
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFF7FBFF)),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 18, 28, 40),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1320),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHero(constraints.maxWidth),
                          const SizedBox(height: 26),
                          _buildAttendanceCard(constraints.maxWidth),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHero(double width) {
    final isPhone = width < 600;
    if (isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 218,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE5F4FF), Color(0xFFF8FCFF)],
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/attendance_rfid_hero.png',
                    fit: BoxFit.cover,
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xEEF4FAFF), Color(0xB8EAF6FF)],
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 22,
                  right: 20,
                  top: 30,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RFID Attendance',
                        style: TextStyle(
                          fontSize: 25,
                          height: 1.15,
                          color: Color(0xFF102A72),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Connect the ESP32 reader, then scan a registered child card.',
                        style: TextStyle(
                          color: Color(0xFF54769B),
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFDCEAF5)),
            ),
            child: _buildFeatureChips(),
          ),
        ],
      );
    }
    return Container(
      height: 264,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE5F4FF), Color(0xFFF8FCFF)],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Stack(
        children: [
          if (!isPhone)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: width < 760 ? .38 : .46,
                  heightFactor: 1,
                  child: Image.asset(
                    'assets/images/attendance_rfid_hero.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          Positioned(
            left: isPhone ? 24 : 36,
            top: isPhone ? 28 : 38,
            right: isPhone
                ? 24
                : width < 760
                ? 28
                : width * .45,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RFID Attendance',
                  style: TextStyle(
                    fontSize: isPhone ? 28 : 33,
                    color: Color(0xFF102A72),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Connect the ESP32 reader, then scan a registered child card.',
                  style: TextStyle(color: Color(0xFF54769B), fontSize: 15),
                ),
                const SizedBox(height: 28),
                _buildFeatureChips(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChips() => Wrap(
    spacing: 12,
    runSpacing: 8,
    children: const [
      _FeatureChip(
        icon: Icons.nfc_rounded,
        title: 'USB RFID Reader',
        subtitle: 'ESP32 serial at 115200 baud',
        color: Color(0xFF338CF3),
      ),
      _FeatureChip(
        icon: Icons.check_circle_rounded,
        title: 'Mark Attendance',
        subtitle: 'Present or Absent',
        color: Color(0xFF22A95B),
      ),
    ],
  );

  Widget _buildAttendanceCard(double width) => Container(
    padding: EdgeInsets.all(width < 600 ? 18 : 26),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x100F2D52),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F4FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.group_outlined,
                color: Color(0xFF1976D2),
                size: 31,
              ),
            ),
            const SizedBox(width: 18),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manual Attendance',
                    style: TextStyle(
                      color: Color(0xFF102A72),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Choose a child for teacher-controlled attendance.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildDailyAttendanceTrigger(),
        const SizedBox(height: 14),
        _buildRfidReaderPanel(),
        const SizedBox(height: 14),
        _buildRfidSectionSelector(),
        const SizedBox(height: 26),
        DropdownButtonFormField<ChildModel>(
          isExpanded: true,
          initialValue: _selectedChild,
          decoration: InputDecoration(
            labelText: 'Select Child (Manual Attendance)',
            prefixIcon: const Icon(Icons.person, color: BrandColors.navy),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          items: _visibleChildrenForManual
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Text(
                    '${c.firstName} ${c.lastName} (${c.childId})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (child) => setState(() => _selectedChild = child),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final present = _attendanceButton(
              'Mark Present',
              Icons.check_circle,
              const Color(0xFF22A95B),
              () => _markAttendance('Present'),
            );
            final absent = _attendanceButton(
              'Mark Absent',
              Icons.cancel,
              const Color(0xFFE8423B),
              () => _markAttendance('Absent'),
            );
            return constraints.maxWidth < 500
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [present, const SizedBox(height: 12), absent],
                  )
                : Row(
                    children: [
                      Expanded(child: present),
                      const SizedBox(width: 18),
                      Expanded(child: absent),
                    ],
                  );
          },
        ),
        const SizedBox(height: 22),
        if (_rfid is SimulatedRfidService)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: OutlinedButton.icon(
              onPressed:
                  _isAttendanceOpenToday &&
                      _selectedRfidSection != null &&
                      _selectedChild?.rfidVerified == true
                  ? () => (_rfid as SimulatedRfidService).emitScan(
                      _selectedChild!.rfidUid!,
                    )
                  : null,
              icon: const Icon(Icons.science_outlined),
              label: const Text('Simulate Registered RFID Scan (development)'),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF5FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFB9DEFF)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_rounded, color: Color(0xFF1976D2)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'RFID scans use the connected ESP32 reader. Manual Present and Absent remain available when the reader is disconnected.',
                  style: TextStyle(
                    color: Color(0xFF1263B4),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildRfidReaderPanel() {
    final connected = _rfidStatus == RfidConnectionStatus.connected;
    final label = switch (_rfidStatus) {
      RfidConnectionStatus.connected => 'Connected',
      RfidConnectionStatus.connecting => 'Connecting…',
      RfidConnectionStatus.unsupported => 'Use Chrome or Edge Web Serial',
      RfidConnectionStatus.error => 'Connection error',
      RfidConnectionStatus.disconnected => 'Disconnected',
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: connected ? const Color(0xFFEAF8EF) : const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: connected ? const Color(0xFF9AD6AA) : const Color(0xFFD1E0EF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                connected ? Icons.usb_rounded : Icons.usb_off_rounded,
                color: connected ? Colors.green : Colors.blueGrey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'RFID Reader: $label',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (connected)
                OutlinedButton.icon(
                  onPressed: _disconnectReader,
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text('Disconnect'),
                )
              else
                FilledButton.icon(
                  onPressed: _rfidStatus == RfidConnectionStatus.connecting
                      ? null
                      : _connectReader,
                  icon: const Icon(Icons.link_rounded),
                  label: Text(
                    _rfidStatus == RfidConnectionStatus.error
                        ? 'Reconnect Reader'
                        : 'Connect RFID Reader',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _rfidFeedback ?? _rfidReaderPrompt(connected),
            style: const TextStyle(color: Color(0xFF526477)),
          ),
        ],
      ),
    );
  }

  // Manual attendance remains an independent fallback. Selecting an RFID
  // section only decides which physical-card scans this reader may accept.
  List<ChildModel> get _visibleChildrenForManual => _children;

  String _rfidReaderPrompt(bool connected) {
    if (!connected) {
      return 'Step 1: Connect the ESP32 USB reader.';
    }
    if (!_isAttendanceOpenToday) {
      return 'Step 2: Open today\'s Daily Attendance.';
    }
    if (_selectedRfidSection == null) {
      return 'Step 3: Select an RFID attendance section.';
    }
    return 'Ready to scan. Hold the child\'s registered RFID card on the reader.';
  }

  Widget _buildDailyAttendanceTrigger() {
    final today = _manilaNow();
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final weekdays = List<DateTime>.generate(
      5,
      (index) => startOfWeek.add(Duration(days: index)),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isAttendanceOpenToday
            ? const Color(0xFFEAF8EF)
            : const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isAttendanceOpenToday
              ? const Color(0xFF9AD6AA)
              : const Color(0xFFFFD98A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isAttendanceOpenToday
                    ? Icons.event_available_rounded
                    : Icons.calendar_month_rounded,
                color: _isAttendanceOpenToday
                    ? Colors.green.shade700
                    : Colors.orange.shade800,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Daily Attendance (Weekdays)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (_isAttendanceOpenToday)
                const Chip(
                  label: Text('OPEN'),
                  avatar: Icon(Icons.check, size: 16),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            _isAttendanceOpenToday
                ? 'Attendance is open for ${DateFormat('EEEE, MMMM d').format(today)}.'
                : _isSchoolWeekday
                ? 'Press today\'s button to enable RFID and manual attendance.'
                : 'Regular daily attendance can be opened Monday to Friday only.',
            style: const TextStyle(color: Color(0xFF526477), fontSize: 13),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isSchoolWeekday ? _openTodayAttendance : null,
            icon: Icon(
              _isAttendanceOpenToday
                  ? Icons.check_circle_rounded
                  : Icons.play_circle_fill_rounded,
            ),
            label: Text(
              _isAttendanceOpenToday
                  ? 'Today\'s Attendance is Open'
                  : 'Open ${DateFormat('EEEE').format(today)} Attendance',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: weekdays.map((date) {
              final isToday = DateUtils.isSameDay(date, today);
              final isOpen = isToday && _isAttendanceOpenToday;
              return FilledButton.tonalIcon(
                onPressed: isToday && _isSchoolWeekday
                    ? _openTodayAttendance
                    : null,
                icon: Icon(
                  isOpen ? Icons.check_circle_rounded : Icons.today_rounded,
                  size: 18,
                ),
                label: Text(
                  isToday && !isOpen
                      ? 'Open ${DateFormat('EEE').format(date)}\n${DateFormat('MMM d').format(date)}'
                      : '${DateFormat('EEE').format(date)}\n${DateFormat('MMM d').format(date)}',
                  textAlign: TextAlign.center,
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  backgroundColor: isOpen ? Colors.green.shade700 : null,
                  foregroundColor: isOpen ? Colors.white : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRfidSectionSelector() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF7FAFD),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFD1E0EF)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RFID Attendance Section',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose the class section allowed to use this RFID reader.',
          style: TextStyle(color: Color(0xFF526477), fontSize: 13),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ChildSection.values.map((section) {
            return ChoiceChip(
              label: Text(section.label),
              selected: _selectedRfidSection == section,
              onSelected: !_isAttendanceOpenToday
                  ? null
                  : (selected) {
                      setState(() {
                        _selectedRfidSection = selected ? section : null;
                        _rfidFeedback = selected
                            ? '${section.label} selected. ${_rfid.isConnected ? 'Ready to scan a registered child card.' : 'Connect the RFID reader to scan.'}'
                            : 'Select an RFID attendance section.';
                      });
                    },
            );
          }).toList(),
        ),
      ],
    ),
  );

  Widget _attendanceButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) => ElevatedButton.icon(
    onPressed: _selectedChild == null || !_isAttendanceOpenToday ? null : onTap,
    icon: Icon(icon),
    label: Text(label),
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 68),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    ),
  );
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .8),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF102A72),
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ],
    ),
  );
}
