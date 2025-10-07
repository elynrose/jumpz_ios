import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'services/native_alarm_service.dart';
import 'services/jump_detection_settings_service.dart';
import 'services/calories_service.dart';
import 'services/mock_subscription_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_tab_screen.dart';

/// Entry point for the Jumpz application.
///
/// The app initialises Firebase, sets up local notifications and provides
/// dependency injection for authentication and Firestore services. A
/// [StreamBuilder] is used to reactively display either the authentication
/// screen or the main application once the user is signed in.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase first (required for app to work)
  await _initializeFirebase();
  
  // Initialize notifications in background
  _initializeNotificationsAsync();

  runApp(const MyApp());
}

/// Initialize Firebase (required for app to work)
Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyBQwNmCFV9H1WVR4NFsgfB-T_PRh5-Yf8g',
        appId: '1:1097026820781:ios:b3bd186af3d3c09a194424',
        messagingSenderId: '1097026820781',
        projectId: 'jmpz-5bea8',
        storageBucket: 'jmpz-5bea8.firebasestorage.app',
      ),
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
    print('⚠️  App will continue without Firebase features');
  }
}

/// Initialize notifications asynchronously without blocking app startup
void _initializeNotificationsAsync() async {
  try {
    await NotificationService().init();
    print('✅ Notifications initialized successfully');
  } catch (e) {
    print('❌ Notification initialization failed: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core services - initialize immediately
        Provider<AuthService>(create: (_) => AuthService()),
        // Heavy services - lazy initialization
        Provider<FirestoreService>(create: (_) => FirestoreService(), lazy: true),
        Provider<CaloriesService>(create: (_) => CaloriesService(), lazy: true),
        ChangeNotifierProvider<JumpDetectionSettingsService>(
          create: (context) => JumpDetectionSettingsService(
            Provider.of<FirestoreService>(context, listen: false),
          ),
          lazy: true,
        ),
        ChangeNotifierProvider<MockSubscriptionService>(
          create: (_) => MockSubscriptionService(),
          lazy: true,
        ),
      ],
      child: MaterialApp(
        title: 'Jumpz',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFFD700), // Gold
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: Colors.black,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            color: Colors.grey[900],
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFFFD700), width: 1),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[900],
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFFFD700), width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.grey[900],
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFFFD700), width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFFFD700), width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFFD700)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFFD700)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2),
            ),
            labelStyle: const TextStyle(color: Colors.white),
            hintStyle: const TextStyle(color: Colors.grey),
          ),
        ),
        home: const _RootRouter(),
      ),
    );
  }
}

/// A private widget that listens to the authentication state and routes
/// accordingly. When a user is signed in the [HomeScreen] is shown, otherwise
/// the [LoginScreen] is displayed.
class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _checkFirebaseInitialized(),
      builder: (context, firebaseSnapshot) {
        if (firebaseSnapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        
        if (!firebaseSnapshot.hasData || firebaseSnapshot.data == false) {
          return const SplashScreen();
        }
        
        final auth = Provider.of<AuthService>(context, listen: false);
        return StreamBuilder(
          stream: auth.authStateChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.active) {
              final user = snapshot.data;
              if (user != null) {
                // User is authenticated, restore alarms
                _restoreAlarms(context);
                return const MainTabScreen();
              } else {
                return const LoginScreen();
              }
            }
            return const SplashScreen();
          },
        );
      },
    );
  }

  /// Check if Firebase is initialized
  Future<bool> _checkFirebaseInitialized() async {
    try {
      // Try to get Firebase app instance
      Firebase.app();
      return true;
    } catch (e) {
      print('❌ Firebase not initialized: $e');
      return false;
    }
  }

  /// Restores alarms when user is authenticated - runs in background
  void _restoreAlarms(BuildContext context) {
    // Run in background to avoid blocking UI
    Future.microtask(() async {
      try {
        final firestore = Provider.of<FirestoreService>(context, listen: false);
        
        // Restore native alarm (primary method)
        await NativeAlarmService.restorePersistentAlarm(firestore);
        
        // Load jump detection settings
        final settingsService = Provider.of<JumpDetectionSettingsService>(context, listen: false);
        await settingsService.loadSettings();
      } catch (e) {
        print('❌ Error restoring alarms in main app: $e');
      }
    });
  }
}

/// A splash screen with animated background that shows while the app is loading
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Black background
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                ),
              ),
              // Loading indicator overlay
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App logo image - transparent display
                    SizedBox(
                      width: 300,
                      height: 300,
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          print('❌ Error loading logo: $error');
                          return Container(
                            color: Colors.red,
                            child: const Center(
                              child: Text(
                                'LOGO ERROR',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Loading indicator
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 20),
                    // Loading text
                    Text(
                      'Loading...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}