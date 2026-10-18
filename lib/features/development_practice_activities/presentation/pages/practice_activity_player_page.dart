import 'package:flutter/material.dart';

import '../../domain/entities/practice_activity.dart';
import '../controllers/practice_activities_controller.dart';

class PracticeActivityPlayerPage extends StatefulWidget {
  const PracticeActivityPlayerPage({
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
  State<PracticeActivityPlayerPage> createState() => _PracticeActivityPlayerPageState();
}

class _PracticeActivityPlayerPageState extends State<PracticeActivityPlayerPage> {
  late final List<_PracticeStep> _steps;
  int _stepIndex = 0;
  String? _selectedOption;
  bool _isSaving = false;
  int _score = 0;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _steps = _stepsFor(widget.activity.domain);
  }

  Future<void> _next() async {
    if (_selectedOption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose one way to try this step first!')),
      );
      return;
    }

    if (_stepIndex < _steps.length - 1) {
      setState(() {
        _score += 10 + (_streak * 2);
        _streak++;
        _stepIndex++;
        _selectedOption = null;
      });
      return;
    }

    setState(() => _isSaving = true);
    final finalScore = _score + 10 + (_streak * 2);
    await widget.controller.complete(
      activity: widget.activity,
      parentUid: widget.parentUid,
      childId: widget.childId,
    );
    if (!mounted) return;
    await _showCompletionDialog(finalScore);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _showCompletionDialog(int finalScore) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Text('🎉', style: TextStyle(fontSize: 48)),
            SizedBox(height: 8),
            Text('Great job, explorer!', textAlign: TextAlign.center),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('You finished this practice adventure.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text('⭐  ${_steps.length} stars    •    $finalScore points', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            const Text('Every try helps your child grow!', textAlign: TextAlign.center),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  void _startOver() {
    setState(() {
      _stepIndex = 0;
      _selectedOption = null;
      _score = 0;
      _streak = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final step = _steps[_stepIndex];
    final isLastStep = _stepIndex == _steps.length - 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Let’s practise together')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (_stepIndex + 1) / _steps.length,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${_stepIndex + 1}/${_steps.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _GameStat(icon: Icons.star_rounded, label: '${_stepIndex + (_selectedOption == null ? 0 : 1)} stars', color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  _GameStat(icon: Icons.bolt_rounded, label: '$_score pts', color: colors.primary),
                  const SizedBox(width: 8),
                  _GameStat(icon: Icons.local_fire_department_rounded, label: '$_streak streak', color: Colors.deepOrange),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                widget.activity.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.primary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Card(
                color: colors.primaryContainer,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    children: [
                      Text(step.emoji, style: const TextStyle(fontSize: 72)),
                      const SizedBox(height: 16),
                      Text(step.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text(step.prompt, textAlign: TextAlign.center, style: TextStyle(color: colors.onPrimaryContainer, height: 1.4)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Choose a way to try it', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...step.options.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _GameChoiceCard(
                    index: entry.key,
                    label: entry.value,
                    selected: _selectedOption == entry.value,
                    onTap: () {
                      setState(() {
                        _selectedOption = entry.value;
                        if (_streak == 0) _streak = 1;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Every choice earns a star. Let the child explore, talk, move, and try again as many times as needed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _startOver,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Start the activity again'),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _isSaving ? null : _next,
                icon: Icon(isLastStep ? Icons.check : Icons.arrow_forward),
                label: Text(_isSaving ? 'Saving…' : (isLastStep ? 'Finish and mark completed' : 'Next step')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameStat extends StatelessWidget {
  const _GameStat({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))),
          ],
        ),
      ),
    );
  }
}

class _GameChoiceCard extends StatelessWidget {
  const _GameChoiceCard({required this.index, required this.label, required this.selected, required this.onTap});

  final int index;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.secondaryContainer : colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? colors.primary : colors.outlineVariant, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: selected ? colors.primary : colors.surfaceContainerHighest,
                foregroundColor: selected ? colors.onPrimary : colors.onSurfaceVariant,
                child: selected ? const Icon(Icons.check, size: 18) : Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
              Icon(selected ? Icons.emoji_events : Icons.touch_app_outlined, color: selected ? Colors.amber.shade700 : colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _PracticeStep {
  const _PracticeStep({required this.emoji, required this.title, required this.prompt, required this.options});

  final String emoji;
  final String title;
  final String prompt;
  final List<String> options;
}

List<_PracticeStep> _stepsFor(PracticeDomain domain) {
  switch (domain) {
    case PracticeDomain.grossMotor:
      return const [
        _PracticeStep(emoji: '🌳', title: 'Stretch tall', prompt: 'Reach up high, then slowly bend down low.', options: ['Reach like a tree', 'Bend like a flower', 'Make a big stretch']),
        _PracticeStep(emoji: '👣', title: 'Follow the path', prompt: 'Walk along an imaginary line. A grown-up can hold your hand.', options: ['Tiny steps', 'Big steps', 'Side steps']),
        _PracticeStep(emoji: '🐸', title: 'Move like an animal', prompt: 'Choose an animal and copy its safe movement.', options: ['Hop like a frog', 'Waddle like a duck', 'Stomp like an elephant']),
      ];
    case PracticeDomain.fineMotor:
      return const [
        _PracticeStep(emoji: '🤏', title: 'Pinch and place', prompt: 'Pick up a safe object and move it into a cup or bowl.', options: ['Use two fingers', 'Use a spoon', 'Use kitchen tongs']),
        _PracticeStep(emoji: '✏️', title: 'Trace a path', prompt: 'Follow a line with a finger, crayon, or pencil.', options: ['Trace a spiral', 'Trace a zigzag', 'Trace a circle']),
        _PracticeStep(emoji: '🧱', title: 'Build it up', prompt: 'Make a small tower, then gently take it apart.', options: ['Stack blocks', 'Stack cups', 'Stack soft toys']),
      ];
    case PracticeDomain.selfHelp:
      return const [
        _PracticeStep(emoji: '👕', title: 'Choose an item', prompt: 'Let the child choose one safe item to practise with.', options: ['Socks', 'Shirt', 'Jacket']),
        _PracticeStep(emoji: '👐', title: 'Try one step', prompt: 'Give the child time to try one part before helping.', options: ['Pull up', 'Push through', 'Zip or close']),
        _PracticeStep(emoji: '🧺', title: 'Put it away', prompt: 'Finish by returning the item to its usual place.', options: ['Basket', 'Drawer', 'Shelf']),
      ];
    case PracticeDomain.receptiveLanguage:
      return const [
        _PracticeStep(emoji: '👀', title: 'Look and find', prompt: 'Name one familiar object and invite the child to find it.', options: ['Find the cup', 'Find the ball', 'Find the book']),
        _PracticeStep(emoji: '👂', title: 'Listen and do', prompt: 'Give one simple direction, then celebrate listening.', options: ['Touch your nose', 'Clap your hands', 'Wave hello']),
        _PracticeStep(emoji: '➡️', title: 'Two-step turn', prompt: 'Try two simple directions one after another.', options: ['Pick up and give', 'Find and place', 'Touch and point']),
      ];
    case PracticeDomain.expressiveLanguage:
      return const [
        _PracticeStep(emoji: '🖼️', title: 'Name the picture', prompt: 'Look at a picture or object and invite the child to name it.', options: ['Name it', 'Point to it', 'Make its sound']),
        _PracticeStep(emoji: '💬', title: 'Add a word', prompt: 'Repeat the child’s words and gently add one more word.', options: ['Say a colour', 'Say an action', 'Say a feeling']),
        _PracticeStep(emoji: '📖', title: 'Tell what happened', prompt: 'Use three objects or pictures to make a tiny story.', options: ['First…', 'Then…', 'Last…']),
      ];
    case PracticeDomain.cognitive:
      return const [
        _PracticeStep(emoji: '🔵', title: 'Find the match', prompt: 'Pair two objects that look alike or belong together.', options: ['Same colour', 'Same shape', 'Same use']),
        _PracticeStep(emoji: '🔺', title: 'Continue the pattern', prompt: 'Make a simple pattern and invite the child to continue it.', options: ['Red-blue', 'Big-small', 'Clap-stomp']),
        _PracticeStep(emoji: '❓', title: 'What comes next?', prompt: 'Talk about what happens next in a familiar routine.', options: ['After eating', 'After bathing', 'Before sleeping']),
      ];
    case PracticeDomain.socialEmotional:
      return const [
        _PracticeStep(emoji: '🙂', title: 'Show a feeling', prompt: 'Invite the child to show or name how a face might feel.', options: ['Happy', 'Sad', 'Excited']),
        _PracticeStep(emoji: '🤝', title: 'Take a turn', prompt: 'Play a short game using “my turn” and “your turn.”', options: ['Roll a ball', 'Pass a toy', 'Build together']),
        _PracticeStep(emoji: '💛', title: 'Choose calm', prompt: 'Practise one way to feel calm when emotions are big.', options: ['Slow breaths', 'Ask for a hug', 'Take a quiet break']),
      ];
    case PracticeDomain.moralSpiritualCultural:
      return const [
        _PracticeStep(emoji: '🌟', title: 'Choose kindness', prompt: 'Talk about one kind action the child can try today.', options: ['Help someone', 'Share something', 'Use kind words']),
        _PracticeStep(emoji: '🏠', title: 'Share a value', prompt: 'Share a family value, greeting, song, or tradition.', options: ['Family story', 'Special song', 'Respectful greeting']),
        _PracticeStep(emoji: '🙏', title: 'Appreciate together', prompt: 'Name one person, place, or thing your family appreciates.', options: ['Say thank you', 'Offer a prayer', 'Share gratitude']),
      ];
  }
}
