import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  bool _isConnected = false;

  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isConnected => _isConnected;

  Future<void> initialize() async {
    // Verificar estado inicial
    await _checkConnection();

    // Escuchar cambios
    _connectivity.onConnectivityChanged.listen((_) => _checkConnection());
  }

  Future<void> _checkConnection() async {
    bool previousStatus = _isConnected;
    
    try {
      // 1. Verificar tipo de conexión
      final result = await _connectivity.checkConnectivity();
      
      // 2. Verificar realmente si hay internet
      if (result != ConnectivityResult.none) {
        // Intentar un ping a un servidor confiable
        final response = await InternetAddress.lookup('google.com');
        _isConnected = response.isNotEmpty && response[0].rawAddress.isNotEmpty;
      } else {
        _isConnected = false;
      }
    } on SocketException catch (_) {
      _isConnected = false;
    } catch (e) {
      _isConnected = false;
    }

    // Solo notificar si el estado cambió
    if (_isConnected != previousStatus) {
      _connectionController.add(_isConnected);
      print('📡 Estado conexión: ${_isConnected ? 'ONLINE' : 'OFFLINE'}');
    }
  }

  Future<bool> testInternetConnection() async {
    try {
      await _checkConnection();
      return _isConnected;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _connectionController.close();
  }
}