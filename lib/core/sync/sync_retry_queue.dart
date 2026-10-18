/// Sync Retry Queue Service
/// 
/// Manages failed sync operations with exponential backoff.
/// Implements retry logic with configurable limits and strategies.

import 'dart:async';
import '../../shared/models/canonical/canonical_entities.dart';
import '../database/database_helper.dart';

enum RetryStrategy { exponentialBackoff, linear, immediate }

class SyncRetryQueue {
  static final SyncRetryQueue _instance = SyncRetryQueue._init();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Map<String, RetryOperation> _activeRetries = {};

  Timer? _retryTimer;
  int _maxRetries = 3;
  RetryStrategy _strategy = RetryStrategy.exponentialBackoff;

  SyncRetryQueue._init();

  factory SyncRetryQueue() => _instance;

  /// Configure retry behavior
  void configure({
    required int maxRetries,
    required RetryStrategy strategy,
  }) {
    _maxRetries = maxRetries;
    _strategy = strategy;
    print('✓ Retry queue configured: max=$maxRetries, strategy=$strategy');
  }

  /// Add operation to retry queue
  Future<void> addToQueue(
    String operationId,
    String entityType,
    String entityId,
    String operation,
    Map<String, dynamic> payload,
    Future<void> Function() retryCallback,
  ) async {
    try {
      final retryOp = RetryOperation(
        id: operationId,
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payload: payload,
        retryCallback: retryCallback,
        retryCount: 0,
        lastAttemptTime: DateTime.now(),
        nextRetryTime: _calculateNextRetryTime(0),
      );

      _activeRetries[operationId] = retryOp;

      // Store in database for persistence
      await _dbHelper.insertRetryQueueItem(
        operationId,
        entityType,
        entityId,
        operation,
        payload,
        0, // retryCount
        'pending',
      );

      print('✓ Added $operationId to retry queue');
      _scheduleNextRetry();
    } catch (e) {
      print('✗ Failed to add to retry queue: $e');
    }
  }

  /// Process retry queue
  Future<void> processQueue() async {
    if (_activeRetries.isEmpty) return;

    print('↻ Processing retry queue (${_activeRetries.length} items)...');

    final now = DateTime.now();
    final itemsToRetry = _activeRetries.values
        .where((op) => op.nextRetryTime.isBefore(now) || op.nextRetryTime.isAtSameMomentAs(now))
        .toList();

    for (final retryOp in itemsToRetry) {
      try {
        await retryOp.retryCallback();

        // Success: remove from queue
        _activeRetries.remove(retryOp.id);
        await _dbHelper.updateRetryQueueItemStatus(
          retryOp.id,
          'success',
          DateTime.now(),
        );

        print('✓ Retry successful for ${retryOp.id}');
      } catch (e) {
        retryOp.retryCount++;

        if (retryOp.retryCount >= _maxRetries) {
          // Max retries exceeded
          _activeRetries.remove(retryOp.id);
          await _dbHelper.updateRetryQueueItemStatus(
            retryOp.id,
            'failed',
            DateTime.now(),
          );

          print('✗ Max retries exceeded for ${retryOp.id}');
        } else {
          // Schedule next retry
          retryOp.lastAttemptTime = DateTime.now();
          retryOp.nextRetryTime = _calculateNextRetryTime(retryOp.retryCount);

          await _dbHelper.updateRetryQueueItemStatus(
            retryOp.id,
            'pending',
            retryOp.nextRetryTime,
          );

          print(
            '⚠️ Retry ${retryOp.retryCount} failed for ${retryOp.id}, '
            'next attempt at ${retryOp.nextRetryTime}',
          );
        }
      }
    }

    _scheduleNextRetry();
  }

  /// Calculate next retry time based on strategy
  DateTime _calculateNextRetryTime(int attemptNumber) {
    final delayMs = switch (_strategy) {
      RetryStrategy.exponentialBackoff =>
        1000 * (1 << attemptNumber), // 1s, 2s, 4s, 8s...
      RetryStrategy.linear => 1000 * (attemptNumber + 1), // 1s, 2s, 3s...
      RetryStrategy.immediate => 0,
    };

    // Add random jitter (±10%)
    final jitter = (delayMs * 0.1 * (0.8 + 0.4 * (delayMs.hashCode % 100) / 100)).toInt();
    final finalDelay = delayMs + jitter;

    return DateTime.now().add(Duration(milliseconds: finalDelay));
  }

  /// Schedule next automatic retry
  void _scheduleNextRetry() {
    _retryTimer?.cancel();

    if (_activeRetries.isEmpty) return;

    // Find earliest retry time
    final earliest = _activeRetries.values
        .map((op) => op.nextRetryTime)
        .reduce((a, b) => a.isBefore(b) ? a : b);

    final delay = earliest.difference(DateTime.now());
    if (delay.isNegative) {
      // Retry is overdue, process immediately
      _retryTimer = Timer(Duration.zero, processQueue);
    } else {
      _retryTimer = Timer(delay, processQueue);
      print('⏱️ Next retry scheduled in ${delay.inSeconds}s');
    }
  }

  /// Get retry queue status
  Map<String, dynamic> getStatus() {
    return {
      'queueSize': _activeRetries.length,
      'pendingItems': _activeRetries.values
          .where((op) => op.retryCount < _maxRetries)
          .length,
      'failedItems': _activeRetries.values
          .where((op) => op.retryCount >= _maxRetries)
          .length,
      'strategy': _strategy.toString(),
      'maxRetries': _maxRetries,
    };
  }

  /// Clear queue (usually on logout)
  Future<void> clear() async {
    _retryTimer?.cancel();
    _activeRetries.clear();
    await _dbHelper.clearRetryQueue();
    print('✓ Retry queue cleared');
  }

  void dispose() {
    _retryTimer?.cancel();
  }
}

/// Single retry operation
class RetryOperation {
  final String id;
  final String entityType;
  final String entityId;
  final String operation;
  final Map<String, dynamic> payload;
  final Future<void> Function() retryCallback;

  int retryCount;
  DateTime lastAttemptTime;
  DateTime nextRetryTime;

  RetryOperation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.retryCallback,
    required this.retryCount,
    required this.lastAttemptTime,
    required this.nextRetryTime,
  });
}
