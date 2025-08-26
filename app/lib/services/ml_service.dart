import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ml_model_downloader/firebase_ml_model_downloader.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MLService {
  // Singleton pattern
  static final MLService _instance = MLService._internal();
  factory MLService() => _instance;
  MLService._internal();

  FirebaseCustomModel? _model;
  FirebaseCustomModel? _anomalyModel;
  Interpreter? _interpreter;
  Interpreter? _anomalyInterpreter;
  bool _isModelLoaded = false;
  bool _isAnomalyModelLoaded = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _predictionTimer;

  // Constants for model configuration
  static const String MODEL_NAME = 'heart-status';
  static const String ANOMALY_MODEL_NAME = 'athlete-anomaly-detector';
  static const String MODEL_VERSION_KEY = 'model_version';
  static const List<int> INPUT_SHAPE = [1, 4];
  static const List<int> OUTPUT_SHAPE = [1, 2];
  static const List<int> ANOMALY_INPUT_SHAPE = [1, 5];
  static const List<int> ANOMALY_OUTPUT_SHAPE = [1, 1];

  // Normalization constants
  static const double MAX_HEART_RATE = 200.0;
  static const double MIN_TEMP = 35.0;
  static const double TEMP_RANGE = 5.0;
  static const double MAX_AGE = 100.0;

  // Anomaly model preprocessing constants
  static const List<double> SCALER_MEAN = [
    130.10256991987998,
    95.09956383382,
    4.976967278282001,
    37.82234,
    1.522,
  ];
  static const List<double> SCALER_SCALE = [
    14.704072545919214,
    2.94924470225052,
    1.9172122073361932,
    0.3356687718570199,
    1.1178175164131219,
  ];

  static const Map<String, int> ACTIVITY_MAPPING = {
    'Cycling': 0,
    'Running': 1,
    'Treadmill': 2,
    'Weightlifting': 3,
  };

  Future<Map<String, dynamic>?> getHeartStatusModel() async {
    if (_isModelLoaded && _interpreter != null) {
      return {
        'status': 'loaded',
        'message': 'Model already loaded and ready',
        'size': _model?.size ?? 0,
      };
    }

    try {
      // Download the model from Firebase ML
      final conditions = FirebaseModelDownloadConditions(
        iosAllowsCellularAccess: true,
        iosAllowsBackgroundDownloading: true,
        androidChargingRequired: false,
        androidWifiRequired: false,
        androidDeviceIdleRequired: false,
      );

      print('Downloading heart-status model from Firebase ML...');

      _model = await FirebaseModelDownloader.instance.getModel(
        'heart-status',
        FirebaseModelDownloadType.latestModel,
        conditions,
      );

      if (_model?.file == null) {
        throw Exception('Model file not found after download');
      }

      // Initialize the interpreter with the downloaded model
      _interpreter = await Interpreter.fromFile(_model!.file!);
      _isModelLoaded = true;

      print('✅ ML model downloaded and initialized successfully');
      print('Model size: ${_model?.size ?? 0} bytes');
      print('Model path: ${_model?.file?.path}');

      return {
        'status': 'loaded',
        'message': 'Model downloaded and initialized successfully',
        'size': _model?.size ?? 0,
      };
    } catch (e) {
      print('❌ Error loading model: $e');
      return {'status': 'error', 'message': 'Failed to load model: $e'};
    }
  }

  Future<String?> _getModelVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(MODEL_VERSION_KEY);
  }

  Future<void> _updateModelVersion(String? version) async {
    if (version == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(MODEL_VERSION_KEY, version);
  }

  Future<Map<String, dynamic>> _predictHeartStatus({
    required double heartRate,
    required double temperature,
    required double age,
    required String gender,
  }) async {
    try {
      // Simple health status assessment based on input values
      final List<String> riskFactors = [];
      final List<String> tips = [];
      String status = 'normal';
      double confidence = 1.0;

      // Heart Rate Analysis
      if (heartRate > 100) {
        riskFactors.add('Elevated Heart Rate');
        tips.add('Consider deep breathing exercises to lower your heart rate');
        tips.add('Avoid caffeine and stay hydrated');
        status = 'abnormal';
        confidence = 0.8;
      } else if (heartRate < 60) {
        riskFactors.add('Low Heart Rate');
        tips.add('Gradually increase physical activity under supervision');
        tips.add('Consult your healthcare provider about your low heart rate');
        status = 'abnormal';
        confidence = 0.7;
      }

      // Temperature Analysis
      if (temperature > 37.5) {
        riskFactors.add('Elevated Body Temperature');
        tips.add('Rest and monitor your temperature');
        tips.add('Stay hydrated and consider reducing training intensity');
        status = 'abnormal';
        confidence = max(confidence, 0.9);
      } else if (temperature < 36.0) {
        riskFactors.add('Low Body Temperature');
        tips.add('Ensure proper warm-up before exercise');
        tips.add('Wear appropriate clothing during training');
        status = 'abnormal';
        confidence = max(confidence, 0.6);
      }

      // Age-specific recommendations
      if (age > 40) {
        tips.add('Include regular recovery periods in your training schedule');
        tips.add('Focus on maintaining flexibility and joint mobility');
      }

      // Add general recommendations
      if (status == 'abnormal') {
        tips.add('Schedule a check-up with your healthcare provider');
        tips.add('Keep detailed records of your symptoms and when they occur');
      } else {
        tips.add('Maintain your current healthy routine');
        tips.add('Regular monitoring helps prevent potential issues');
      }

      return {
        'status': status,
        'confidence': confidence,
        'hr': heartRate,
        'temperature': temperature,
        'risk_factors': riskFactors,
        'health_tips': tips,
        'probabilities': {
          'normal': status == 'normal' ? 0.9 : 0.1,
          'abnormal': status == 'abnormal' ? 0.9 : 0.1,
        },
        'model_info': {'name': 'heart-status', 'size': _model?.size ?? 0},
        'time': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      print('Error during prediction: $e');
      throw Exception('Failed to make prediction: $e');
    }
  }

  Future<void> _storePredictionHistory(
    String userId,
    Map<String, dynamic> prediction,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('health_history')
          .add({...prediction, 'timestamp': FieldValue.serverTimestamp()});
    } catch (e) {
      print('Error storing prediction history: $e');
    }
  }

  Stream<Map<String, dynamic>> setupRealtimePredictions(String userId) async* {
    // Ensure model is loaded
    if (!_isModelLoaded || _interpreter == null) {
      final modelResult = await getHeartStatusModel();
      if (modelResult?['status'] != 'loaded') {
        yield {
          'error': 'Failed to load ML model',
          'time': DateTime.now().millisecondsSinceEpoch,
        };
        return;
      }
    }

    await for (var snapshot
        in _firestore.collection('users').doc(userId).snapshots()) {
      if (!snapshot.exists) continue;

      final userData = snapshot.data() as Map<String, dynamic>;
      final heartRate = userData['hr'] as num?;
      final temperature = userData['temp'] as num?;
      final age = userData['age'] as num?;
      final gender = userData['gender'] as String?;

      print('Debug - Received user data:');
      print('  Heart Rate: $heartRate');
      print('  Temperature: $temperature');
      print('  Age: $age');
      print('  Gender: $gender');

      // Check each required field and provide specific error message
      List<String> missingFields = [];
      if (heartRate == null) missingFields.add('heart rate');
      if (temperature == null) missingFields.add('temperature');
      if (age == null) missingFields.add('age');
      if (gender == null) missingFields.add('gender');

      if (missingFields.isNotEmpty) {
        yield {
          'error': 'Missing required health data: ${missingFields.join(", ")}',
          'missing_fields': missingFields,
          'time': DateTime.now().millisecondsSinceEpoch,
        };
        continue;
      }

      try {
        final prediction = await _predictHeartStatus(
          heartRate: heartRate!.toDouble(),
          temperature: temperature!.toDouble(),
          age: age!.toDouble(),
          gender: gender!,
        );

        await _storePredictionHistory(userId, prediction);
        yield prediction;
      } catch (e) {
        yield {
          'error': 'Error making prediction: $e',
          'time': DateTime.now().millisecondsSinceEpoch,
        };
      }
    }
  }

  void dispose() {
    _interpreter?.close();
    _anomalyInterpreter?.close();
    _predictionTimer?.cancel();
  }

  double max(double a, double b) => a > b ? a : b;

  Future<Map<String, dynamic>?> getAnomalyDetectorModel() async {
    if (_isAnomalyModelLoaded && _anomalyInterpreter != null) {
      return {
        'status': 'loaded',
        'message': 'Anomaly detector model already loaded and ready',
        'size': _anomalyModel?.size ?? 0,
      };
    }

    try {
      // Download the anomaly model from Firebase ML
      final conditions = FirebaseModelDownloadConditions(
        iosAllowsCellularAccess: true,
        iosAllowsBackgroundDownloading: true,
        androidChargingRequired: false,
        androidWifiRequired: false,
        androidDeviceIdleRequired: false,
      );

      print('Downloading athlete-anomaly-detector model from Firebase ML...');

      _anomalyModel = await FirebaseModelDownloader.instance.getModel(
        ANOMALY_MODEL_NAME,
        FirebaseModelDownloadType.latestModel,
        conditions,
      );

      if (_anomalyModel?.file == null) {
        throw Exception('Anomaly model file not found after download');
      }

      // Initialize the interpreter with the downloaded model
      _anomalyInterpreter = await Interpreter.fromFile(_anomalyModel!.file!);
      _isAnomalyModelLoaded = true;

      print('✅ Anomaly detector model downloaded and initialized successfully');
      print('Model size: ${_anomalyModel?.size ?? 0} bytes');
      print('Model path: ${_anomalyModel?.file?.path}');

      return {
        'status': 'loaded',
        'message':
            'Anomaly detector model downloaded and initialized successfully',
        'size': _anomalyModel?.size ?? 0,
      };
    } catch (e) {
      print('❌ Error loading anomaly detector model: $e');
      return {
        'status': 'error',
        'message': 'Failed to load anomaly detector model: $e',
      };
    }
  }

  // Preprocess input for anomaly detection
  List<double> _preprocessAnomalyInput({
    required double heartRate,
    required double oxygenLevel,
    required double fatigueScore,
    required double temperature,
    required String activity,
  }) {
    // Encode activity
    int activityCode = ACTIVITY_MAPPING[activity] ?? 0;

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
      features[i] = (features[i] - SCALER_MEAN[i]) / SCALER_SCALE[i];
    }

    return features;
  }

  Future<Map<String, dynamic>> predictAnomaly({
    required double heartRate,
    required double oxygenLevel,
    required double fatigueScore,
    required double temperature,
    required String activity,
  }) async {
    try {
      if (!_isAnomalyModelLoaded || _anomalyInterpreter == null) {
        throw Exception('Anomaly detector model not loaded');
      }

      // Preprocess input
      List<double> processedInput = _preprocessAnomalyInput(
        heartRate: heartRate,
        oxygenLevel: oxygenLevel,
        fatigueScore: fatigueScore,
        temperature: temperature,
        activity: activity,
      );

      // Prepare input tensor
      var input = [processedInput];
      var output = List.filled(1, 0.0).reshape([1, 1]);

      // Run inference
      _anomalyInterpreter!.run(input, output);

      double probability = output[0][0];
      bool isAnomaly = probability > 0.5;

      String riskLevel;
      if (probability < 0.1) {
        riskLevel = 'Very Low';
      } else if (probability < 0.3) {
        riskLevel = 'Low';
      } else if (probability < 0.5) {
        riskLevel = 'Moderate';
      } else {
        riskLevel = 'High';
      }

      return {
        'is_anomaly': isAnomaly,
        'probability': probability,
        'risk_level': riskLevel,
        'confidence': probability,
        'input_features': {
          'heart_rate': heartRate,
          'oxygen_level': oxygenLevel,
          'fatigue_score': fatigueScore,
          'temperature': temperature,
          'activity': activity,
        },
        'processed_features': processedInput,
        'model_info': {
          'name': ANOMALY_MODEL_NAME,
          'size': _anomalyModel?.size ?? 0,
        },
        'time': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      print('Error during anomaly prediction: $e');
      throw Exception('Failed to make anomaly prediction: $e');
    }
  }
}
