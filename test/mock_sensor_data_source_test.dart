import 'package:flutter_test/flutter_test.dart';
import 'package:prana_health/features/devices/mock_sensor_data_source.dart';
import 'package:prana_health/features/scenarios/disaster_scenario_engine.dart';
import 'package:prana_health/shared/models/motion_reading.dart';

void main() {
  group('MockSensorDataSource Tests', () {
    late MockSensorDataSource dataSource;

    setUp(() {
      dataSource = MockSensorDataSource();
    });

    tearDown(() {
      dataSource.dispose();
    });

    test('Emits simulated fall anomaly motion reading', () async {
      expectLater(
        dataSource.motionStream,
        emits(predicate<MotionReading>((motion) => motion.isFallSuspected)),
      );

      dataSource.triggerSimulatedFall();
    });

    test('Scenario switching updates without error', () {
      dataSource.setScenario(DisasterScenario.heatwave);
      dataSource.setScenario(DisasterScenario.airPollution);
      dataSource.setScenario(DisasterScenario.normal);
    });
  });
}
