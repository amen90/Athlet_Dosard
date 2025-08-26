import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import 'dart:async';

class AthleteDetailScreen extends StatefulWidget {
  final Map<String, dynamic> athleteData;

  const AthleteDetailScreen({super.key, required this.athleteData});

  @override
  State<AthleteDetailScreen> createState() => _AthleteDetailScreenState();
}

class _AthleteDetailScreenState extends State<AthleteDetailScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  StreamSubscription? _athleteDataSubscription;
  Map<String, dynamic> _currentAthleteData = {};

  @override
  void initState() {
    super.initState();
    _currentAthleteData = Map<String, dynamic>.from(widget.athleteData);
    _setupAthleteDataStream();
  }

  void _setupAthleteDataStream() {
    _athleteDataSubscription = _firebaseService
        .streamAthleteData(widget.athleteData['uid'])
        .listen(
          (athleteData) {
            if (athleteData != null && mounted) {
              setState(() {
                _currentAthleteData = athleteData;
              });
            }
          },
          onError: (error) {
            print('Error in athlete data stream: $error');
          },
        );
  }

  @override
  void dispose() {
    _athleteDataSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentAthleteData['name'] ?? 'Athlete Details'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
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
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Text(
                            _currentAthleteData['name']
                                    ?.substring(0, 1)
                                    .toUpperCase() ??
                                'A',
                            style: TextStyle(fontSize: 24, color: Colors.white),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentAthleteData['name'] ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _currentAthleteData['email'] ?? 'No email',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 32),
                    _buildInfoRow(
                      'Age',
                      '${_currentAthleteData['age'] ?? 'N/A'}',
                    ),
                    _buildInfoRow(
                      'Gender',
                      _currentAthleteData['gender'] ?? 'N/A',
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Health Data Section
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
                    Text(
                      'Real-time Health Data',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildHealthDataRow(
                      'HR',
                      _currentAthleteData['hr']?.toString() ?? 'N/A',
                      'BPM',
                      Icons.favorite,
                      Colors.red,
                    ),
                    SizedBox(height: 12),
                    _buildHealthDataRow(
                      'Temperature',
                      _currentAthleteData['temp']?.toString() ?? 'N/A',
                      '°C',
                      Icons.thermostat,
                      Colors.orange,
                    ),
                    SizedBox(height: 12),
                    _buildHealthDataRow(
                      'SpO2',
                      _currentAthleteData['spo2']?.toString() ?? 'N/A',
                      '%',
                      Icons.bloodtype,
                      Colors.blue,
                    ),
                    SizedBox(height: 12),
                    _buildHealthDataRow(
                      'Activity',
                      _currentAthleteData['activity'] ?? 'N/A',
                      '',
                      _currentAthleteData['activity'] == 'Weightlifting'
                          ? Icons.fitness_center
                          : Icons.directions_run,
                      Theme.of(context).primaryColor,
                    ),
                    SizedBox(height: 12),
                    _buildHealthDataRow(
                      'Fatigue Score',
                      _currentAthleteData['fatigue_score']?.toString() ?? 'N/A',
                      '/10',
                      Icons.battery_3_bar,
                      Color(0xFF9C27B0),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildHealthDataRow(
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    final bool hasData = value != 'N/A';

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: hasData ? Colors.black87 : Colors.grey,
                  ),
                ),
                if (hasData) ...[
                  SizedBox(width: 4),
                  Text(
                    unit,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}
