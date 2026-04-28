import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SocialAuthResult {
  final User? user;
  final String? accessToken;
  final String? idToken;
  final String provider;

  SocialAuthResult({
    this.user,
    this.accessToken,
    this.idToken,
    required this.provider,
  });
}

class SocialAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '1054468511277-uq2b0r9e2mpv8mcfpr4c92e0n9h5cmod.apps.googleusercontent.com',
    serverClientId: '1054468511277-uq2b0r9e2mpv8mcfpr4c92e0n9h5cmod.apps.googleusercontent.com',
  );

  Future<SocialAuthResult?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      return SocialAuthResult(
        user: _auth.currentUser,
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
        provider: 'google',
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<SocialAuthResult?> signInWithGitHub() async {
    try {
      final githubProvider = GithubAuthProvider();
      final result = await _auth.signInWithProvider(githubProvider);

      final accessToken = result.credential?.accessToken;

      return SocialAuthResult(
        user: result.user,
        accessToken: accessToken,
        idToken: null,
        provider: 'github',
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
