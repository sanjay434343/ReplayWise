import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/gmail.readonly',
      'https://www.googleapis.com/auth/gmail.modify',
      'https://mail.google.com/',
    ],
  );

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get current user UID
  String? get currentUserUid => _auth.currentUser?.uid;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Save UID to SharedPreferences (no encryption)
  Future<void> saveUidToPrefs(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('uid', uid);
  }

  // Load UID from SharedPreferences (no decryption)
  Future<String?> loadUidFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('uid');
  }

  // Remove UID from SharedPreferences
  Future<void> removeUidFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('uid');
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      print('Starting Google Sign-In...');
      print('Package name: com.app.replywise');
      print('SHA-1 fingerprint: 08:52:49:66:E6:C3:0C:AE:56:A8:E8:15:6A:2F:E9:D8:79:8C:78:F0');
      print('Using auto-configured client ID from google-services.json');
      
      // Check if Google Play Services is available
      final bool isAvailable = await _googleSignIn.isSignedIn();
      print('Google Play Services previously signed in: $isAvailable');
      
      // Sign out first to ensure clean state
      await _googleSignIn.signOut();
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled the sign-in
        print('Google Sign-In was cancelled by user');
        return null;
      }

      print('Google Sign-In successful for: ${googleUser.email}');
      print('Google User ID: ${googleUser.id}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Failed to get Google authentication tokens');
      }

      print('Google Auth tokens obtained successfully');
      print('Access Token: ${googleAuth.accessToken != null ? "Present" : "Missing"}');
      print('ID Token: ${googleAuth.idToken != null ? "Present" : "Missing"}');

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        // Save UID (no encryption)
        await saveUidToPrefs(userCredential.user!.uid);
        print('Firebase authentication successful');
        print('User UID: ${userCredential.user!.uid}');
        print('User Email: ${userCredential.user!.email}');
        print('User Display Name: ${userCredential.user!.displayName}');
      }
      
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'account-exists-with-different-credential':
          throw Exception('An account already exists with a different credential.');
        case 'invalid-credential':
          throw Exception('Invalid credential provided.');
        case 'operation-not-allowed':
          throw Exception('Google sign-in is not enabled.');
        case 'user-disabled':
          throw Exception('This user account has been disabled.');
        case 'user-not-found':
          throw Exception('No user found for this credential.');
        case 'wrong-password':
          throw Exception('Wrong password provided.');
        default:
          throw Exception('Firebase Auth Error: ${e.message}');
      }
    } catch (e) {
      print('Google Sign-In Error: $e');
      if (e.toString().contains('ApiException: 10')) {
        print('DEVELOPER_ERROR detected. Your SHA-1 fingerprint is:');
        print('08:52:49:66:E6:C3:0C:AE:56:A8:E8:15:6A:2F:E9:D8:79:8C:78:F0');
        print('Please ensure this SHA-1 is added to your Firebase Console:');
        print('1. Go to Firebase Console → Project Settings → General');
        print('2. Scroll to "Your apps" → Android app');
        print('3. Add the SHA-1 fingerprint above');
        print('4. Verify package name is: com.app.replywise');
        
        throw Exception('Configuration Error: SHA-1 fingerprint not found in Firebase Console. Please add: 08:52:49:66:E6:C3:0C:AE:56:A8:E8:15:6A:2F:E9:D8:79:8C:78:F0');
      }
      // Bypass to home page if the error is the type cast error
      if (e.toString().contains("type 'List<Object?>' is not a subtype of type 'PigeonUserDetails?'")) {
        print('Bypassing error and treating as login success.');
        return _auth.currentUser;
      }
      throw Exception('Google sign-in failed: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      print('Signing out user...');
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      await removeUidFromPrefs();
      print('Sign out successful');
    } catch (e) {
      print('Sign out error: $e');
      throw Exception('Sign out failed: $e');
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        print('Deleting user account: ${user.uid}');
        await user.delete();
        await _googleSignIn.signOut();
        print('Account deletion successful');
      }
    } catch (e) {
      print('Account deletion error: $e');
      throw Exception('Account deletion failed: $e');
    }
  }

  // Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;

  // Get user display name
  String? get userDisplayName => _auth.currentUser?.displayName;

  // Get user email
  String? get userEmail => _auth.currentUser?.email;

  // Get user photo URL
  String? get userPhotoURL => _auth.currentUser?.photoURL;

  // Get user creation time
  DateTime? get userCreationTime => _auth.currentUser?.metadata.creationTime;

  // Get last sign in time
  DateTime? get lastSignInTime => _auth.currentUser?.metadata.lastSignInTime;

  // Check if email is verified
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  // Get provider data
  List<UserInfo> get providerData => _auth.currentUser?.providerData ?? [];

  // Reload user data
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
    } catch (e) {
      print('Error reloading user: $e');
    }
  }

  // Get ID token
  Future<String?> getIdToken() async {
    try {
      return await _auth.currentUser?.getIdToken();
    } catch (e) {
      print('Error getting ID token: $e');
      return null;
    }
  }

  // Check Google Sign-In status
  Future<bool> isGoogleSignedIn() async {
    try {
      return await _googleSignIn.isSignedIn();
    } catch (e) {
      print('Error checking Google sign-in status: $e');
      return false;
    }
  }

  // Get Google access token (for API calls)
  Future<String?> getGoogleAccessToken() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signInSilently();
      if (account != null) {
        final GoogleSignInAuthentication auth = await account.authentication;
        return auth.accessToken;
      }
      return null;
    } catch (e) {
      print('Error getting Google access token: $e');
      return null;
    }
  }

  // Try auto-login using stored UID
  Future<bool> tryAutoLogin() async {
    final uid = await loadUidFromPrefs();
    if (uid != null && _auth.currentUser != null && _auth.currentUser!.uid == uid) {
      return true;
    }
    return false;
  }
}
