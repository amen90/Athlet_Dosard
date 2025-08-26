// Dart preprocessing code for Athlete Anomaly Detection
class AthleteAnomalyPreprocessor {
  // Scaler parameters (from training)
  static const List<double> scalerMean = [
    130.10256991987998,
    95.09956383382,
    4.976967278282001,
    37.82234,
    1.522,
  ];

  static const List<double> scalerScale = [
    14.704072545919214,
    2.94924470225052,
    1.9172122073361932,
    0.3356687718570199,
    1.1178175164131219,
  ];

  // Activity encoding mapping
  static const Map<String, int> activityMapping = {
    'Cycling': 0,
    'Running': 1,
    'Treadmill': 2,
    'Weightlifting': 3,
  };

  static List<double> preprocessInput({
    required double heartRate,
    required double oxygenLevel,
    required double fatigueScore,
    required double temperature,
    required String activity,
  }) {
    // Encode activity
    int activityCode = activityMapping[activity] ?? 0;

    // Create feature array
    List<double> features = [
      heartRate,
      oxygenLevel,
      fatigueScore,
      temperature,
      activityCode.toDouble(),
    ];

    // Apply scaling: (x - mean) / scale
    for (int i = 0; i < features.length; i++) {
      features[i] = (features[i] - scalerMean[i]) / scalerScale[i];
    }

    return features;
  }

  static bool isAnomaly(double probability) {
    return probability > 0.5;
  }

  static String getRiskLevel(double probability) {
    if (probability < 0.1) {
      return 'Very Low';
    } else if (probability < 0.3) {
      return 'Low';
    } else if (probability < 0.5) {
      return 'Moderate';
    } else {
      return 'High';
    }
  }

  static Map<String, dynamic> validateInput({
    required double heartRate,
    required double oxygenLevel,
    required double fatigueScore,
    required double temperature,
    required String activity,
  }) {
    List<String> errors = [];

    print('=== Validation Debug ===');
    print('Validating HR: $heartRate (expected: 50-220)');
    print('Validating SpO2: $oxygenLevel (expected: 85-100)');
    print('Validating Fatigue: $fatigueScore (expected: 1-10)');
    print('Validating Temp: $temperature (expected: 35-40)');
    print(
      'Validating Activity: $activity (expected: ${activityMapping.keys.join(', ')})',
    );

    // Validate heart rate (more lenient range)
    if (heartRate < 40 || heartRate > 250) {
      errors.add(
        'Heart rate must be between 40 and 250 BPM (current: $heartRate)',
      );
    }

    // Validate oxygen level (more lenient range)
    if (oxygenLevel < 80 || oxygenLevel > 105) {
      errors.add(
        'Oxygen level must be between 80% and 105% (current: $oxygenLevel)',
      );
    }

    // Validate fatigue score
    if (fatigueScore < 1 || fatigueScore > 10) {
      errors.add(
        'Fatigue score must be between 1 and 10 (current: $fatigueScore)',
      );
    }

    // Validate temperature (more lenient range)
    if (temperature < 30 || temperature > 45) {
      errors.add(
        'Temperature must be between 30°C and 45°C (current: $temperature)',
      );
    }

    // Validate activity
    if (!activityMapping.containsKey(activity)) {
      errors.add(
        'Activity must be one of: ${activityMapping.keys.join(', ')} (current: $activity)',
      );
    }

    print('Validation result: ${errors.isEmpty ? 'PASS' : 'FAIL'}');
    if (errors.isNotEmpty) {
      print('Validation errors: $errors');
    }

    return {'isValid': errors.isEmpty, 'errors': errors};
  }
}
