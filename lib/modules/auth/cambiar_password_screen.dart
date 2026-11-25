import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/themes/app_theme.dart';
import '../../core/utils/contrasena.dart';

/// Primer ingreso de un comensal registrado por el mesero: entró con su celular
/// como contraseña temporal y debe crear una propia antes de usar la app.
class CambiarPasswordScreen extends StatefulWidget {
  const CambiarPasswordScreen({super.key});

  @override
  State<CambiarPasswordScreen> createState() => _CambiarPasswordScreenState();
}

class _CambiarPasswordScreenState extends State<CambiarPasswordScreen> {
  final _apiService = ApiService();
  final _nueva = TextEditingController();
  final _confirmar = TextEditingController();
  bool _ocultar = true;
  bool _guardando = false;
  String? _error;

  Future<void> _guardar(String role, String actual) async {
    final problema = problemaDeContrasena(_nueva.text);
    if (problema != null) {
      setState(() => _error = problema);
      return;
    }
    if (_nueva.text != _confirmar.text) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await _apiService.post('/me/password', {
        'current_password': actual,
        'password': _nueva.text,
        'password_confirmation': _confirmar.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Listo! Ya tienes tu propia contraseña'), backgroundColor: Colors.green),
      );
      Navigator.pushReplacementNamed(context, '/dashboard', arguments: role);
    } on DioException catch (e) {
      final data = e.response?.data;
      final errores = data is Map ? data['errors'] : null;
      setState(() {
        _guardando = false;
        _error = errores is Map && errores.isNotEmpty
            ? (errores.values.first as List).first.toString()
            : (data is Map ? data['message'] : null) ?? 'No se pudo guardar la contraseña';
      });
    }
  }

  InputDecoration _decoracion(String etiqueta) => InputDecoration(
        labelText: etiqueta,
        labelStyle: const TextStyle(color: AppTheme.accent),
        prefixIcon: const Icon(Icons.lock, color: AppTheme.primary),
        suffixIcon: IconButton(
          icon: Icon(_ocultar ? Icons.visibility : Icons.visibility_off, color: AppTheme.accent),
          onPressed: () => setState(() => _ocultar = !_ocultar),
        ),
        filled: true,
        fillColor: Colors.white10,
        border: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final role = args['role'] as String;
    final actual = args['actual'] as String;

    return Scaffold(
      appBar: AppBar(title: const Text('Crea tu contraseña'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.lock_reset, size: 64, color: AppTheme.primary),
            const SizedBox(height: 12),
            const Text(
              'Entraste con una contraseña temporal (tu número de celular). '
              'Crea una contraseña propia para proteger tu cuenta y tus puntos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textLight),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nueva,
              obscureText: _ocultar,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(color: AppTheme.textLight),
              decoration: _decoracion('Nueva contraseña'),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: Text('Al menos $minimoContrasena caracteres, con letras y números (por ejemplo: pension24).',
                  style: TextStyle(color: Colors.white60, fontSize: 12)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmar,
              obscureText: _ocultar,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(color: AppTheme.textLight),
              decoration: _decoracion('Repite la contraseña'),
              onSubmitted: (_) => _guardando ? null : _guardar(role, actual),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _guardando ? null : () => _guardar(role, actual),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _guardando
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar y continuar', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
