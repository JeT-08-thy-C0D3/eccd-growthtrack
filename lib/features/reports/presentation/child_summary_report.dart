import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';

class ChildSummaryReport extends StatelessWidget {
  final ChildModel child;
  const ChildSummaryReport({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Report: ${child.name}')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: DatabaseHelper.instance.getChildProgressSummary(child.id!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No report data available.'));
          }

          final data = snapshot.data!;
          final List<Map<String, dynamic>> assessments = data['assessments'];
          final double attendanceRate = data['attendance_rate'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(title: 'Attendance Overview', icon: Icons.calendar_month),
                Card(
                  color: Colors.blue.withValues(alpha: 0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Attendance Rate', style: TextStyle(fontSize: 16)),
                        Text(
                          '${attendanceRate.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: attendanceRate > 80 ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _SectionHeader(title: 'Developmental Scores (Avg)', icon: Icons.insights),
                if (assessments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('No ECCD evaluations found.'),
                  )
                else
                  ...assessments.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item['domain'], style: const TextStyle(fontWeight: FontWeight.w500)),
                              Text('${(item['avg_score'] as double).toStringAsFixed(1)} pts'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: (item['avg_score'] as double) / 4, // Max score per domain in mock is 4
                            backgroundColor: Colors.grey.withValues(alpha: 0.2),
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(10),
                            minHeight: 8,
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 40),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Report generation for PDF coming soon!')),
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Download PDF Report'),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
