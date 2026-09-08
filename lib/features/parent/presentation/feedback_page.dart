import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../../../shared/models/child_model.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _feedbackController = TextEditingController();
  bool _isSending = false;
  ChildModel? _child;

  @override
  void initState() {
    super.initState();
    _loadChild();
  }

  Future<void> _loadChild() async {
    final user = await AuthRepositoryImpl().getCurrentUser();
    if (user != null) {
      final children = await DatabaseHelper.instance.readChildrenByParent(user.id!);
      if (children.isNotEmpty) {
        setState(() {
          _child = children.first;
        });
      }
    }
  }

  void _sendFeedback() async {
    if (_feedbackController.text.isEmpty || _child == null) return;

    setState(() => _isSending = true);
    
    final user = await AuthRepositoryImpl().getCurrentUser();
    
    await DatabaseHelper.instance.insertFeedback({
      'child_id': _child!.childId,
      'parent_id': user!.id!,
      'message': _feedbackController.text,
      'date': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
    });

    setState(() => _isSending = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback sent to teacher successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Feedback')),
      body: _child == null 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Message for ${_child!.firstName}\'s Teacher',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your message will be visible to your child\'s assigned teacher and used for developmental triangulation.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _feedbackController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Enter your message here...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSending ? null : _sendFeedback,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSending 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Send Message', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
    );
  }
}
