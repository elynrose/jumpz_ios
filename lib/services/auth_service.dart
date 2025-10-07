import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';

/// A simple wrapper around [FirebaseAuth] providing helper methods for sign
/// in/out and exposing an authentication state stream. This class should be
/// provided via a [Provider] at the root of the application to allow easy
/// access to authentication state across the widget tree.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isFirebaseInitialized = false;

  AuthService() {
    _checkFirebaseStatus();
  }

  void _checkFirebaseStatus() {
    try {
      // Try to access Firebase Auth to check if it's initialized
      _auth.currentUser;
      _isFirebaseInitialized = true;
      print('✅ Firebase Auth is available');
    } catch (e) {
      _isFirebaseInitialized = false;
      print('❌ Firebase Auth not available: $e');
    }
  }

  /// Stream of authentication state changes. Emitted whenever the current user
  /// signs in or out.
  Stream<User?> get authStateChanges {
    if (!_isFirebaseInitialized) {
      // Return a stream that immediately emits null if Firebase is not initialized
      return Stream.value(null);
    }
    return _auth.authStateChanges();
  }

  /// The currently signed‑in user, or null if no user is signed in.
  User? get currentUser {
    if (!_isFirebaseInitialized) return null;
    return _auth.currentUser;
  }

  /// Creates a new user using an email and password. The display name can be
  /// set after registration via [updateDisplayName] on the returned user.
  Future<UserCredential> signUp({required String email, required String password}) async {
    if (!_isFirebaseInitialized) {
      throw Exception('Firebase is not initialized. Please check your configuration.');
    }
    final result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    // Initialize user document in Firestore
    final firestoreService = FirestoreService();
    await firestoreService.initUserIfNew();
    return result;
  }

  /// Signs in a user using an email and password.
  Future<UserCredential> signIn({required String email, required String password}) async {
    if (!_isFirebaseInitialized) {
      throw Exception('Firebase is not initialized. Please check your configuration.');
    }
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Google Sign-In is not available - using email/password authentication only

  /// Signs out the current user. Returns a future that completes once the user
  /// has been signed out.
  Future<void> signOut() async {
    if (!_isFirebaseInitialized) {
      print('⚠️  Firebase not initialized, cannot sign out');
      return;
    }
    return _auth.signOut();
  }
}