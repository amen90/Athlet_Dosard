import 'package:flutter/material.dart';
import '../services/ml_service.dart';
import '../services/firebase_service.dart';
import '../services/anomaly_preprocessor.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class AthleteDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const AthleteDashboardScreen({super.key, required this.userData});

  @override
  State<AthleteDashboardScreen> createState() => _AthleteDashboardScreenState();
}

class _AthleteDashboardScreenState extends State<AthleteDashboardScreen> {
  final MLService _mlService = MLService();
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoadingModel = false;
  bool _isLoadingAnomalyModel = false;
  String _modelStatus = 'Not loaded';
  String _anomalyModelStatus = 'Not loaded';
  Map<String, dynamic>? _predictionResults;
  Map<String, dynamic>? _anomalyResults;
  StreamSubscription? _predictionSubscription;
  StreamSubscription? _userDataSubscription;
  Map<String, dynamic> _currentUserData = {};
  String _selectedActivity = 'Weightlifting'; // Default activity

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _heartRateController = TextEditingController();
  final _ageController = TextEditingController();
  final _restingBPController = TextEditingController();
  final _cholesterolController = TextEditingController();
  final _fastingBSController = TextEditingController();
  String _gender = 'male';

  @override
  void initState() {
    super.initState();
    _currentUserData = Map<String, dynamic>.from(widget.userData);
    _selectedActivity = _currentUserData['activity'] ?? 'Weightlifting';
    _setupUserDataStream();
    _loadModelInBackground();
  }

  void _setupUserDataStream() {
    _userDataSubscription = _firebaseService
        .streamAthleteData(widget.userData['uid'])
        .listen(
          (userData) {
            if (userData != null && mounted) {
              setState(() {
                _currentUserData = userData;
              });
            }
          },
          onError: (error) {
            print('Error in user data stream: $error');
          },
        );
  }

  @override
  void dispose() {
    _userDataSubscription?.cancel();
    _predictionSubscription?.cancel();
    _mlService.dispose();
    super.dispose();
  }

  void _loadModelInBackground() {
    // Load heart status model
    _mlService.getHeartStatusModel().then((modelResult) {
      if (mounted) {
        setState(() {
          _modelStatus = modelResult?['message'] ?? 'Failed to load model';
        });

        if (modelResult?['status'] == 'loaded') {
          _setupRealtimePredictions();
        }
      }
    });

    // Load anomaly detector model
    setState(() {
      _isLoadingAnomalyModel = true;
      _anomalyModelStatus = 'Loading anomaly detector...';
    });

    _mlService.getAnomalyDetectorModel().then((anomalyResult) {
      if (mounted) {
        setState(() {
          _isLoadingAnomalyModel = false;
          _anomalyModelStatus =
              anomalyResult?['message'] ?? 'Failed to load anomaly model';
        });

        if (anomalyResult?['status'] == 'loaded') {
          _setupAnomalyDetection();
        }
      }
    });
  }

  void _setupRealtimePredictions() {
    setState(() {
      _modelStatus = 'Monitoring health data...';
    });

    _predictionSubscription = _mlService
        .setupRealtimePredictions(widget.userData['uid'])
        .listen(
          (predictionResults) {
            if (mounted) {
              setState(() {
                _isLoadingModel = false;
                _predictionResults = predictionResults;
              });
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _isLoadingModel = false;
                _modelStatus = 'Error monitoring data: $error';
                _predictionResults = {
                  'error': 'Failed to monitor health data: $error',
                };
              });
            }
          },
        );
  }

  void _setupAnomalyDetection() {
    // Check if we have enough data for anomaly detection
    _checkAndRunAnomalyDetection();

    // Listen to user data changes for real-time anomaly detection
    _userDataSubscription?.cancel();
    _userDataSubscription = _firebaseService
        .streamAthleteData(widget.userData['uid'])
        .listen(
          (userData) {
            if (userData != null && mounted) {
              setState(() {
                _currentUserData = userData;
                _selectedActivity = userData['activity'] ?? 'Weightlifting';
              });
              _checkAndRunAnomalyDetection();
            }
          },
          onError: (error) {
            print('Error in user data stream: $error');
          },
        );
  }

  void _checkAndRunAnomalyDetection() {
    final hr = _currentUserData['hr'];
    final spo2 = _currentUserData['spo2'];
    final temp = _currentUserData['temp'];
    final activity = _currentUserData['activity'];
    final fatigueScore = _currentUserData['fatigue_score'];

    if (hr != null &&
        spo2 != null &&
        temp != null &&
        activity != null &&
        fatigueScore != null) {
      _runAnomalyDetection(
        heartRate: hr.toDouble(),
        oxygenLevel: spo2.toDouble(),
        temperature: temp.toDouble(),
        activity: activity,
        fatigueScore: fatigueScore.toDouble(),
      );
    } else {
      setState(() {
        _anomalyResults = {
          'error': 'Insufficient data for anomaly detection',
          'missing_fields': _getMissingFields(),
        };
      });
    }
  }

  List<String> _getMissingFields() {
    List<String> missing = [];
    if (_currentUserData['hr'] == null) missing.add('Heart Rate');
    if (_currentUserData['spo2'] == null) missing.add('SpO2');
    if (_currentUserData['temp'] == null) missing.add('Temperature');
    if (_currentUserData['activity'] == null) missing.add('Activity');
    if (_currentUserData['fatigue_score'] == null) missing.add('Fatigue Score');
    return missing;
  }

  Future<void> _runAnomalyDetection({
    required double heartRate,
    required double oxygenLevel,
    required double temperature,
    required String activity,
    required double fatigueScore,
  }) async {
    try {
      // Debug logging
      print('=== Anomaly Detection Debug ===');
      print('Heart Rate: $heartRate');
      print('Oxygen Level (SpO2): $oxygenLevel');
      print('Temperature: $temperature');
      print('Activity: $activity');
      print('Fatigue Score: $fatigueScore');

      // Validate input first
      final validation = AthleteAnomalyPreprocessor.validateInput(
        heartRate: heartRate,
        oxygenLevel: oxygenLevel,
        fatigueScore: fatigueScore,
        temperature: temperature,
        activity: activity,
      );

      print('Validation result: ${validation['isValid']}');
      if (!validation['isValid']) {
        print('Validation errors: ${validation['errors']}');
      }

      if (!validation['isValid']) {
        setState(() {
          _anomalyResults = {
            'error': 'Invalid input data',
            'validation_errors': validation['errors'],
            'debug_data': {
              'heart_rate': heartRate,
              'oxygen_level': oxygenLevel,
              'temperature': temperature,
              'activity': activity,
              'fatigue_score': fatigueScore,
            },
          };
        });
        return;
      }

      // Run anomaly detection
      final result = await _mlService.predictAnomaly(
        heartRate: heartRate,
        oxygenLevel: oxygenLevel,
        fatigueScore: fatigueScore,
        temperature: temperature,
        activity: activity,
      );

      if (mounted) {
        setState(() {
          _anomalyResults = result;
        });
      }
    } catch (e) {
      print('Anomaly detection error: $e');
      if (mounted) {
        setState(() {
          _anomalyResults = {'error': 'Anomaly detection failed: $e'};
        });
      }
    }
  }

  // Add method to update activity
  Future<void> _updateActivity(String newActivity) async {
    try {
      await _firestore.collection('users').doc(_currentUserData['uid']).update({
        'activity': newActivity,
      });

      setState(() {
        _selectedActivity = newActivity;
      });
    } catch (e) {
      print('Error updating activity: $e');
      // You might want to show an error message to the user
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 24,
              errorBuilder: (context, error, stackTrace) => SizedBox(),
            ),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Athlete Dashboard',
                style: TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Profile Icon Button with animated effect
          Hero(
            tag: 'profileAvatar',
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/athlete_profile',
                    arguments: _currentUserData,
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 15,
                    child: Text(
                      _currentUserData['name']?.substring(0, 1).toUpperCase() ??
                          'A',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed:
                () => Navigator.pushReplacementNamed(context, '/welcome'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header gradient section with animation and shadow
          Container(
            padding: EdgeInsets.only(left: 20, right: 20, bottom: 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                // Animated avatar
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: Duration(milliseconds: 500),
                  builder: (context, value, child) {
                    return Transform.scale(scale: value, child: child);
                  },
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 30,
                    child: Text(
                      _currentUserData['name']?.substring(0, 1).toUpperCase() ??
                          'A',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome,',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${_currentUserData['name'] ?? 'Athlete'}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Dashboard content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Health Monitoring Section - Now this is the main focus
                  _sectionTitle('Health Monitoring'),
                  SizedBox(height: 16),

                  // Health Monitoring Cards - Two per row
                  Row(
                    children: [
                      // Heart Rate Card
                      Expanded(
                        child: _buildHealthCard(
                          context: context,
                          icon: Icons.monitor_heart,
                          iconColor: Color(0xFFE53935),
                          title: 'Heart Rate',
                          value:
                              _currentUserData['hr'] != null
                                  ? '${_currentUserData['hr']}'
                                  : 'No data',
                          unit: 'BPM',
                        ),
                      ),
                      SizedBox(width: 12),
                      // Temperature Card
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return _buildHealthCard(
                              context: context,
                              icon: Icons.thermostat,
                              iconColor: Color(0xFFFF9800),
                              title: 'Temperature',
                              value:
                                  _currentUserData['temp'] != null
                                      ? '${_currentUserData['temp']}'
                                      : 'No data',
                              unit: '°C',
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 12),

                  // SpO2 and Fatigue Score Cards - Two per row
                  Row(
                    children: [
                      // SpO2 Card
                      Expanded(
                        child: _buildHealthCard(
                          context: context,
                          icon: Icons.bloodtype,
                          iconColor: Color(0xFF2196F3),
                          title: 'SpO2',
                          value:
                              _currentUserData['spo2'] != null
                                  ? '${_currentUserData['spo2']}'
                                  : 'No data',
                          unit: '%',
                        ),
                      ),
                      SizedBox(width: 12),
                      // Fatigue Score Card
                      Expanded(
                        child: _buildHealthCard(
                          context: context,
                          icon: Icons.battery_3_bar,
                          iconColor: Color(0xFF9C27B0),
                          title: 'Fatigue Score',
                          value:
                              _currentUserData['fatigue_score'] != null
                                  ? '${_currentUserData['fatigue_score']}'
                                  : 'No data',
                          unit: '/10',
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Activity Selection Section
                  _sectionTitle('Activity'),
                  SizedBox(height: 12),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.fitness_center,
                                color: Theme.of(context).primaryColor,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Select your activity:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              // Weightlifting Checkbox
                              Expanded(
                                child: InkWell(
                                  onTap: () => _updateActivity('Weightlifting'),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value:
                                            _selectedActivity ==
                                            'Weightlifting',
                                        onChanged: (bool? value) {
                                          if (value == true) {
                                            _updateActivity('Weightlifting');
                                          }
                                        },
                                        activeColor:
                                            Theme.of(context).primaryColor,
                                      ),
                                      Text('Weightlifting'),
                                    ],
                                  ),
                                ),
                              ),
                              // Running Checkbox
                              Expanded(
                                child: InkWell(
                                  onTap: () => _updateActivity('Running'),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: _selectedActivity == 'Running',
                                        onChanged: (bool? value) {
                                          if (value == true) {
                                            _updateActivity('Running');
                                          }
                                        },
                                        activeColor:
                                            Theme.of(context).primaryColor,
                                      ),
                                      Text('Running'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // ML Model Section
                  _sectionTitle('Health Status Monitor'),
                  SizedBox(height: 16),

                  // ML Model Status Card
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.model_training,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'AI Health Monitor',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (_isLoadingModel)
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Status: ${_modelStatus}',
                            style: TextStyle(
                              color:
                                  _modelStatus.contains('Error') ||
                                          _modelStatus.contains('Failed')
                                      ? Colors.red
                                      : _modelStatus.contains('Model loaded') ||
                                          _modelStatus.contains('Monitoring')
                                      ? Colors.green
                                      : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Prediction Results
                  if (_predictionResults != null) ...[
                    SizedBox(height: 24),
                    _sectionTitle('Health Assessment'),
                    SizedBox(height: 16),

                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color:
                          _predictionResults!.containsKey('error')
                              ? Colors.red.shade50
                              : _predictionResults!['status'] == 'normal'
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _predictionResults!.containsKey('error')
                                      ? Icons.error
                                      : _predictionResults!['status'] ==
                                          'normal'
                                      ? Icons.check_circle
                                      : Icons.warning,
                                  color:
                                      _predictionResults!.containsKey('error')
                                          ? Colors.red
                                          : _predictionResults!['status'] ==
                                              'normal'
                                          ? Colors.green
                                          : Colors.orange,
                                  size: 28,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _predictionResults!.containsKey('error')
                                        ? 'Error'
                                        : _predictionResults!['status'] ==
                                            'normal'
                                        ? 'Heart Status: Normal'
                                        : 'Heart Status: Attention Required',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          _predictionResults!.containsKey(
                                                'error',
                                              )
                                              ? Colors.red
                                              : _predictionResults!['status'] ==
                                                  'normal'
                                              ? Colors.green.shade700
                                              : Colors.orange.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),

                            if (_predictionResults!.containsKey('error'))
                              Text(
                                _predictionResults!['error'],
                                style: TextStyle(color: Colors.red.shade800),
                              )
                            else ...[
                              _buildResultRow(
                                label: 'Confidence',
                                value:
                                    '${(_predictionResults!['confidence'] * 100).toStringAsFixed(2)}%',
                              ),

                              // Display Risk Factors
                              if (_predictionResults!['risk_factors'] != null &&
                                  (_predictionResults!['risk_factors'] as List)
                                      .isNotEmpty) ...[
                                SizedBox(height: 16),
                                Text(
                                  'Risk Factors:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                SizedBox(height: 8),
                                ..._predictionResults!['risk_factors']
                                    .map<Widget>((factor) {
                                      return Padding(
                                        padding: EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.arrow_right,
                                              size: 20,
                                              color: Colors.grey[600],
                                            ),
                                            SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                factor,
                                                style: TextStyle(
                                                  color: Colors.grey[800],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    })
                                    .toList(),
                              ],

                              // Display Health Tips
                              if (_predictionResults!['health_tips'] != null &&
                                  (_predictionResults!['health_tips'] as List)
                                      .isNotEmpty) ...[
                                SizedBox(height: 16),
                                Text(
                                  'Recommendations:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                SizedBox(height: 8),
                                ..._predictionResults!['health_tips']
                                    .map<Widget>((tip) {
                                      return Padding(
                                        padding: EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.tips_and_updates,
                                              size: 20,
                                              color: Theme.of(
                                                context,
                                              ).primaryColor.withOpacity(0.7),
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                tip,
                                                style: TextStyle(
                                                  color: Colors.grey[800],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    })
                                    .toList(),
                              ],

                              SizedBox(height: 16),
                              Text(
                                _predictionResults!['status'] == 'normal'
                                    ? 'Your heart health appears to be normal based on the current data.'
                                    : 'Some health metrics require attention. Please review the recommendations above.',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color:
                                      _predictionResults!['status'] == 'normal'
                                          ? Colors.green.shade800
                                          : Colors.orange.shade900,
                                ),
                              ),

                              if (_predictionResults!.containsKey('time'))
                                Padding(
                                  padding: const EdgeInsets.only(top: 12.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Last updated: ${_formatTimestamp(_predictionResults!['time'])}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],

                  SizedBox(height: 16),

                  // Anomaly Detection Section
                  if (_anomalyResults != null) ...[
                    _sectionTitle('Anomaly Detection'),
                    SizedBox(height: 16),

                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color:
                          _anomalyResults!.containsKey('error')
                              ? Colors.red.shade50
                              : _anomalyResults!['is_anomaly'] == true
                              ? Colors.orange.shade50
                              : Colors.green.shade50,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _anomalyResults!.containsKey('error')
                                      ? Icons.error
                                      : _anomalyResults!['is_anomaly'] == true
                                      ? Icons.warning_amber
                                      : Icons.check_circle,
                                  color:
                                      _anomalyResults!.containsKey('error')
                                          ? Colors.red
                                          : _anomalyResults!['is_anomaly'] ==
                                              true
                                          ? Colors.orange
                                          : Colors.green,
                                  size: 28,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _anomalyResults!.containsKey('error')
                                        ? 'Detection Error'
                                        : _anomalyResults!['is_anomaly'] == true
                                        ? 'Anomaly Detected'
                                        : 'Normal Pattern',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          _anomalyResults!.containsKey('error')
                                              ? Colors.red
                                              : _anomalyResults!['is_anomaly'] ==
                                                  true
                                              ? Colors.orange.shade800
                                              : Colors.green.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),

                            if (_anomalyResults!.containsKey('error')) ...[
                              Text(
                                _anomalyResults!['error'],
                                style: TextStyle(color: Colors.red.shade800),
                              ),
                              if (_anomalyResults!.containsKey(
                                'missing_fields',
                              ))
                                Text(
                                  'Missing: ${_anomalyResults!['missing_fields'].join(', ')}',
                                  style: TextStyle(
                                    color: Colors.red.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                            ] else ...[
                              _buildResultRow(
                                label: 'Risk Level',
                                value:
                                    _anomalyResults!['risk_level'] ?? 'Unknown',
                              ),
                              _buildResultRow(
                                label: 'Confidence',
                                value:
                                    '${(_anomalyResults!['probability'] * 100).toStringAsFixed(1)}%',
                              ),

                              SizedBox(height: 16),
                              Text(
                                _anomalyResults!['is_anomaly'] == true
                                    ? 'Your current health metrics show an unusual pattern. Please monitor closely and consider consulting your healthcare provider.'
                                    : 'Your health metrics are within normal patterns. Continue your current routine.',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color:
                                      _anomalyResults!['is_anomaly'] == true
                                          ? Colors.orange.shade900
                                          : Colors.green.shade800,
                                ),
                              ),

                              if (_anomalyResults!.containsKey('time'))
                                Padding(
                                  padding: const EdgeInsets.only(top: 12.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Last checked: ${_formatTimestamp(_anomalyResults!['time'])}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Anomaly Model Status Card
                    Card(
                      color: Theme.of(context).primaryColor.withOpacity(0.08),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            if (_isLoadingAnomalyModel)
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).primaryColor,
                                ),
                              )
                            else
                              Icon(
                                Icons.psychology,
                                color: Theme.of(context).primaryColor,
                                size: 20,
                              ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Anomaly Detection: $_anomalyModelStatus',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 16),
                  ],

                  // Info card about data
                  Card(
                    color: Theme.of(context).primaryColor.withOpacity(0.08),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(context).primaryColor,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Health data is collected in real-time from your sensors. The AI model provides automatic assessment based on your heart rate, temperature, age, and gender.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Format timestamp to readable date/time
  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }

  Widget _buildResultRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildHealthCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String unit,
  }) {
    final bool hasData = value != 'No data';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Text(
                    hasData ? value : 'No data',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: hasData ? Colors.black87 : Colors.grey,
                    ),
                  ),
                  if (hasData)
                    Text(
                      ' $unit',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
