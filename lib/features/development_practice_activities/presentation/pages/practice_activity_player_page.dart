import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/practice_activity.dart';
import '../controllers/practice_activities_controller.dart';

/// A guided, visual version of a practice activity. Completion is recorded only
/// after the parent and child finish the final visual step together.
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
  State<PracticeActivityPlayerPage> createState() =>
      _PracticeActivityPlayerPageState();
}

class _PracticeActivityPlayerPageState
    extends State<PracticeActivityPlayerPage> {
  late final List<_PracticeStep> _steps;
  int _stepIndex = 0;
  String? _selectedOption;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _steps = _stepsFor(widget.activity);
  }

  Future<void> _continue() async {
    if (_selectedOption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose what you tried before continuing.'),
        ),
      );
      return;
    }

    if (_stepIndex < _steps.length - 1) {
      setState(() {
        _stepIndex++;
        _selectedOption = null;
      });
      return;
    }

    setState(() => _isSaving = true);
    await widget.controller.complete(
      activity: widget.activity,
      parentUid: widget.parentUid,
      childId: widget.childId,
    );
    if (!mounted) return;
    await _showCompletionDialog();
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _showCompletionDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(
          Icons.emoji_events_rounded,
          size: 54,
          color: Color(0xFFF5AA16),
        ),
        title: const Text('Activity completed!', textAlign: TextAlign.center),
        content: Text(
          '${widget.activity.title} is now in Completed Activities for this child.',
          textAlign: TextAlign.center,
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

  void _restart() {
    setState(() {
      _stepIndex = 0;
      _selectedOption = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final step = _steps[_stepIndex];
    final isLastStep = _stepIndex == _steps.length - 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Visual activity')),
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
                      minHeight: 9,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Step ${_stepIndex + 1} of ${_steps.length}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                widget.activity.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _VisualActivityScene(step: step, stepIndex: _stepIndex),
              const SizedBox(height: 24),
              Text(
                step.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                step.prompt,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.45),
              ),
              const SizedBox(height: 24),
              Text(
                'What did you try?',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...step.options.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ChoiceCard(
                    index: entry.key,
                    label: entry.value,
                    selected: _selectedOption == entry.value,
                    onTap: () => setState(() => _selectedOption = entry.value),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Take your time. An adult should supervise all movement and materials.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _restart,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Restart activity'),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _isSaving ? null : _continue,
                icon: Icon(
                  isLastStep
                      ? Icons.check_circle_rounded
                      : Icons.arrow_forward_rounded,
                ),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : isLastStep
                      ? 'Finish and mark completed'
                      : 'Continue to next step',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisualActivityScene extends StatefulWidget {
  const _VisualActivityScene({required this.step, required this.stepIndex});

  final _PracticeStep step;
  final int stepIndex;

  @override
  State<_VisualActivityScene> createState() => _VisualActivitySceneState();
}

class _VisualActivitySceneState extends State<_VisualActivityScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final wave = math.sin(_controller.value * math.pi);
            return DecoratedBox(
              decoration: BoxDecoration(color: step.background),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 440),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(.12, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: Image.asset(
                        step.visualAssetPath,
                        key: ValueKey(
                          '${step.visualAssetPath}-${widget.stepIndex}',
                        ),
                        fit: BoxFit.cover,
                        alignment: Alignment(
                          -1 + widget.stepIndex.toDouble(),
                          0,
                        ),
                        errorBuilder: (_, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x12071D2E), Color(0x7A071D2E)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24 + (wave * 15),
                    top: 25,
                    child: _SceneBubble(
                      icon: step.supportingIcons[0],
                      color: step.accent,
                    ),
                  ),
                  Positioned(
                    right: 28 + (wave * 12),
                    bottom: 24,
                    child: _SceneBubble(
                      icon: step.supportingIcons[1],
                      color: step.accent,
                    ),
                  ),
                  Center(
                    child: Transform.translate(
                      offset: Offset(0, -10 * wave),
                      child: Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .92),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: step.accent.withValues(alpha: .25),
                              blurRadius: 24,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(step.icon, color: step.accent, size: 48),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .92),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        step.visualCaption,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: step.accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SceneBubble extends StatelessWidget {
  const _SceneBubble({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 54,
    height: 54,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .84),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: color, size: 29),
  );
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.index,
    required this.label,
    required this.selected,
    required this.onTap,
  });

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
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: selected
                    ? colors.primary
                    : colors.surfaceContainerHighest,
                foregroundColor: selected
                    ? colors.onPrimary
                    : colors.onSurfaceVariant,
                child: selected
                    ? const Icon(Icons.check, size: 18)
                    : Text(
                        '${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PracticeStep {
  const _PracticeStep({
    required this.title,
    required this.prompt,
    required this.options,
    required this.icon,
    required this.supportingIcons,
    required this.background,
    required this.accent,
    required this.visualCaption,
    required this.visualAssetPath,
  });

  final String title;
  final String prompt;
  final List<String> options;
  final IconData icon;
  final List<IconData> supportingIcons;
  final Color background;
  final Color accent;
  final String visualCaption;
  final String visualAssetPath;
}

List<_PracticeStep> _stepsFor(PracticeActivity activity) {
  final style = _visualStyleFor(activity.domain);
  _PracticeStep step(
    String title,
    String prompt,
    List<String> options,
    IconData icon,
    String caption,
  ) => _PracticeStep(
    title: title,
    prompt: prompt,
    options: options,
    icon: icon,
    supportingIcons: style.supportingIcons,
    background: style.background,
    accent: style.accent,
    visualCaption: caption,
    visualAssetPath: style.visualAssetPath,
  );

  switch (activity.id) {
    case 'gross-motor-balance-path':
      return [
        step(
          'Set up the path',
          'Place safe cushions, paper shapes, or a taped line on a clear floor.',
          ['Cushion path', 'Paper shapes', 'Tape line'],
          Icons.route_rounded,
          'LOOK - STEP - BALANCE',
        ),
        step(
          'Walk the path',
          'Invite the child to walk slowly from one end to the other.',
          ['Tiny steps', 'Big steps', 'Hold a hand'],
          Icons.directions_walk_rounded,
          'STEP WITH CARE',
        ),
        step(
          'Celebrate the finish',
          'Pause, smile, and try the path again in a new way if the child wants.',
          ['High five', 'Try again', 'Make it longer'],
          Icons.emoji_events_rounded,
          'YOU DID IT',
        ),
      ];
    case 'gross-motor-animal-moves':
      return [
        step(
          'Choose an animal',
          'Pick a safe animal movement to copy together.',
          ['Frog hop', 'Duck waddle', 'Elephant stomp'],
          Icons.pets_rounded,
          'PICK AN ANIMAL',
        ),
        step(
          'Move together',
          'Copy the movement in an open, safe space.',
          ['Hop', 'Waddle', 'Stomp'],
          Icons.directions_run_rounded,
          'MOVE YOUR BODY',
        ),
        step(
          'Make a new move',
          'Let the child choose one more animal to lead.',
          ['Child chooses', 'Copy each other', 'Make an animal sound'],
          Icons.record_voice_over_rounded,
          'YOUR TURN TO LEAD',
        ),
      ];
    case 'fine-motor-tong-transfer':
      return [
        step(
          'Gather safe items',
          'Put large soft objects in one bowl and an empty bowl beside it.',
          ['Pom-poms', 'Blocks', 'Rolled socks'],
          Icons.inventory_2_rounded,
          'READY TO SORT',
        ),
        step(
          'Pick and move',
          'Use fingers, a spoon, or child-safe tongs to move one item at a time.',
          ['Two fingers', 'Spoon', 'Tongs'],
          Icons.back_hand_rounded,
          'PICK - MOVE - DROP',
        ),
        step(
          'Count the moves',
          'Notice how many items made it to the new bowl.',
          ['Count aloud', 'Name colours', 'Switch hands'],
          Icons.format_list_numbered_rounded,
          'LOOK AT THE PROGRESS',
        ),
      ];
    case 'fine-motor-shape-collage':
      return [
        step(
          'Choose paper',
          'Offer safe paper pieces and a background sheet.',
          ['Colour paper', 'Magazine paper', 'Scrap paper'],
          Icons.auto_awesome_mosaic_rounded,
          'CHOOSE AND CREATE',
        ),
        step(
          'Make shapes',
          'Tear, fold, or place pieces into simple shapes.',
          ['Circle', 'Triangle', 'Long strip'],
          Icons.category_rounded,
          'MAKE A SHAPE',
        ),
        step(
          'Build the picture',
          'Arrange the pieces together and talk about the picture.',
          ['Glue it', 'Name it', 'Add one more piece'],
          Icons.brush_rounded,
          'YOUR ARTWORK',
        ),
      ];
    case 'self-help-dressing-practice':
      return [
        step(
          'Pick one item',
          'Choose one familiar clothing item for a calm practice.',
          ['Socks', 'Shirt', 'Jacket'],
          Icons.checkroom_rounded,
          'ONE SMALL STEP',
        ),
        step(
          'Try before helping',
          'Model the first part, then give time for the child to try.',
          ['Pull up', 'Push through', 'Fasten'],
          Icons.accessibility_new_rounded,
          'I CAN TRY',
        ),
        step(
          'Put it away',
          'Return the item to its usual place when finished.',
          ['Basket', 'Drawer', 'Shelf'],
          Icons.inventory_rounded,
          'ALL TIDY',
        ),
      ];
    case 'self-help-clean-up-routine':
      return [
        step(
          'Choose a few things',
          'Pick three to five toys or materials to put away.',
          ['Blocks', 'Books', 'Soft toys'],
          Icons.toys_rounded,
          'LET US TIDY',
        ),
        step(
          'Match each home',
          'Show where an item belongs, then let the child match the next one.',
          ['Bin', 'Shelf', 'Basket'],
          Icons.home_work_rounded,
          'EVERYTHING HAS A HOME',
        ),
        step(
          'Finish together',
          'Celebrate the clear space with a short song or countdown.',
          ['Count down', 'Sing a song', 'High five'],
          Icons.cleaning_services_rounded,
          'CLEAN SPACE, HAPPY FACE',
        ),
      ];
    case 'receptive-language-listen-and-find':
      return [
        step(
          'Look at the choices',
          'Place two or three familiar items where the child can see them.',
          ['Cup and ball', 'Book and shoe', 'Toy and spoon'],
          Icons.visibility_rounded,
          'LOOK CLOSELY',
        ),
        step(
          'Name one item',
          'Say one simple direction and pause to let the child respond.',
          ['Find the cup', 'Bring the ball', 'Point to the book'],
          Icons.hearing_rounded,
          'LISTEN AND FIND',
        ),
        step(
          'Try two steps',
          'Add one more simple action when the child is ready.',
          ['Find and give', 'Pick up and place', 'Touch and point'],
          Icons.double_arrow_rounded,
          'TWO STEPS TOGETHER',
        ),
      ];
    case 'receptive-language-sound-hunt':
      return [
        step(
          'Be quiet and listen',
          'Pause safely and listen for a sound nearby.',
          ['Bird sound', 'Fan sound', 'Footsteps'],
          Icons.hearing_rounded,
          'LISTEN',
        ),
        step(
          'Guess the sound',
          'Ask what made the sound and offer choices if needed.',
          ['Inside sound', 'Outside sound', 'People sound'],
          Icons.quiz_rounded,
          'WHAT DID YOU HEAR?',
        ),
        step(
          'Talk about it',
          'Describe the sound using a word, gesture, or picture.',
          ['Loud or soft', 'Near or far', 'Fast or slow'],
          Icons.chat_bubble_outline_rounded,
          'TALK ABOUT SOUND',
        ),
      ];
    case 'expressive-language-story-bag':
      return [
        step(
          'Pick three objects',
          'Place three familiar items in a bag or box.',
          ['Toy', 'Spoon', 'Small book'],
          Icons.shopping_bag_rounded,
          'WHAT IS INSIDE?',
        ),
        step(
          'Take one out',
          'Take turns choosing an object and naming it or making its sound.',
          ['Name it', 'Point to it', 'Make a sound'],
          Icons.redeem_rounded,
          'TAKE A TURN',
        ),
        step(
          'Make a tiny story',
          'Add one sentence for each object together.',
          ['First', 'Then', 'Last'],
          Icons.menu_book_rounded,
          'TELL THE STORY',
        ),
      ];
    case 'expressive-language-picture-talk':
      return [
        step(
          'Choose a picture',
          'Look at a family photo, book picture, or favourite object.',
          ['Family photo', 'Book page', 'Toy'],
          Icons.photo_rounded,
          'LOOK AND TALK',
        ),
        step(
          'Ask an open question',
          'Give the child time to share an idea, word, or gesture.',
          ['Who is here?', 'What happened?', 'What do you see?'],
          Icons.forum_rounded,
          'YOUR IDEAS MATTER',
        ),
        step(
          'Add one word',
          'Repeat the child’s idea and add one helpful word.',
          ['A colour', 'An action', 'A feeling'],
          Icons.add_comment_rounded,
          'SAY A LITTLE MORE',
        ),
      ];
    case 'cognitive-sort-and-match':
      return [
        step(
          'Gather items',
          'Choose safe items that differ by colour, shape, or size.',
          ['Buttons', 'Blocks', 'Socks'],
          Icons.widgets_rounded,
          'LOOK FOR CLUES',
        ),
        step(
          'Make groups',
          'Invite the child to put items that belong together in a group.',
          ['Same colour', 'Same shape', 'Same size'],
          Icons.account_tree_rounded,
          'SORT AND MATCH',
        ),
        step(
          'Explain a choice',
          'Ask why two items belong together; any answer is welcome.',
          ['Show it', 'Say it', 'Point to it'],
          Icons.lightbulb_rounded,
          'TELL ME WHY',
        ),
      ];
    case 'cognitive-sequence-the-day':
      return [
        step(
          'Remember the day',
          'Choose two or three things that happened today.',
          ['Breakfast', 'Playtime', 'Bath time'],
          Icons.today_rounded,
          'REMEMBER',
        ),
        step(
          'Put them in order',
          'Ask what happened first, next, and last.',
          ['First', 'Next', 'Last'],
          Icons.sort_rounded,
          'PUT IN ORDER',
        ),
        step(
          'Tell it again',
          'Retell the sequence using drawings, objects, or words.',
          ['Draw it', 'Act it out', 'Use objects'],
          Icons.history_edu_rounded,
          'TELL THE DAY',
        ),
      ];
    case 'social-emotional-feelings-check-in':
      return [
        step(
          'Look at feelings',
          'Show two or three feeling faces or name the feelings.',
          ['Happy', 'Sad', 'Excited'],
          Icons.sentiment_satisfied_alt_rounded,
          'HOW DO I FEEL?',
        ),
        step(
          'Choose a feeling',
          'Invite the child to point, show, or name a feeling.',
          ['Point to a face', 'Make a face', 'Say a word'],
          Icons.face_rounded,
          'IT IS OK TO FEEL',
        ),
        step(
          'Choose a calm idea',
          'Practise one gentle way to feel calm when feelings are big.',
          ['Slow breaths', 'Ask for a hug', 'Quiet break'],
          Icons.self_improvement_rounded,
          'CALM TOGETHER',
        ),
      ];
    case 'social-emotional-turn-taking':
      return [
        step(
          'Pick a shared game',
          'Choose a simple activity with a clear turn.',
          ['Roll a ball', 'Pass a toy', 'Build together'],
          Icons.sports_baseball_rounded,
          'READY TO SHARE',
        ),
        step(
          'Name each turn',
          'Use “my turn” and “your turn” as you play.',
          ['My turn', 'Your turn', 'Our turn'],
          Icons.swap_horiz_rounded,
          'TAKE TURNS',
        ),
        step(
          'Celebrate waiting',
          'Notice and praise friendly waiting and sharing.',
          ['Say thank you', 'High five', 'Try again'],
          Icons.volunteer_activism_rounded,
          'KIND PLAY',
        ),
      ];
    case 'moral-cultural-gratitude':
      return [
        step(
          'Choose a quiet moment',
          'Sit together in a calm, comfortable place.',
          ['At home', 'Before a meal', 'Before sleep'],
          Icons.nightlight_round_rounded,
          'A QUIET MOMENT',
        ),
        step(
          'Share appreciation',
          'Each person names something or someone they appreciate.',
          ['A person', 'A place', 'A helpful thing'],
          Icons.favorite_rounded,
          'THANK YOU',
        ),
        step(
          'Connect as a family',
          'Share why it matters in a way that fits your family’s values.',
          ['Tell a story', 'Say a prayer', 'Give a hug'],
          Icons.family_restroom_rounded,
          'TOGETHER',
        ),
      ];
    case 'moral-cultural-family-tradition':
      return [
        step(
          'Choose a tradition',
          'Pick a family song, story, greeting, or practice to share.',
          ['Song', 'Story', 'Greeting'],
          Icons.celebration_rounded,
          'OUR FAMILY',
        ),
        step(
          'Share its meaning',
          'Tell the child where it came from or why it is important.',
          ['Who taught it?', 'When do we do it?', 'Why do we love it?'],
          Icons.auto_stories_rounded,
          'SHARE THE MEANING',
        ),
        step(
          'Join in together',
          'Invite the child to take part in a comfortable way.',
          ['Sing together', 'Repeat a greeting', 'Ask a question'],
          Icons.groups_rounded,
          'BELONG TOGETHER',
        ),
      ];
  }
  return const [];
}

class _VisualStyle {
  const _VisualStyle(
    this.background,
    this.accent,
    this.supportingIcons,
    this.visualAssetPath,
  );

  final Color background;
  final Color accent;
  final List<IconData> supportingIcons;
  final String visualAssetPath;
}

_VisualStyle _visualStyleFor(PracticeDomain domain) {
  switch (domain) {
    case PracticeDomain.grossMotor:
      return const _VisualStyle(Color(0xFFE1F6EC), Color(0xFF18794E), [
        Icons.park_rounded,
        Icons.star_rounded,
      ], 'assets/images/practice_activities/gross_motor_sequence.png');
    case PracticeDomain.fineMotor:
      return const _VisualStyle(Color(0xFFFFF1DF), Color(0xFFC36D10), [
        Icons.circle_rounded,
        Icons.auto_awesome_rounded,
      ], 'assets/images/practice_activities/fine_motor_sequence.png');
    case PracticeDomain.selfHelp:
      return const _VisualStyle(Color(0xFFE8F1FF), Color(0xFF2B62B8), [
        Icons.home_rounded,
        Icons.check_circle_rounded,
      ], 'assets/images/practice_activities/self_help_sequence.png');
    case PracticeDomain.receptiveLanguage:
      return const _VisualStyle(Color(0xFFEAF7F9), Color(0xFF087B83), [
        Icons.hearing_rounded,
        Icons.visibility_rounded,
      ], 'assets/images/practice_activities/receptive_language_sequence.png');
    case PracticeDomain.expressiveLanguage:
      return const _VisualStyle(Color(0xFFF5EAFE), Color(0xFF7838A5), [
        Icons.chat_rounded,
        Icons.mic_rounded,
      ], 'assets/images/practice_activities/expressive_language_sequence.png');
    case PracticeDomain.cognitive:
      return const _VisualStyle(Color(0xFFFFF7D9), Color(0xFF9A6A00), [
        Icons.extension_rounded,
        Icons.lightbulb_rounded,
      ], 'assets/images/practice_activities/cognitive_sequence.png');
    case PracticeDomain.socialEmotional:
      return const _VisualStyle(Color(0xFFFFEAF1), Color(0xFFC43B6E), [
        Icons.favorite_rounded,
        Icons.sentiment_satisfied_rounded,
      ], 'assets/images/practice_activities/social_emotional_sequence.png');
    case PracticeDomain.moralSpiritualCultural:
      return const _VisualStyle(Color(0xFFEEE9FF), Color(0xFF6245A3), [
        Icons.diversity_1_rounded,
        Icons.star_rounded,
      ], 'assets/images/practice_activities/moral_cultural_sequence.png');
  }
}
