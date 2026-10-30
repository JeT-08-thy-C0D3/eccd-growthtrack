import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../data/attendance_repository.dart';
import '../domain/attendance_model.dart';

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
    if (!mounted) return;
    setState(() {
      _children = data;
      _selectedChild = data.isEmpty ? null : data.first;
      _isLoading = false;
    });
  }

  Future<void> _markAttendance(String status) async {
    if (_selectedChild == null) return;
    final now = DateTime.now();
    await _repository.addAttendance(
      AttendanceModel(
        childId: _selectedChild!.childId,
        attendanceDate: DateFormat('yyyy-MM-dd').format(now),
        attendanceTime: DateFormat('HH:mm:ss').format(now),
        status: status,
        updatedAt: now.toIso8601String(),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Attendance recorded: ${_selectedChild!.firstName} is $status',
        ),
        backgroundColor: status == 'Present' ? Colors.green : Colors.red,
      ),
    );
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
                        'Simulated RFID Attendance',
                        style: TextStyle(
                          fontSize: 25,
                          height: 1.15,
                          color: Color(0xFF102A72),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Select a child and simulate an RFID scan to mark attendance.',
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
                  'Simulated RFID Attendance',
                  style: TextStyle(
                    fontSize: isPhone ? 28 : 33,
                    color: Color(0xFF102A72),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Select a child and simulate an RFID scan to mark attendance.',
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
        title: 'RFID Simulation',
        subtitle: 'For testing and demo purposes',
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
                    'Select Child',
                    style: TextStyle(
                      color: Color(0xFF102A72),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Choose a child to simulate an RFID scan.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        DropdownButtonFormField<ChildModel>(
          isExpanded: true,
          initialValue: _selectedChild,
          decoration: InputDecoration(
            labelText: 'Select Child (Simulate Scan)',
            prefixIcon: const Icon(Icons.person, color: BrandColors.navy),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          items: _children
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
                  'Hardware Note: In the final production version, this manual selection will be replaced by a background service listening for RFID Serial Input.',
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

  Widget _attendanceButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) => ElevatedButton.icon(
    onPressed: _selectedChild == null ? null : onTap,
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
