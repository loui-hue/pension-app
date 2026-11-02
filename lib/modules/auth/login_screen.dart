import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/themes/app_theme.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _apiService.init();
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Por favor completa todos los campos');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _apiService.post('/login', {
        'email': _emailController.text.trim().toLowerCase(),
        'password': _passwordController.text,
      });

      final token = response.data['token'];
      final roles = response.data['user']['roles'] as List;
      final role = roles.first;

      await _apiService.setToken(token);
      const storage = FlutterSecureStorage();
      await storage.write(key: AppConstants.userKey, value: role);

      if (!mounted) return;
      // Comensal registrado por el mesero: primero crea su propia contraseña.
      if (response.data['user']['must_change_password'] == true) {
        Navigator.pushReplacementNamed(context, '/cambiar-password', arguments: {
          'role': role,
          'actual': _passwordController.text,
        });
      } else {
        Navigator.pushReplacementNamed(context, '/dashboard', arguments: role);
      }
    } on DioException catch (e) {
      _showError(e.response?.data['message'] ?? 'Error de conexión');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Recuperación asistida: sin Internet ni SMS, el personal la restablece en persona.
  void _olvideMiPassword() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('¿Olvidaste tu contraseña?', style: TextStyle(color: AppTheme.accent)),
        content: const Text(
          '1. Pídele al mesero o al administrador de la pensión que restablezca tu contraseña.\n\n'
          '2. Luego entra con tu número de celular como usuario y como contraseña.\n\n'
          '3. La app te pedirá crear una contraseña nueva.',
          style: TextStyle(color: AppTheme.textLight),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido')),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3E2723), Color(0xFF5D4037)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.restaurant, size: 80, color: AppTheme.primary),
                  const SizedBox(height: 16),
                  const Text(
                    'Pensión Doña Roberta',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Text(
                    'Sistema de Gestión',
                    style: TextStyle(fontSize: 14, color: AppTheme.accent),
                  ),
                  const SizedBox(height: 48),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: const TextStyle(color: AppTheme.textLight),
                    decoration: InputDecoration(
                      labelText: 'Correo o celular',
                      labelStyle: const TextStyle(color: AppTheme.accent),
                      prefixIcon: const Icon(Icons.person, color: AppTheme.primary),
                      filled: true,
                      fillColor: Colors.white10,
                      border: UnderlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: const TextStyle(color: AppTheme.textLight),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      labelStyle: const TextStyle(color: AppTheme.accent),
                      prefixIcon: const Icon(Icons.lock, color: AppTheme.primary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          color: AppTheme.primary,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      filled: true,
                      fillColor: Colors.white10,
                      border: UnderlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Ingresar', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _olvideMiPassword,
                    child: const Text('¿Olvidaste tu contraseña?',
                        style: TextStyle(color: AppTheme.accent)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}