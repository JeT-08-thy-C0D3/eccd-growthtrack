import 'package:flutter/material.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../shared/models/child_model.dart';
import '../../../../shared/widgets/brand_widgets.dart';
import '../../../auth/data/auth_repository_impl.dart';
import '../../domain/entities/practice_activity.dart';
import '../controllers/practice_activities_controller.dart';
import 'activity_details_page.dart';

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
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ActivityDetailsPage(
        activity: activity,
        controller: _controller,
        parentUid: _parentUid,
        childId: _selectedChildId,
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          color: const Color(0xFFF8FCFF),
          child: _isInitializing || _controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => _controller.load(
                    parentUid: _parentUid,
                    childId: _selectedChildId,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
                    children: [
                      const _PracticeHero(),
                      const SizedBox(height: 20),
                      const _PracticeInfoBanner(),
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
                                  child: Text(
                                    '${child.firstName} ${child.lastName}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (childId) async {
                            final child = _children.firstWhere(
                              (item) => item.childId == childId,
                            );
                            setState(() => _selectedChild = child);
                            await _controller.load(
                              parentUid: _parentUid,
                              childId: _selectedChildId,
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 20),
                      const Text(
                        'Browse by domain',
                        style: TextStyle(
                          color: Color(0xFF07135B),
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _DomainChip(
                              label: 'All',
                              selected: _controller.selectedDomain == null,
                              onTap: () => _selectDomain(null),
                              leading: Icons.check_rounded,
                            ),
                            const SizedBox(width: 9),
                            ...PracticeDomain.values.map(
                              (domain) => Padding(
                                padding: const EdgeInsets.only(right: 9),
                                child: _DomainChip(
                                  label: domain.label,
                                  selected:
                                      _controller.selectedDomain == domain,
                                  onTap: () => _selectDomain(domain),
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
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        )
                      else if (_controller.activities.isEmpty)
                        const _EmptyActivities()
                      else
                        ..._controller.activities.map(
                          (activity) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _ActivityCard(
                              activity: activity,
                              isCompleted: _controller.completedActivityIds
                                  .contains(activity.id),
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

class _PracticeHero extends StatelessWidget {
  const _PracticeHero();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Container(
      height: compact ? 250 : 156,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 22 : 28,
        vertical: compact ? 20 : 24,
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF8FF), Color(0xFFD5F0FF)],
        ),
      ),
      child: Stack(
        children: [
          if (!compact) ...[
            Positioned(
              right: 18,
              bottom: -42,
              child: Icon(
                Icons.emoji_people_rounded,
                size: 186,
                color: BrandColors.sky.withValues(alpha: .72),
              ),
            ),
            Positioned(
              right: 174,
              bottom: -18,
              child: Icon(
                Icons.spa_rounded,
                size: 105,
                color: BrandColors.green.withValues(alpha: .54),
              ),
            ),
            Positioned(
              right: 27,
              top: 12,
              child: Icon(
                Icons.home_rounded,
                size: 42,
                color: BrandColors.sunshine,
              ),
            ),
          ],
          compact
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1599F4),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: const Icon(
                        Icons.directions_run_rounded,
                        size: 35,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Practice Activities',
                      style: TextStyle(
                        color: Color(0xFF07135B),
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Fun and engaging activities to support your child’s development at home.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF166BB6),
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ],
                )
              : Row(
            children: [
              Container(
                width: 94,
                height: 94,
                decoration: BoxDecoration(
                  color: const Color(0xFF1599F4),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.directions_run_rounded,
                  size: 54,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 24),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Practice Activities',
                      style: TextStyle(
                        color: Color(0xFF07135B),
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 9),
                    Text(
                      "Fun and engaging activities to support your child’s development at home.",
                      style: TextStyle(color: Color(0xFF166BB6), fontSize: 17),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PracticeInfoBanner extends StatelessWidget {
  const _PracticeInfoBanner();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
    decoration: BoxDecoration(
      color: const Color(0xFFDFF3FF),
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Row(
      children: [
        Icon(
          Icons.lightbulb_outline_rounded,
          color: Color(0xFF1599F4),
          size: 31,
        ),
        SizedBox(width: 22),
        Expanded(
          child: Text(
            'Optional ideas for practising together at home. These activities are not teacher-assigned, graded, or submitted.',
            style: TextStyle(color: Color(0xFF1672C6), fontSize: 16),
          ),
        ),
      ],
    ),
  );
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.activity,
    required this.isCompleted,
    required this.onTap,
  });

  final PracticeActivity activity;
  final bool isCompleted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _domainColor(activity.domain);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(23),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            boxShadow: [
              BoxShadow(
                color: BrandColors.sky.withValues(alpha: .075),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(23),
                ),
                child: Icon(
                  _domainIcon(activity.domain),
                  color: color,
                  size: 37,
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: const TextStyle(
                        color: Color(0xFF07135B),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDFF3FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        activity.domain.label,
                        style: const TextStyle(
                          color: Color(0xFF1688DE),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      activity.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF60749C),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 18,
                      children: [
                        _InfoPill(
                          icon: Icons.schedule_outlined,
                          label: '${activity.estimatedDurationMinutes} min',
                        ),
                        _InfoPill(
                          icon: Icons.signal_cellular_alt_rounded,
                          label: activity.difficulty.label,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F9FD),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_rounded
                      : Icons.arrow_forward_ios_rounded,
                  color: isCompleted
                      ? BrandColors.green
                      : const Color(0xFF10245E),
                  size: isCompleted ? 26 : 21,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DomainChip extends StatelessWidget {
  const _DomainChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? leading;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFF1599F4) : const Color(0xFFF9FCFF),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0xFFD4E0ED),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              Icon(leading, size: 19, color: Colors.white),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF455879),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
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

Color _domainColor(PracticeDomain domain) {
  switch (domain) {
    case PracticeDomain.grossMotor:
      return const Color(0xFF16B978);
    case PracticeDomain.fineMotor:
      return const Color(0xFF7763E8);
    case PracticeDomain.selfHelp:
      return const Color(0xFFEC8D20);
    case PracticeDomain.receptiveLanguage:
      return const Color(0xFF208CE7);
    case PracticeDomain.expressiveLanguage:
      return const Color(0xFFE76492);
    case PracticeDomain.cognitive:
      return const Color(0xFF9A6CDA);
    case PracticeDomain.socialEmotional:
      return const Color(0xFFDC7E2B);
    case PracticeDomain.moralSpiritualCultural:
      return BrandColors.green;
  }
}
