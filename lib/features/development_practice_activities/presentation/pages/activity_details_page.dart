import 'package:flutter/material.dart';

import '../../domain/entities/practice_activity.dart';
import '../controllers/practice_activities_controller.dart';
import 'practice_activity_player_page.dart';

class ActivityDetailsPage extends StatefulWidget {
  const ActivityDetailsPage({
    super.key,
    required this.activity,
    required this.controller,
    required this.parentUid,
    this.childId,
  });

  final PracticeActivity activity;
  final PracticeActivitiesController controller;
  final String parentUid;
  final String? childId;

  @override
  State<ActivityDetailsPage> createState() => _ActivityDetailsPageState();
}

class _ActivityDetailsPageState extends State<ActivityDetailsPage> {
  bool _isSaving = false;

  Future<void> _markCompleted() async {
    setState(() => _isSaving = true);
    await widget.controller.complete(
      activity: widget.activity,
      parentUid: widget.parentUid,
      childId: widget.childId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Activity marked as completed on this device.')),
    );
    Navigator.pop(context, true);
  }

  Future<void> _openPlayer() async {
    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PracticeActivityPlayerPage(
          activity: widget.activity,
          controller: widget.controller,
          parentUid: widget.parentUid,
          childId: widget.childId,
        ),
      ),
    );
    if (!mounted || completed != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Great practice! Activity saved as completed on this device.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final isCompleted = widget.controller.completedActivityIds.contains(widget.activity.id);
        final colors = Theme.of(context).colorScheme;
        final screenSize = MediaQuery.sizeOf(context);
        final isCompact = screenSize.width < 600;
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: isCompact ? 16 : 32,
            vertical: 24,
          ),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 760,
              maxHeight: screenSize.height - 48,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Activity Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: colors.secondaryContainer,
                      child: Icon(Icons.self_improvement, color: colors.onSecondaryContainer, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.activity.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(widget.activity.domain.label)),
                    Chip(avatar: const Icon(Icons.schedule, size: 16), label: Text('${widget.activity.estimatedDurationMinutes} min')),
                    Chip(avatar: const Icon(Icons.signal_cellular_alt, size: 16), label: Text(widget.activity.difficulty.label)),
                  ],
                ),
                const SizedBox(height: 24),
                Text('About this activity', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(widget.activity.description, style: const TextStyle(height: 1.45)),
                const SizedBox(height: 24),
                Text('How to do it', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...widget.activity.instructions.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: colors.primaryContainer,
                          child: Text('${entry.key + 1}', style: TextStyle(color: colors.onPrimaryContainer, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(entry.value, style: const TextStyle(height: 1.4))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  color: colors.surfaceContainerHighest,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.favorite_outline),
                        SizedBox(width: 12),
                        Expanded(child: Text('Follow your child’s pace. Participation is optional, and there is no grade, approval, evidence, or submission.', style: TextStyle(height: 1.35))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _openPlayer,
                    icon: Icon(isCompleted ? Icons.replay : Icons.play_circle_outline),
                    label: Text(isCompleted ? 'Play again' : 'Play visual activity'),
                  ),
                ),
                if (!isCompleted) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : _markCompleted,
                      icon: const Icon(Icons.check),
                      label: const Text('Mark completed after practising offline'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}
