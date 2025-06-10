import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final supabase = Supabase.instance.client;
  
  // Configuración con tu Client ID específico
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // IMPORTANTE: Usa el mismo Client ID que pusiste en strings.xml
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
      print('🔍 Iniciando Google Sign-In (sin Firebase)...');
      
      await _googleSignIn.signOut();
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('❌ Usuario canceló el login');
        return;
      }
      
      print('✅ Usuario Google: ${googleUser.email}');
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.idToken == null || googleAuth.accessToken == null) {
        throw Exception('No se pudieron obtener los tokens de Google');
      }
      
      print('🔑 Tokens obtenidos, autenticando con Supabase...');
      
      final AuthResponse response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken!,
      );
      
      if (response.user == null) {
        throw Exception('Error al autenticar con Supabase');
      }
      
      print('🎉 Login exitoso: ${response.user!.email}');
      
    } catch (e) {
      print('💥 Error: $e');
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