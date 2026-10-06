import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';

class ChildSummaryReport extends StatefulWidget {
  final ChildModel child;
  const ChildSummaryReport({super.key, required this.child});

  @override
  State<ChildSummaryReport> createState() => _ChildSummaryReportState();
}

class _ChildSummaryReportState extends State<ChildSummaryReport> {
  bool _isLoading = true;
  Map<String, dynamic>? _summaryData;
  List<_TimelineItem> _timelineItems = [];

  @override
  void initState() {
    super.initState();
    _loadReportAndTimeline();
  }

  Future<void> _loadReportAndTimeline() async {
    setState(() => _isLoading = true);

    final summary = await DatabaseHelper.instance.getChildProgressSummary(widget.child.id!);
    final evaluations = await DatabaseHelper.instance.getChildEvaluationHistory(widget.child.childId);
    final triangulations = await DatabaseHelper.instance.getTriangulationHistory(widget.child.childId);
    final approvedSummaries = await DatabaseHelper.instance.getApprovedSummariesByChild(widget.child.childId);
    final referrals = await DatabaseHelper.instance.getReferralsByChild(widget.child.childId);

    final List<_TimelineItem> events = [];

    for (final eval in evaluations) {
      final date = (eval['evaluation_date'] as String? ?? eval['date'] as String? ?? '').split('T')[0];
      final domain = eval['domain'] as String? ?? 'General';
      final score = eval['score'] ?? 0;
      final remarks = eval['remarks'] as String? ?? '';
      events.add(
        _TimelineItem(
          date: date,
          category: 'Evaluation',
          title: 'ECCD Evaluation: $domain',
          description: 'Score: $score / 4 pts${remarks.isNotEmpty ? ' • $remarks' : ''}',
          icon: Icons.assignment_turned_in,
          color: Colors.blue,
          badgeText: '$score / 4 pts',
        ),
      );
    }

    for (final tri in triangulations) {
      final rawDate = (tri['generated_date'] as String? ?? '').split(' ')[0];
      final date = rawDate.split('T')[0];
      final status = tri['development_status'] as String? ?? 'On Track';
      final summaryText = tri['triangulated_summary'] as String? ?? '';
      events.add(
        _TimelineItem(
          date: date,
          category: 'Triangulation Result',
          title: 'Triangulation Analysis Result',
          description: summaryText,
          icon: Icons.analytics,
          color: Colors.purple,
          badgeText: status,
        ),
      );
    }

    for (final sum in approvedSummaries) {
      final rawDate = (sum['approved_date'] as String? ?? sum['created_date'] as String? ?? '').split(' ')[0];
      final date = rawDate.split('T')[0];
      final summaryText = sum['development_summary'] as String? ?? '';
      final approver = sum['approved_by'] as String? ?? 'Teacher';
      events.add(
        _TimelineItem(
          date: date,
          category: 'Approved AI Summary',
          title: 'Approved Development Summary',
          description: summaryText,
          icon: Icons.auto_awesome,
          color: Colors.amber.shade800,
          badgeText: 'Approved by $approver',
        ),
      );
    }

    for (final ref in referrals) {
      final date = (ref['referral_date'] as String? ?? '').split('T')[0];
      final concern = ref['concern'] as String? ?? 'Developmental Concern';
      final desc = ref['description'] as String? ?? '';
      final status = ref['status'] as String? ?? 'Pending';
      events.add(
        _TimelineItem(
          date: date,
          category: 'Referral Case',
          title: 'Referral: $concern',
          description: desc,
          icon: Icons.assignment_late,
          color: Colors.deepOrange,
          badgeText: status,
        ),
      );
    }

    events.sort((a, b) => b.date.compareTo(a.date));

    if (mounted) {
      setState(() {
        _summaryData = summary;
        _timelineItems = events;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Progress: ${widget.child.firstName} ${widget.child.lastName}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'Attendance Overview', icon: Icons.calendar_month),
                  Card(
                    elevation: 0,
                    color: Colors.blue.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.blue.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Attendance Rate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(
                            '${(_summaryData?['attendance_rate'] as double? ?? 0.0).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: (_summaryData?['attendance_rate'] as double? ?? 0.0) > 80 ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _SectionHeader(title: 'Developmental Scores (Avg)', icon: Icons.insights),
                  _buildScoresList(),
                  const SizedBox(height: 32),
                  _SectionHeader(title: 'Development Timeline', icon: Icons.timeline),
                  const SizedBox(height: 8),
                  if (_timelineItems.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text('No timeline events recorded yet.'),
                      ),
                    )
                  else
                    _buildMaterial3Timeline(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildScoresList() {
    final List<Map<String, dynamic>> assessments = _summaryData?['assessments'] ?? [];
    if (assessments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('No ECCD evaluation scores found.'),
      );
    }

    return Column(
      children: assessments.map((item) {
        final avgScore = (item['avg_score'] as double? ?? 0.0);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item['domain'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text('${avgScore.toStringAsFixed(1)} / 4 pts', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: avgScore / 4.0,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                color: Colors.blue,
                borderRadius: BorderRadius.circular(10),
                minHeight: 8,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMaterial3Timeline() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _timelineItems.length,
      itemBuilder: (context, index) {
        final item = _timelineItems[index];
        final isLast = index == _timelineItems.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline Node and Connecting Line
              SizedBox(
                width: 48,
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: item.color, width: 2),
                      ),
                      child: Icon(item.icon, size: 18, color: item.color),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Timeline Content Card
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.date.isNotEmpty ? item.date : 'Recent',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (item.badgeText != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: item.color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    item.badgeText!,
                                    style: TextStyle(
                                      color: item.color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          if (item.description.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              item.description,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

class _TimelineItem {
  final String date;
  final String category;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String? badgeText;

  _TimelineItem({
    required this.date,
    required this.category,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.badgeText,
  });
}
