/// Session Controller with Timeout Management
/// 
/// Manages user sessions with automatic timeout and logout.
/// All sensitive operations trigger timeout reset.

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firebase_auth_service.dart';

class SessionController {
  static final SessionController _instance = SessionController._init();
  
  /// Session timeout in seconds (15 minutes)
  static const int SESSION_TIMEOUT_SECONDS = FirebaseAuthService.SESSION_TIMEOUT_SECONDS;
  
  /// Warning threshold: show dialog 2 minutes before timeout
  static const int WARNING_THRESHOLD_SECONDS = 120;

  final FirebaseAuthService _authService = FirebaseAuthService();
  
  Timer? _sessionTimer;
  Timer? _warningTimer;
  
  bool _isSessionActive = false;
  DateTime? _lastActivityTime;
  
  final List<VoidCallback> _timeoutListeners = [];
  final List<VoidCallback> _warningListeners = [];

  SessionController._init();

  factory SessionController() => _instance;

  /// Initialize session management
  void initialize() {
    _isSessionActive = _authService.isAuthenticated;
    if (_isSessionActive) {
      _resetSessionTimer();
      _setupActivityListeners();
    }
  }

  /// Register callback for session timeout
  void onSessionTimeout(VoidCallback callback) {
    _timeoutListeners.add(callback);
  }

  /// Register callback for timeout warning
  void onTimeoutWarning(VoidCallback callback) {
    _warningListeners.add(callback);
  }

  /// Record user activity (resets timeout)
  void recordActivity() {
    if (!_isSessionActive) return;
    
    _lastActivityTime = DateTime.now();
    _resetSessionTimer();
  }

  /// Get remaining session time in seconds
  int getTimeRemaining() {
    if (_lastActivityTime == null) return 0;
    
    final elapsed = DateTime.now().difference(_lastActivityTime!).inSeconds;
    final remaining = SESSION_TIMEOUT_SECONDS - elapsed;
    
    return remaining > 0 ? remaining : 0;
  }

  /// Check if session is about to timeout (within warning threshold)
  bool isAboutToTimeout() {
    return getTimeRemaining() < WARNING_THRESHOLD_SECONDS;
  }

  /// Extend session (manual action, e.g., user clicks "Continue")
  void extendSession() {
    recordActivity();
    _warningListeners.clear(); // Clear warning callback once extended
  }

  /// End session (logout)
  Future<void> endSession() async {
    _cancelTimers();
    _isSessionActive = false;
    _lastActivityTime = null;
    _timeoutListeners.clear();
    _warningListeners.clear();
    
    await _authService.signOut();
  }

  /// Cleanup on logout
  void dispose() {
    _cancelTimers();
    _timeoutListeners.clear();
    _warningListeners.clear();
  }

  // Private helpers
  
  void _resetSessionTimer() {
    _cancelTimers();
    _lastActivityTime = DateTime.now();
    
    // Main timeout timer
    _sessionTimer = Timer(
      Duration(seconds: SESSION_TIMEOUT_SECONDS),
      _handleSessionTimeout,
    );
    
    // Warning timer (fires 2 minutes before timeout)
    final warningDuration = SESSION_TIMEOUT_SECONDS - WARNING_THRESHOLD_SECONDS;
    _warningTimer = Timer(
      Duration(seconds: warningDuration),
      _handleWarning,
    );
  }

  void _cancelTimers() {
    _sessionTimer?.cancel();
    _warningTimer?.cancel();
  }

  void _handleWarning() {
    for (final listener in _warningListeners) {
      listener();
    }
  }

  void _handleSessionTimeout() {
    _isSessionActive = false;
    for (final listener in _timeoutListeners) {
      listener();
    }
  }

  void _setupActivityListeners() {
    // On mobile: listen to app lifecycle changes
    if (!kIsWeb) {
      // Note: Requires WidgetsBindingObserver integration
      // This is handled by AppLifecycleListener in main app
    }
    
    // On web: listen to window focus changes
    if (kIsWeb) {
      // Note: Requires web-specific event listeners
      // This is handled by SessionListenerWidget
    }
  }
}

/// Widget that listens to user activity and manages session timeout
/// Wrap your main app content with this widget
class SessionTimeoutListener extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSessionTimeout;
  final VoidCallback? onTimeoutWarning;

  const SessionTimeoutListener({
    required this.child,
    this.onSessionTimeout,
    this.onTimeoutWarning,
    Key? key,
  }) : super(key: key);

  @override
  State<SessionTimeoutListener> createState() => _SessionTimeoutListenerState();
}

class _SessionTimeoutListenerState extends State<SessionTimeoutListener>
    with WidgetsBindingObserver {
  late SessionController _sessionController;

  @override
  void initState() {
    super.initState();
    _sessionController = SessionController();
    
    if (widget.onSessionTimeout != null) {
      _sessionController.onSessionTimeout(widget.onSessionTimeout!);
    }
    if (widget.onTimeoutWarning != null) {
      _sessionController.onTimeoutWarning(widget.onTimeoutWarning!);
    }
    
    _sessionController.initialize();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionController.dispose();
    super.dispose();
  }

  /// Track app lifecycle: pause = session expires, resume = reset timer
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App backgrounded - session may expire
      // Timer continues running
    } else if (state == AppLifecycleState.resumed) {
      // App foreground - reset session if within timeout
      if (_sessionController.getTimeRemaining() > 0) {
        _sessionController.recordActivity();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _sessionController.recordActivity(),
      onLongPress: () => _sessionController.recordActivity(),
      child: widget.child,
    );
  }
}

// Import statement needed for SessionTimeoutListener
import 'package:flutter/material.dart';
