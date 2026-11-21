class MachineReading {
  const MachineReading({
    required this.machineId,
    required this.machineName,
    required this.vibration,
    required this.temperature,
    required this.current,
    required this.condition,
    required this.health,
    required this.confidence,
    required this.severity,
    required this.anomalyScore,
    required this.isAnomaly,
    required this.primarySensor,
    required this.explanation,
    required this.contributions,
    required this.rulDays,
    required this.timestamp,
  });

  final String machineId,
      machineName,
      condition,
      severity,
      primarySensor,
      explanation,
      timestamp;
  final double vibration,
      temperature,
      current,
      health,
      confidence,
      anomalyScore,
      rulDays;
  final bool isAnomaly;
  final Map<String, double> contributions;

  factory MachineReading.fromJson(Map<String, dynamic> json) => MachineReading(
        machineId: '${json['machine_id'] ?? 'Unknown'}',
        machineName:
            '${json['machine_name'] ?? json['machine_id'] ?? 'Virtual machine'}',
        vibration: _number(json['vibration']),
        temperature: _number(json['temperature']),
        current: _number(json['current']),
        condition: '${json['condition'] ?? json['prediction'] ?? 'Unknown'}',
        health: _number(json['health']),
        confidence: _number(json['confidence']),
        severity: '${json['severity'] ?? 'Info'}',
        anomalyScore: _number(json['anomaly_score']),
        isAnomaly: json['is_anomaly'] == true || json['is_anomaly'] == 1,
        primarySensor: '${json['primary_sensor'] ?? 'N/A'}',
        explanation:
            '${json['explanation'] ?? 'No explanation supplied by the model.'}',
        contributions: (json['sensor_contributions'] is Map
            ? (json['sensor_contributions'] as Map)
                .map((k, v) => MapEntry('$k', _number(v)))
            : <String, double>{}),
        rulDays: _number(json['rul_days_estimate']),
        timestamp: '${json['timestamp'] ?? ''}',
      );

  static double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}
