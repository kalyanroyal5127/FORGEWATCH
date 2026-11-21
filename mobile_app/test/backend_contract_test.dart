import 'package:flutter_test/flutter_test.dart';
import 'package:forgewatch_mobile/config/api_config.dart';
import 'package:forgewatch_mobile/models/machine_reading.dart';

void main() {
  test('default production API is HTTPS and not a local address', () {
    expect(isProduction, isTrue);
    final uri = Uri.parse(apiBaseUrl);
    expect(uri.scheme, 'https');
    expect(uri.host, 'kalyanfaultdetection.in');
    expect(apiBaseUrl, isNot(contains('localhost')));
    expect(apiBaseUrl, isNot(contains('127.0.0.1')));
  });

  test('machine model maps backend readings and classifier results', () {
    final machine = MachineReading.fromJson({
      'machine_id': 'M-001',
      'machine_name': 'Virtual Machine 1',
      'vibration': 7.1,
      'temperature': 59.2,
      'current': 8.8,
      'condition': 'Abnormal Vibration',
      'health': 55.0,
      'confidence': 0.91,
      'severity': 'Critical',
      'anomaly_score': 0.37,
      'is_anomaly': true,
      'primary_sensor': 'vibration',
      'explanation': 'Vibration exceeds its simulated baseline.',
      'sensor_contributions': {
        'vibration': 0.82,
        'temperature': 0.03,
        'current': 0.02
      },
      'rul_days_estimate': 14.5,
      'timestamp': '2026-11-21T10:00:00+00:00',
    });

    expect(machine.machineId, 'M-001');
    expect(machine.condition, 'Abnormal Vibration');
    expect(machine.vibration, 7.1);
    expect(machine.confidence, 0.91);
    expect(machine.isAnomaly, isTrue);
    expect(machine.primarySensor, 'vibration');
    expect(machine.contributions['vibration'], 0.82);
    expect(machine.rulDays, 14.5);
  });
}
