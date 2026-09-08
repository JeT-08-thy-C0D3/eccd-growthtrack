import 'package:flutter/material.dart';
import '../../reports/domain/development_summary_model.dart';

class ChildDevelopmentSummaryView extends StatelessWidget {
  final DevelopmentSummaryModel summary;
  const ChildDevelopmentSummaryView({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Development Summary')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 8),
            Text(summary.developmentSummary, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            _buildSection('Strengths', summary.strengthAreas, Icons.star, Colors.green),
            const SizedBox(height: 24),
            _buildSection('Areas for Improvement', summary.improvementAreas, Icons.trending_up, Colors.orange),
            const SizedBox(height: 24),
            _buildSection('Home Activities', summary.suggestedHomeActivities, Icons.home, Colors.purple),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'Approved by ${summary.approvedBy} on ${summary.approvedDate}',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Text(content, style: const TextStyle(fontSize: 15)),
        ),
      ],
    );
  }
}
