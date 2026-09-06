import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../auth/data/auth_repository_impl.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _childrenAttendance = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final teacher = await AuthRepositoryImpl().getCurrentUser();
    if (teacher != null) {
      final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      final data = await DatabaseHelper.instance.getAttendanceForDate(teacher.id!, dateStr);
      setState(() {
        _childrenAttendance = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateAttendance(int childId, String status) async {
    final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
    await DatabaseHelper.instance.markAttendance(childId, dateStr, status);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Monitoring'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2023),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _loadData();
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.today),
                const SizedBox(width: 8),
                Text(
                  "Date: ${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _childrenAttendance.isEmpty
                    ? const Center(child: Text('No children registered yet.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _childrenAttendance.length,
                        itemBuilder: (context, index) {
                          final child = _childrenAttendance[index];
                          final status = child['status'];

                          return Card(
                            child: ListTile(
                              title: Text(child['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _AttendanceButton(
                                    label: 'P',
                                    color: Colors.green,
                                    isSelected: status == 'Present',
                                    onTap: () => _updateAttendance(child['id'], 'Present'),
                                  ),
                                  const SizedBox(width: 4),
                                  _AttendanceButton(
                                    label: 'A',
                                    color: Colors.red,
                                    isSelected: status == 'Absent',
                                    onTap: () => _updateAttendance(child['id'], 'Absent'),
                                  ),
                                  const SizedBox(width: 4),
                                  _AttendanceButton(
                                    label: 'L',
                                    color: Colors.orange,
                                    isSelected: status == 'Late',
                                    onTap: () => _updateAttendance(child['id'], 'Late'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _AttendanceButton({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
