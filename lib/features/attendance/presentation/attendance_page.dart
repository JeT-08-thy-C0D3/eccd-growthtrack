import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../data/attendance_repository.dart';
import '../domain/attendance_model.dart';
import 'attendance_history_page.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final AttendanceRepository _repository = AttendanceRepositoryImpl();
  List<ChildModel> _children = [];
  ChildModel? _selectedChild;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    final teacher = await AuthRepositoryImpl().getCurrentUser();
    final data = teacher == null
        ? <ChildModel>[]
        : await DatabaseHelper.instance.readChildrenByTeacher(teacher.uid);
    setState(() {
      _children = data;
      _isLoading = false;
      if (_children.isNotEmpty) {
        _selectedChild = _children.first;
      }
    });
  }

  void _markAttendance(String status) async {
    if (_selectedChild == null) return;

    final now = DateTime.now();
    final attendance = AttendanceModel(
      childId: _selectedChild!.childId,
      attendanceDate: DateFormat('yyyy-MM-dd').format(now),
      attendanceTime: DateFormat('HH:mm:ss').format(now),
      status: status,
      updatedAt: now.toIso8601String(),
    );

    await _repository.addAttendance(attendance);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance recorded: ${_selectedChild!.firstName} is $status'),
          backgroundColor: status == 'Present' ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulated RFID Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              if (_selectedChild != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AttendanceHistoryPage(child: _selectedChild!),
                  ),
                );
              }
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.nfc, size: 80, color: Colors.blue),
                  const SizedBox(height: 24),
                  const Text(
                    'RFID Simulation Mode',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select a child to simulate an RFID scan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 40),
                  DropdownButtonFormField<ChildModel>(
                    isExpanded: true,
                    initialValue: _selectedChild,
                    decoration: const InputDecoration(
                      labelText: 'Select Child (Simulate Scan)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: _children.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(
                          '${c.firstName} ${c.lastName} (${c.childId})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedChild = val),
                  ),
                  const SizedBox(height: 32),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final present = ElevatedButton.icon(
                        onPressed: () => _markAttendance('Present'),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Mark Present'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      );
                      final absent = ElevatedButton.icon(
                        onPressed: () => _markAttendance('Absent'),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Mark Absent'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      );
                      if (constraints.maxWidth < 360) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [present, const SizedBox(height: 12), absent],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: present),
                          const SizedBox(width: 16),
                          Expanded(child: absent),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 48),
                  const Text(
                    'Hardware Note: In the final production version, this manual selection will be replaced by a background service listening for RFID Serial input.',
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}
