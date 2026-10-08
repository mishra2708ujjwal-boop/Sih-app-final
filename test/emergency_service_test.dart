import 'package:flutter_test/flutter_test.dart';
import 'package:prana_health/features/emergency/emergency_service.dart';

void main() {
  group('EmergencyService Tests', () {
    late EmergencyService emergencyService;

    setUp(() {
      emergencyService = EmergencyService();
    });

    tearDown(() {
      emergencyService.dispose();
    });

    test('Initial state is ready', () {
      expect(emergencyService.currentState, equals(EmergencyState.ready));
      expect(emergencyService.dispatchedGpsLocation, isNull);
    });

    test('Manual SOS trigger immediately transitions to sosSent without fake GPS', () {
      emergencyService.triggerManualSos();
      expect(emergencyService.currentState, equals(EmergencyState.sosSent));
      expect(emergencyService.dispatchedGpsLocation, contains('Location unavailable'));
      expect(emergencyService.dispatchedTimestamp, isNotNull);
    });

    test('Resolve emergency resets state to ready', () {
      emergencyService.triggerManualSos();
      expect(emergencyService.currentState, equals(EmergencyState.sosSent));

      emergencyService.resolveEmergency();
      expect(emergencyService.currentState, equals(EmergencyState.ready));
      expect(emergencyService.dispatchedGpsLocation, isNull);
    });
  });
}
