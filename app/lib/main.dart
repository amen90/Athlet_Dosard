import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import './screen/welcome_screen.dart';
import 'screen/dashboard_screen.dart';
import 'screen/login_screen.dart';
import 'screen/register_screen.dart';
import 'screen/athlete_profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

// Enhanced theme colors based on logo
class AppColors {
  // Main brand color - Deep Purple 800
  static const MaterialColor primaryPurple =
      MaterialColor(0xFF4527A0, <int, Color>{
        50: Color(0xFFEDE7F6),
        100: Color(0xFFD1C4E9),
        200: Color(0xFFB39DDB),
        300: Color(0xFF9575CD),
        400: Color(0xFF7E57C2),
        500: Color(0xFF673AB7),
        600: Color(0xFF5E35B1),
        700: Color(0xFF512DA8),
        800: Color(0xFF4527A0),
        900: Color(0xFF311B92),
      });

  // Secondary accent color - Light Purple
  static const Color accentColor = Color(0xFFB39DDB); // Purple 200

  // Background colors
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color cardColor = Colors.white;

  // Status colors
  static const Color success = Color(0xFF4CAF50); // Green
  static const Color warning = Color(0xFFFFC107); // Amber
  static const Color error = Color(0xFFE53935); // Red

  // Data visualization colors
  static const Color heartRateColor = Color(0xFFE53935); // Red
  static const Color tempColor = Color(0xFFFF9800); // Orange

  // Gradients
  static LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF673AB7), // Purple 500
      Color(0xFF4527A0), // Deep Purple 800
    ],
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trackervest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: AppColors.primaryPurple,
        scaffoldBackgroundColor: AppColors.backgroundColor,
        visualDensity: VisualDensity.adaptivePlatformDensity,

        // Enhanced card theme
        cardTheme: CardTheme(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: AppColors.primaryPurple.withOpacity(0.3),
        ),

        // Enhanced appBar theme
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),

        // Enhanced button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: AppColors.primaryPurple,
            elevation: 3,
            padding: EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),

        // Enhanced text field theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primaryPurple.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primaryPurple.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.error, width: 1),
          ),
          prefixIconColor: AppColors.primaryPurple.shade300,
          suffixIconColor: AppColors.primaryPurple.shade300,
          hintStyle: TextStyle(color: Colors.grey.shade400),
        ),

        // Text themes
        textTheme: TextTheme(
          headlineLarge: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryPurple.shade800,
          ),
          headlineMedium: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryPurple.shade800,
          ),
          titleLarge: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Colors.black87),
        ),

        // Icon theme
        iconTheme: IconThemeData(color: AppColors.primaryPurple),
      ),
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => WelcomeScreen(),
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/dashboard': (context) => DashboardScreen(),
        '/athlete_profile': (context) {
          final userData =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return AthleteProfileScreen(userData: userData);
        },
      },
    );
  }
}
