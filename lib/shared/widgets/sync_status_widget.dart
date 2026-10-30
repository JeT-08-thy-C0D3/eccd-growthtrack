/// Sync Status Widget
///
/// Displays current sync state to users with visual feedback.
/// Shows pending operations, last sync time, and errors.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/sync/unified_sync_service.dart';

class SyncStatusWidget extends StatefulWidget {
  final bool showLastSync;
  final bool showPendingCount;
  final VoidCallback? onSyncPressed;

  const SyncStatusWidget({
    super.key,
    this.showLastSync = true,
    this.showPendingCount = true,
    this.onSyncPressed,
  });

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  late final UnifiedSyncService _syncService;
  late final StreamController<void> _syncStatusStream;

  @override
  void initState() {
    super.initState();
    _syncService = UnifiedSyncService();
    _syncStatusStream = StreamController<void>.broadcast();

    _syncService.onStatusChanged(() {
      _syncStatusStream.add(null);
    });

    _syncService.onError((error) {
      _showErrorSnackBar(error);
    });
  }

  @override
  void dispose() {
    _syncStatusStream.close();
    super.dispose();
  }

  void _showErrorSnackBar(String error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sync error: $error'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: _syncStatusStream.stream,
      builder: (context, snapshot) {
        return _buildSyncStatus();
      },
    );
  }

  Widget _buildSyncStatus() {
    switch (_syncService.status) {
      case SyncStatus.idle:
        return _buildIdleStatus();
      case SyncStatus.syncing:
        return _buildSyncingStatus();
      case SyncStatus.error:
        return _buildErrorStatus();
      case SyncStatus.conflictDetected:
        return _buildConflictStatus();
    }
  }

  Widget _buildIdleStatus() {
    final pendingCount = _syncService.pendingOperations;
    final lastSync = _syncService.lastSyncTime;

    if (pendingCount == 0) {
      return Tooltip(
        message: lastSync != null
            ? 'Last synced: ${_formatTime(lastSync)}'
            : 'No sync yet',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 16),
            const SizedBox(width: 4),
            Text(
              'Synced',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Colors.green),
            ),
          ],
        ),
      );
    } else {
      return GestureDetector(
        onTap: widget.onSyncPressed,
        child: Tooltip(
          message: 'Tap to sync now',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_upload, color: Colors.orange, size: 16),
              const SizedBox(width: 4),
              Text(
                '$pendingCount pending',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Colors.orange),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildSyncingStatus() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'Syncing...',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).primaryColor),
        ),
      ],
    );
  }

  Widget _buildErrorStatus() {
    return Tooltip(
      message: 'Sync error (will retry automatically)',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 16),
          const SizedBox(width: 4),
          Text(
            'Sync error',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictStatus() {
    return Tooltip(
      message: 'Conflict detected (manual resolution needed)',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning, color: Colors.amber, size: 16),
          const SizedBox(width: 4),
          Text(
            'Conflict',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Colors.amber),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

/// Full-screen sync status dialog
class SyncStatusDialog extends StatefulWidget {
  const SyncStatusDialog({super.key});

  @override
  State<SyncStatusDialog> createState() => _SyncStatusDialogState();
}

class _SyncStatusDialogState extends State<SyncStatusDialog> {
  late final UnifiedSyncService _syncService;

  @override
  void initState() {
    super.initState();
    _syncService = UnifiedSyncService();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sync Status',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildStatusDetail('Status', _syncService.status.toString()),
            const SizedBox(height: 12),
            _buildStatusDetail(
              'Pending Operations',
              '${_syncService.pendingOperations}',
            ),
            const SizedBox(height: 12),
            _buildStatusDetail(
              'Last Sync',
              _syncService.lastSyncTime != null
                  ? _formatDateTime(_syncService.lastSyncTime!)
                  : 'Never',
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDetail(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(value),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
