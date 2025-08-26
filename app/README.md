# TrackerVest 🏃‍♂️📊

A comprehensive Flutter-based health monitoring and athlete management system that provides real-time health tracking, anomaly detection, and performance analytics for athletes and coaches.

## 🌟 Features

### 🔐 Authentication & User Management
- **Dual Role System**: Separate interfaces for athletes and coaches
- **Firebase Authentication**: Secure login and registration
- **Role-based Access Control**: Different permissions for athletes vs coaches

### 📱 Athlete Dashboard
- **Real-time Health Monitoring**: Live tracking of vital signs
- **Health Metrics Display**: 
  - Heart Rate (HR) monitoring
  - SpO2 (Blood Oxygen Saturation) levels
  - Body Temperature tracking
  - Fatigue Score assessment (1-10 scale)
- **Activity Selection**: Choose between Weightlifting and Running activities
- **Anomaly Detection**: AI-powered risk assessment with visual indicators
- **Personal Health History**: Track trends and patterns over time

### 👨‍💼 Coach Dashboard
- **Multi-Athlete Management**: Monitor multiple athletes simultaneously
- **Comprehensive Overview**: View all athletes' health metrics at a glance
- **Health Status Indicators**: Quick visual assessment of athlete conditions
- **Detailed Athlete Profiles**: Deep dive into individual athlete data
- **Risk Assessment**: Monitor anomaly detection results across the team

### 🤖 AI-Powered Anomaly Detection
- **Machine Learning Integration**: TensorFlow Lite models for real-time analysis
- **Multi-Model System**: 
  - Heart Status Classification
  - Athlete Anomaly Detection
- **Risk Level Assessment**: 
  - Very Low Risk (Green)
  - Low Risk (Yellow)
  - Moderate Risk (Orange)
  - High Risk (Red)
- **Real-time Processing**: Instant analysis of health data
- **Data Validation**: Ensures data integrity before processing

### 🔥 Firebase Integration
- **Firestore Database**: Real-time data synchronization
- **Cloud Storage**: Secure data storage and retrieval
- **Real-time Updates**: Live data streaming between devices
- **Scalable Architecture**: Handles multiple users simultaneously

## 🏗️ Technical Architecture

### Frontend (Flutter)
- **Cross-platform**: iOS and Android support
- **Material Design**: Modern, intuitive UI/UX
- **Real-time Updates**: StreamBuilder for live data
- **State Management**: Efficient data flow and UI updates

### Backend (Firebase)
- **Authentication**: Firebase Auth for user management
- **Database**: Firestore for real-time data storage
- **Cloud Functions**: Serverless backend processing
- **Security Rules**: Role-based data access control

### Machine Learning
- **TensorFlow Lite**: On-device ML inference
- **Custom Models**: Trained specifically for athlete health data
- **Preprocessing Pipeline**: Data normalization and feature engineering
- **Model Validation**: Ensures accurate predictions

## 📊 Data Schema

### User Profile
```json
{
  "email": "athlete@example.com",
  "role": "athlete",
  "hr": 75,
  "spo2": 98,
  "temperature": 36.5,
  "fatigue_score": 5,
  "activity": "Weightlifting",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

### Health Metrics Ranges
- **Heart Rate**: 40-250 BPM
- **SpO2**: 80-105%
- **Temperature**: 30-45°C
- **Fatigue Score**: 1-10 scale
- **Activities**: Weightlifting, Running

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Firebase CLI
- Android Studio / VS Code
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Destro2204/trackervest.git
   cd trackervest
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a new Firebase project
   - Enable Authentication and Firestore
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place configuration files in appropriate directories

4. **Seed Database** (Optional)
   ```bash
   node seedFirestore.js
   ```

5. **Run the application**
   ```bash
   flutter run
   ```

## 📁 Project Structure

```
lib/
├── models/           # Data models and schemas
├── screen/          # UI screens and pages
├── services/        # Business logic and API services
├── widgets/         # Reusable UI components
└── main.dart       # Application entry point

assets/
├── model/          # TensorFlow Lite models
└── config/         # Configuration files

firebase/
└── seedFirestore.js # Database seeding script
```

## 🔧 Configuration

### Firebase Configuration
1. Update Firebase configuration in `lib/services/firebase_service.dart`
2. Configure Firestore security rules
3. Set up authentication providers

### Model Configuration
- Models are stored in `assets/model/`
- Configuration files in `assets/config/`
- Preprocessing parameters in `mobile_config.json`

## 🧪 Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

## 📈 Performance Monitoring

- **Real-time Analytics**: Firebase Analytics integration
- **Crash Reporting**: Firebase Crashlytics
- **Performance Monitoring**: Firebase Performance
- **Custom Metrics**: Health data analytics

## 🔒 Security Features

- **Data Encryption**: End-to-end encryption for sensitive health data
- **Role-based Access**: Secure data access based on user roles
- **Input Validation**: Comprehensive data validation and sanitization
- **Privacy Compliance**: HIPAA-compliant health data handling

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Team

- **Developer**: [Your Name]
- **Project Type**: Health Monitoring & Athlete Management System
- **Technology Stack**: Flutter, Firebase, TensorFlow Lite

## 📞 Support

For support and questions:
- Create an issue on GitHub
- Contact: [medtaherjouida@gmail.com]

## 🔄 Version History

- **v1.0.0**: Initial release with basic health monitoring
- **v1.1.0**: Added anomaly detection and AI models
- **v1.2.0**: Enhanced dashboard and coach features
- **v1.3.0**: Added activity selection and fatigue scoring

---

**TrackerVest** - Empowering athletes and coaches with intelligent health monitoring and performance analytics. 🏆
