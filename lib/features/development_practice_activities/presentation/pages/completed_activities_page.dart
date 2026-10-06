import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../auth/data/auth_repository_impl.dart';
import '../../data/repositories/practice_activity_repository_impl.dart';
import '../../domain/entities/practice_completion.dart';
import '../../domain/usecases/get_completed_practice_activities.dart';

class CompletedActivitiesPage extends StatefulWidget {
  const CompletedActivitiesPage({super.key, this.parentUid, this.childId});

  final String? parentUid;
  final String? childId;

  @override
  State<CompletedActivitiesPage> createState() => _CompletedActivitiesPageState();
}

class _CompletedActivitiesPageState extends State<CompletedActivitiesPage> {
  List<PracticeCompletion> _completions = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final user = await AuthRepositoryImpl().getCurrentUser();
    final parentUid = widget.parentUid ?? user?.uid ?? 'local-parent';
    final useCase = GetCompletedPracticeActivities(PracticeActivityRepositoryImpl());
    final completions = await useCase(parentUid: parentUid, childId: widget.childId);
    if (!mounted) return;
    setState(() {
      _completions = completions;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Completed Activities')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _completions.isEmpty
              ? _EmptyHistory(onBrowse: () => Navigator.pop(context))
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _completions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _CompletionTile(completion: _completions[index]),
                  ),
                ),
    );
  }
}

class _CompletionTile extends StatelessWidget {
  const _CompletionTile({required this.completion});

  final PracticeCompletion completion;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, yyyy • h:mm a').format(completion.completedAt.toLocal());
    return Card(
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE6F4EA),
          child: Icon(Icons.check, color: Colors.green),
        ),
        title: Text(completion.activityTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${completion.domainLabel}\n$date'),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('No completed activities yet', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('When you mark an activity as completed, it will appear here.', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: onBrowse, child: const Text('Browse activities')),
          ],
        ),
      ),
    );
  }
}
