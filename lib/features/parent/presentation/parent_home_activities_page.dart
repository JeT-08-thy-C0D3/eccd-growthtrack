import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../shared/models/child_model.dart';
import '../../home_activities/data/activity_repository.dart';
import '../../home_activities/domain/activity_model.dart';
import '../../home_activities/presentation/activity_submission_page.dart';

class ParentHomeActivitiesPage extends StatefulWidget {
  final ChildModel child;
  const ParentHomeActivitiesPage({super.key, required this.child});

  @override
  State<ParentHomeActivitiesPage> createState() =>
      _ParentHomeActivitiesPageState();
}

class _ParentHomeActivitiesPageState extends State<ParentHomeActivitiesPage> {
  final ActivityRepository _repository = ActivityRepositoryImpl();
  List<ActivityModel> _activities = [];
  bool _isLoading = true;
  String? _loadError;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _activityChanges;

  @override
  void initState() {
    super.initState();
    _loadActivities();
    _listenForAssignedActivities();
  }

  /// A parent who already has this page open sees newly assigned teacher work
  /// immediately, without needing to sign out, reopen the page, or refresh.
  void _listenForAssignedActivities() {
    if (!kIsWeb) return;
    final parentUid = FirebaseAuth.instance.currentUser?.uid;
    if (parentUid == null || parentUid.isEmpty) return;

    _activityChanges = FirebaseFirestore.instance
        .collection('activities')
        .where('child_id', isEqualTo: widget.child.childId)
        .where('parent_uid', isEqualTo: parentUid)
        .snapshots()
        .listen(
          (snapshot) {
            final activities =
                snapshot.docs
                    .map((doc) => ActivityModel.fromMap(doc.data()))
                    .toList()
                  ..sort((a, b) => b.createdDate.compareTo(a.createdDate));
            if (!mounted) return;
            setState(() {
              _activities = activities;
              _loadError = null;
              _isLoading = false;
            });
          },
          onError: (_) {
            // Keep the result of the normal one-time load visible if a live
            // listener temporarily loses its network connection.
          },
        );
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repository.getActivitiesForChild(
        widget.child.childId,
      );
      if (!mounted) return;
      setState(() {
        _activities = data;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = 'Unable to load home activities right now.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitActivity(ActivityModel activity) async {
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ActivitySubmissionPage(activity: activity),
      ),
    );
    if (submitted == true && mounted) {
      await _loadActivities();
    }
  }

  @override
  void dispose() {
    _activityChanges?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Activities for ${widget.child.firstName} ${widget.child.lastName}',
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 54,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  Text(_loadError!),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loadActivities,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            )
          : _activities.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_turned_in_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text('No home activities assigned yet.'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _activities.length,
              itemBuilder: (context, index) {
                final activity = _activities[index];
                final isCompleted = activity.status == 'Completed';

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                activity.activityTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                activity.status,
                                style: TextStyle(
                                  color: isCompleted
                                      ? Colors.green
                                      : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(activity.instructions),
                        const SizedBox(height: 16),
                        Text(
                          'Assigned on: ${activity.createdDate}\nDue: ${activity.dueDate}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        if (!isCompleted) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: activity.id == null
                                  ? null
                                  : () => _submitActivity(activity),
                              icon: const Icon(Icons.upload_file_rounded),
                              label: const Text('Submit with Proof'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: activity.id == null
                                  ? null
                                  : () => _submitActivity(activity),
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text('View Submitted Activity'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
