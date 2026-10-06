import 'package:flutter/material.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../shared/models/child_model.dart';
import '../../../auth/data/auth_repository_impl.dart';
import '../../domain/entities/practice_activity.dart';
import '../controllers/practice_activities_controller.dart';
import 'activity_details_page.dart';
import 'completed_activities_page.dart';

class PracticeActivitiesPage extends StatefulWidget {
  const PracticeActivitiesPage({super.key});

  @override
  State<PracticeActivitiesPage> createState() => _PracticeActivitiesPageState();
}

class _PracticeActivitiesPageState extends State<PracticeActivitiesPage> {
  late final PracticeActivitiesController _controller;
  List<ChildModel> _children = const [];
  ChildModel? _selectedChild;
  String _parentUid = '';
  bool _isInitializing = true;

  String? get _selectedChildId => _selectedChild?.childId;

  @override
  void initState() {
    super.initState();
    _controller = PracticeActivitiesController();
    _loadContext();
  }

  Future<void> _loadContext() async {
    final user = await AuthRepositoryImpl().getCurrentUser();
    var children = <ChildModel>[];
    if (user != null) {
      _parentUid = user.uid;
      children = await DatabaseHelper.instance.readChildrenByParent(user.uid);
    }

    if (!mounted) return;
    setState(() {
      _children = children;
      _selectedChild = children.isEmpty ? null : children.first;
      _parentUid = _parentUid.isEmpty ? 'local-parent' : _parentUid;
      _isInitializing = false;
    });
    await _controller.load(parentUid: _parentUid, childId: _selectedChildId);
  }

  Future<void> _selectDomain(PracticeDomain? domain) {
    return _controller.selectDomain(
      domain: domain,
      parentUid: _parentUid,
      childId: _selectedChildId,
    );
  }

  Future<void> _openActivity(PracticeActivity activity) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityDetailsPage(
          activity: activity,
          controller: _controller,
          parentUid: _parentUid,
          childId: _selectedChildId,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompletedActivitiesPage(
          parentUid: _parentUid,
          childId: _selectedChildId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Practice Activities'),
            actions: [
              IconButton(
                tooltip: 'Completed activities',
                icon: const Icon(Icons.history),
                onPressed: _openHistory,
              ),
            ],
          ),
          body: _isInitializing || _controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => _controller.load(
                    parentUid: _parentUid,
                    childId: _selectedChildId,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _IntroCard(),
                      if (_children.length > 1) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedChildId,
                          decoration: const InputDecoration(
                            labelText: 'Practising with',
                            prefixIcon: Icon(Icons.child_care_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: _children
                              .map(
                                (child) => DropdownMenuItem(
                                  value: child.childId,
                                  child: Text('${child.firstName} ${child.lastName}'),
                                ),
                              )
                              .toList(),
                          onChanged: (childId) async {
                            final child = _children.firstWhere((item) => item.childId == childId);
                            setState(() => _selectedChild = child);
                            await _controller.load(
                              parentUid: _parentUid,
                              childId: _selectedChildId,
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      Text(
                        'Browse by domain',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 42,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            FilterChip(
                              label: const Text('All'),
                              selected: _controller.selectedDomain == null,
                              onSelected: (_) => _selectDomain(null),
                            ),
                            const SizedBox(width: 8),
                            ...PracticeDomain.values.map(
                              (domain) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(domain.label),
                                  selected: _controller.selectedDomain == domain,
                                  onSelected: (_) => _selectDomain(domain),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_controller.errorMessage != null)
                        Text(
                          _controller.errorMessage!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        )
                      else if (_controller.activities.isEmpty)
                        const _EmptyActivities()
                      else
                        ..._controller.activities.map(
                          (activity) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ActivityCard(
                              activity: activity,
                              isCompleted: _controller.completedActivityIds.contains(activity.id),
                              onTap: () => _openActivity(activity),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, color: colors.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Optional ideas for practising together at home. These activities are not teacher-assigned, graded, or submitted.',
                style: TextStyle(color: colors.onPrimaryContainer, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity, required this.isCompleted, required this.onTap});

  final PracticeActivity activity;
  final bool isCompleted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.secondaryContainer,
                child: Icon(_domainIcon(activity.domain), color: colorScheme.onSecondaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(activity.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(activity.domain.label, style: TextStyle(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(activity.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        _InfoPill(icon: Icons.schedule_outlined, label: '${activity.estimatedDurationMinutes} min'),
                        _InfoPill(icon: Icons.signal_cellular_alt, label: activity.difficulty.label),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(isCompleted ? Icons.check_circle : Icons.chevron_right, color: isCompleted ? Colors.green : colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _EmptyActivities extends StatelessWidget {
  const _EmptyActivities();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: Text('No activities found for this domain.')),
    );
  }
}

IconData _domainIcon(PracticeDomain domain) {
  switch (domain) {
    case PracticeDomain.grossMotor:
      return Icons.directions_run;
    case PracticeDomain.fineMotor:
      return Icons.edit_outlined;
    case PracticeDomain.selfHelp:
      return Icons.backpack_outlined;
    case PracticeDomain.receptiveLanguage:
      return Icons.hearing_outlined;
    case PracticeDomain.expressiveLanguage:
      return Icons.record_voice_over_outlined;
    case PracticeDomain.cognitive:
      return Icons.psychology_outlined;
    case PracticeDomain.socialEmotional:
      return Icons.people_outline;
    case PracticeDomain.moralSpiritualCultural:
      return Icons.diversity_3_outlined;
  }
}
