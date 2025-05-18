import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';


class AuthService {

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign in with email and password

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      return userCredential.user;
    } catch (error) {
      print("Error signing in: $error");
      return null;
    }
  }

  // Register with email and password

  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await userCredential.user?.sendEmailVerification();
      print("Verification email sent!");
      if (userCredential.user != null && userCredential.user!.emailVerified) {
        print("Login successful, email verified!");
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        // Allow access to your app
      } else {
        print("Email not verified. Please check your inbox.");
        await _auth.signOut();
      }
      return userCredential.user;
    } catch (error) {
      print("Error registering user: $error");
      return null;
    }
  }
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // user canceled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      return userCredential.user;
    } catch (error) {
      print("Google Sign-In error: $error");
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();          // Sign out from Google
      await _auth.signOut();                   // Sign out from Firebase
      print('User signed out successfully');
    } catch (e) {
      print('Error signing out: $e');
    }
  }
  // Get the current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }


}