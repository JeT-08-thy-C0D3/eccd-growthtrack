import 'package:flutter_test/flutter_test.dart';
import 'package:eccd_growthtrack/features/attendance/domain/attendance_model.dart';
import 'package:eccd_growthtrack/features/rfid/rfid_service.dart';

void main() {
  test('normalizes RFID UID consistently', () {
    expect(normalizeRfidUid('04:a1-b2 c3'), '04A1B2C3');
    expect(normalizeRfidUid('  ab cd  '), 'ABCD');
  });

  test('debounces repeated UID scans for five seconds', () {
    final gate = RfidScanDebouncer();
    final start = DateTime.utc(2026, 11, 9, 0, 0, 0);
    expect(gate.accept('04:a1-b2', now: start), isTrue);
    expect(
      gate.accept('04A1B2', now: start.add(const Duration(seconds: 4))),
      isFalse,
    );
    expect(
      gate.accept('04A1B2', now: start.add(const Duration(seconds: 5))),
      isTrue,
    );
  });

  test('simulated service emits normalized scan JSON once', () async {
    final service = SimulatedRfidService();
    final message = service.messages.first;
    service.emitScan('04:a1-b2', scanId: 'test-scan');
    final scan = await message;
    expect(scan.type, 'SCAN');
    expect(scan.uid, '04A1B2');
    expect(scan.scanId, 'test-scan');
    await service.dispose();
  });

  test('parses newline JSON protocol metadata including ACK event id', () {
    final message = RfidMessage.fromLine(
      '{"type":"ACK","eventId":"attendance-001","ok":true}',
    );
    expect(message.type, 'ACK');
    expect(message.eventId, 'attendance-001');
  });

  test('attendance model preserves original timestamp and RFID source', () {
    final attendance = AttendanceModel(
      childId: 'CHILD-001',
      attendanceDate: '2026-11-09',
      attendanceTime: '08:30:45',
      status: 'Present',
      updatedAt: '2026-11-09T00:30:45.000Z',
      attendanceMethod: 'rfid',
      eventTimestampUtc: '2026-11-09T00:30:45.000Z',
    );
    expect(
      AttendanceModel.fromMap(attendance.toMap()).eventTimestampUtc,
      '2026-11-09T00:30:45.000Z',
    );
    expect(
      AttendanceModel.fromMap(attendance.toMap()).attendanceMethod,
      'rfid',
    );
  });
}
