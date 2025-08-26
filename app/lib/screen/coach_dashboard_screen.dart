import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/ml_service.dart';
import 'athlete_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class CoachDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const CoachDashboardScreen({super.key, required this.userData});

  @override
  State<CoachDashboardScreen> createState() => _CoachDashboardScreenState();
}

class _CoachDashboardScreenState extends State<CoachDashboardScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final MLService _mlService = MLService();
  StreamSubscription? _athletesSubscription;
  List<Map<String, dynamic>> _athletes = [];

  @override
  void initState() {
    super.initState();
    _setupAthletesStream();
    _initializeMLService();
  }

  void _setupAthletesStream() {
    _athletesSubscription = _firebaseService.streamAllAthletes().listen(
      (athletes) {
        if (mounted) {
          setState(() {
            _athletes = athletes;
          });
        }
      },
      onError: (error) {
        print('Error in athletes stream: $error');
      },
    );
  }

  void _initializeMLService() async {
    try {
      // Initialize ML models in background and wait for them to load
      print('Loading ML models for coach dashboard...');

      final heartModel = await _mlService.getHeartStatusModel();
      print('Heart model status: ${heartModel?['status']}');

      final anomalyModel = await _mlService.getAnomalyDetectorModel();
      print('Anomaly model status: ${anomalyModel?['status']}');

      if (heartModel?['status'] == 'loaded' &&
          anomalyModel?['status'] == 'loaded') {
        print('✅ All ML models loaded successfully for coach dashboard');
      } else {
        print('⚠️ Some ML models failed to load');
      }
    } catch (e) {
      print('❌ Error initializing ML service in coach dashboard: $e');
    }
  }

  @override
  void dispose() {
    _athletesSubscription?.cancel();
    _mlService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Coach Dashboard'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed:
                () => Navigator.pushReplacementNamed(context, '/welcome'),
          ),
        ],
      ),
      body:
          _athletes.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.group_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No athletes found',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _athletes.length,
                itemBuilder: (context, index) {
                  final athlete = _athletes[index];
                  final hasHealthData =
                      athlete['hr'] != null ||
                      athlete['temp'] != null ||
                      athlete['spo2'] != null ||
                      athlete['activity'] != null ||
                      athlete['fatigue_score'] != null;

                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.all(16),
                      childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          athlete['name']?.substring(0, 1).toUpperCase() ?? 'A',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        athlete['name'] ?? 'Unknown Athlete',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle:
                          hasHealthData
                              ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 8),
                                  if (athlete['hr'] != null)
                                    _buildHealthIndicator(
                                      Icons.favorite,
                                      Colors.red,
                                      'HR',
                                      '${athlete['hr']} BPM',
                                    ),
                                  if (athlete['temp'] != null)
                                    Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: _buildHealthIndicator(
                                        Icons.thermostat,
                                        Colors.orange,
                                        'Temperature',
                                        '${athlete['temp']}°C',
                                      ),
                                    ),
                                  if (athlete['spo2'] != null)
                                    Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: _buildHealthIndicator(
                                        Icons.bloodtype,
                                        Colors.blue,
                                        'SpO2',
                                        '${athlete['spo2']}%',
                                      ),
                                    ),
                                  if (athlete['activity'] != null)
                                    Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: _buildHealthIndicator(
                                        athlete['activity'] == 'Weightlifting'
                                            ? Icons.fitness_center
                                            : Icons.directions_run,
                                        Theme.of(context).primaryColor,
                                        'Activity',
                                        athlete['activity'],
                                      ),
                                    ),
                                  if (athlete['fatigue_score'] != null)
                                    Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: _buildHealthIndicator(
                                        Icons.battery_3_bar,
                                        Color(0xFF9C27B0),
                                        'Fatigue',
                                        '${athlete['fatigue_score']}/10',
                                      ),
                                    ),
                                ],
                              )
                              : Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'No health data available',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                      trailing: Icon(Icons.expand_more),
                      children: [
                        // AI Analysis Section
                        _buildAIAnalysisSection(athlete),
                        SizedBox(height: 8),
                        // View Details Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => AthleteDetailScreen(
                                        athleteData: athlete,
                                      ),
                                ),
                              );
                            },
                            icon: Icon(Icons.person),
                            label: Text('View Full Details'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }

  Widget _buildHealthIndicator(
    IconData icon,
    Color color,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildAIAnalysisSection(Map<String, dynamic> athlete) {
    final hasCompleteData =
        athlete['hr'] != null &&
        athlete['temp'] != null &&
        athlete['spo2'] != null &&
        athlete['activity'] != null &&
        athlete['fatigue_score'] != null;

    if (!hasCompleteData) {
      return Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Insufficient data for AI analysis',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Health Analysis',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 12),

        // Health Assessment Card
        FutureBuilder<Map<String, dynamic>?>(
          future: _getHealthAssessment(athlete),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildAnalysisCard(
                title: 'Heart Status Assessment',
                icon: Icons.favorite,
                color: Colors.orange,
                content: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Analyzing...'),
                  ],
                ),
              );
            }

            final assessment = snapshot.data;
            if (assessment == null || assessment.containsKey('error')) {
              return _buildAnalysisCard(
                title: 'Heart Status Assessment',
                icon: Icons.error,
                color: Colors.red,
                content: Text(
                  assessment?['error'] ?? 'Analysis failed',
                  style: TextStyle(color: Colors.red),
                ),
              );
            }

            final status = assessment['status'] ?? 'unknown';
            final confidence = assessment['confidence'] ?? 0.0;
            final issues = assessment['issues'] as List<dynamic>? ?? [];

            return _buildAnalysisCard(
              title: 'Health Status Assessment',
              icon: status == 'normal' ? Icons.check_circle : Icons.warning,
              color: status == 'normal' ? Colors.green : Colors.orange,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status: ${status == 'normal' ? 'Normal' : 'Attention Required'}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color:
                          status == 'normal'
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                    ),
                  ),
                  if (issues.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      'Issues: ${issues.join(", ")}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                  Text(
                    'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            );
          },
        ),

        SizedBox(height: 12),

        // Anomaly Detection Card
        FutureBuilder<Map<String, dynamic>?>(
          future: _getAnomalyDetection(athlete),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildAnalysisCard(
                title: 'Anomaly Detection',
                icon: Icons.psychology,
                color: Colors.purple,
                content: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Scanning...'),
                  ],
                ),
              );
            }

            final anomaly = snapshot.data;
            if (anomaly == null || anomaly.containsKey('error')) {
              final errorMessage = anomaly?['error'] ?? 'Detection failed';

              // Provide more user-friendly error messages
              String displayError = errorMessage;
              Color errorColor = Colors.red;

              if (errorMessage.contains('model not available') ||
                  errorMessage.contains('not loaded')) {
                displayError = 'AI model loading...';
                errorColor = Colors.orange;
              } else if (errorMessage.contains('Missing required data')) {
                displayError = 'Incomplete health data';
                errorColor = Colors.grey;
              } else if (errorMessage.contains('Invalid')) {
                displayError = 'Invalid health data detected';
                errorColor = Colors.orange;
              }

              return _buildAnalysisCard(
                title: 'Anomaly Detection',
                icon:
                    errorColor == Colors.orange
                        ? Icons.hourglass_empty
                        : Icons.error,
                color: errorColor,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayError, style: TextStyle(color: errorColor)),
                    if (errorMessage.contains('Invalid') ||
                        errorMessage.contains('Missing')) ...[
                      SizedBox(height: 4),
                      Text(
                        'Check athlete\'s health data values',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ],
                ),
              );
            }

            final isAnomaly = anomaly['is_anomaly'] ?? false;
            final riskLevel = anomaly['risk_level'] ?? 'Unknown';
            final probability = anomaly['probability'] ?? 0.0;

            return _buildAnalysisCard(
              title: 'Anomaly Detection',
              icon: isAnomaly ? Icons.warning_amber : Icons.check_circle,
              color: isAnomaly ? Colors.orange : Colors.green,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAnomaly ? 'Anomaly Detected' : 'Normal Pattern',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color:
                          isAnomaly
                              ? Colors.orange.shade700
                              : Colors.green.shade700,
                    ),
                  ),
                  Text(
                    'Risk Level: $riskLevel',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  Text(
                    'Confidence: ${(probability * 100).toStringAsFixed(1)}%',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAnalysisCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget content,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _getHealthAssessment(
    Map<String, dynamic> athlete,
  ) async {
    try {
      // Simple health assessment based on standard ranges
      final hr = athlete['hr']?.toDouble() ?? 0;
      final temp = athlete['temp']?.toDouble() ?? 0;
      final spo2 = athlete['spo2']?.toDouble() ?? 0;

      List<String> issues = [];
      String status = 'normal';
      double confidence = 1.0;

      // Heart rate assessment
      if (hr > 100) {
        issues.add('Elevated heart rate');
        status = 'attention_required';
        confidence = 0.8;
      } else if (hr < 60) {
        issues.add('Low heart rate');
        status = 'attention_required';
        confidence = 0.7;
      }

      // Temperature assessment
      if (temp > 37.5) {
        issues.add('Elevated temperature');
        status = 'attention_required';
        confidence = 0.9;
      } else if (temp < 36.0) {
        issues.add('Low temperature');
        status = 'attention_required';
        confidence = 0.6;
      }

      // SpO2 assessment
      if (spo2 < 95) {
        issues.add('Low oxygen saturation');
        status = 'attention_required';
        confidence = 0.85;
      }

      return {
        'status': status,
        'confidence': confidence,
        'issues': issues,
        'time': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      return {'error': 'Assessment failed: $e'};
    }
  }

  Future<Map<String, dynamic>?> _getAnomalyDetection(
    Map<String, dynamic> athlete,
  ) async {
    try {
      // Ensure the anomaly model is loaded first
      final modelStatus = await _mlService.getAnomalyDetectorModel();
      if (modelStatus == null || modelStatus['status'] != 'loaded') {
        return {
          'error':
              'Anomaly model not available: ${modelStatus?['message'] ?? 'Unknown error'}',
        };
      }

      // Validate input data
      final hr = athlete['hr']?.toDouble();
      final spo2 = athlete['spo2']?.toDouble();
      final fatigueScore = athlete['fatigue_score']?.toDouble();
      final temp = athlete['temp']?.toDouble();
      final activity = athlete['activity'];

      if (hr == null ||
          spo2 == null ||
          fatigueScore == null ||
          temp == null ||
          activity == null) {
        return {'error': 'Missing required data for anomaly detection'};
      }

      // Validate data ranges
      if (hr <= 0 || hr > 300) {
        return {'error': 'Invalid heart rate: $hr'};
      }
      if (spo2 <= 0 || spo2 > 100) {
        return {'error': 'Invalid SpO2: $spo2'};
      }
      if (fatigueScore < 1 || fatigueScore > 10) {
        return {'error': 'Invalid fatigue score: $fatigueScore'};
      }
      if (temp < 30 || temp > 45) {
        return {'error': 'Invalid temperature: $temp'};
      }

      final result = await _mlService.predictAnomaly(
        heartRate: hr,
        oxygenLevel: spo2,
        fatigueScore: fatigueScore,
        temperature: temp,
        activity: activity,
      );
      return result;
    } catch (e) {
      print('Anomaly detection error in coach dashboard: $e');
      return {'error': 'Detection failed: ${e.toString()}'};
    }
  }
}
