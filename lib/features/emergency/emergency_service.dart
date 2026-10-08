import 'dart:async';
import '../../core/constants/app_constants.dart';

enum EmergencyState {
  ready,
  countdown,
  sosSent,
  cancelled,
}

/// Emergency & SOS Assistance State Machine
class EmergencyService {
  EmergencyState _state = EmergencyState.ready;
  int _countdownRemaining = AppConstants.sosCountdownSeconds;
  Timer? _countdownTimer;
  final _stateController = StreamController<EmergencyState>.broadcast();
  final _countdownController = StreamController<int>.broadcast();

  String? _dispatchedGpsLocation;
  String? _dispatchedMapsLink;
  DateTime? _dispatchedTimestamp;

  // Live outcome of the automatic dispatch, filled in by the controller.
  bool _dispatchInProgress = false;
  bool? _smsSent;
  String? _callStatus; // 'called' | 'dialer' | 'failed' | 'skipped'

  EmergencyState get currentState => _state;
  int get countdownRemaining => _countdownRemaining;
  String? get dispatchedGpsLocation => _dispatchedGpsLocation;
  String? get dispatchedMapsLink => _dispatchedMapsLink;
  DateTime? get dispatchedTimestamp => _dispatchedTimestamp;
  bool get dispatchInProgress => _dispatchInProgress;
  bool? get smsSent => _smsSent;
  String? get callStatus => _callStatus;

  Stream<EmergencyState> get stateStream => _stateController.stream;
  Stream<int> get countdownStream => _countdownController.stream;

  void triggerFallDetected() {
    if (_state == EmergencyState.sosSent) return;
    _startCountdown();
  }

  void triggerManualSos() {
    _sendSosImmediate();
  }

  void _startCountdown() {
    _state = EmergencyState.countdown;
    _countdownRemaining = AppConstants.sosCountdownSeconds;
    _stateController.add(_state);
    _countdownController.add(_countdownRemaining);

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _countdownRemaining--;
      _countdownController.add(_countdownRemaining);

      if (_countdownRemaining <= 0) {
        timer.cancel();
        _sendSosImmediate();
      }
    });
  }

  void cancelEmergency() {
    _countdownTimer?.cancel();
    _state = EmergencyState.cancelled;
    _stateController.add(_state);

    // Reset back to ready after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      _state = EmergencyState.ready;
      _stateController.add(_state);
    });
  }

  void _sendSosImmediate({String? customGpsLocation}) {
    _countdownTimer?.cancel();
    _state = EmergencyState.sosSent;
    // The controller resolves the real GPS fix and performs the SMS/call once
    // it sees this state; start clean so the UI shows "locating / sending".
    _dispatchInProgress = false;
    _smsSent = null;
    _callStatus = null;
    _dispatchedMapsLink = null;
    _dispatchedGpsLocation = customGpsLocation;
    _dispatchedTimestamp = DateTime.now();
    _stateController.add(_state);
  }

  // ── Dispatch outcome, driven by PranaHealthController ─────────────────────
  // Kept separate from the telephony/GPS code: this class stays a pure state
  // machine, the controller (which holds the profile, vitals and dispatcher)
  // performs the send and reports back through these mutators.

  /// Marks that acquiring GPS + sending has begun. Shows "Locating…" in the UI.
  void beginDispatch() {
    _dispatchInProgress = true;
    _dispatchedGpsLocation = 'Locating…';
    _dispatchedMapsLink = null;
    _smsSent = null;
    _callStatus = null;
    _stateController.add(_state);
  }

  /// Records the resolved location before the message is built/sent.
  void setDispatchedLocation(String? text, String? mapsLink) {
    _dispatchedGpsLocation = text;
    _dispatchedMapsLink = mapsLink;
    _stateController.add(_state);
  }

  /// Records the final outcome of the SMS + call.
  void completeDispatch({
    String? gpsText,
    required bool smsSent,
    required String callStatus,
  }) {
    _dispatchInProgress = false;
    if (gpsText != null) _dispatchedGpsLocation = gpsText;
    _smsSent = smsSent;
    _callStatus = callStatus;
    _stateController.add(_state);
  }

  void resolveEmergency() {
    _countdownTimer?.cancel();
    _state = EmergencyState.ready;
    _dispatchedGpsLocation = null;
    _dispatchedMapsLink = null;
    _dispatchedTimestamp = null;
    _dispatchInProgress = false;
    _smsSent = null;
    _callStatus = null;
    _stateController.add(_state);
  }

  void dispose() {
    _countdownTimer?.cancel();
    _stateController.close();
    _countdownController.close();
  }
}
