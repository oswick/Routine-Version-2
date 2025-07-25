import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final supabase = Supabase.instance.client;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '641741918490-01dhk8snfaoent4j60jnaph1ev5v4726.apps.googleusercontent.com',
    scopes: [
      'email',
      'profile',
      'openid',
    ],
  );

  User? get currentUser => supabase.auth.currentUser;
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  Future<void> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (googleAuth.idToken == null || googleAuth.accessToken == null) {
        throw Exception('No se pudieron obtener los tokens de Google');
      }

      final AuthResponse response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken!,
      );

      if (response.user == null) {
        throw Exception('Error al autenticar con Supabase');
      }
    } catch (e) {
      await _googleSignIn.signOut();
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await Future.wait([
        _googleSignIn.signOut(),
        supabase.auth.signOut(),
      ]);
    } catch (e) {
      throw Exception('Error al cerrar sesión: $e');
    }
  }

  bool get isAuthenticated => currentUser != null;
  String? get currentUserId => currentUser?.id;
  String? get currentUserEmail => currentUser?.email;
  Session? get currentSession => supabase.auth.currentSession;
}
