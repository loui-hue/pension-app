import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../themes/app_theme.dart';

/// Mensaje que devolvió el API (en español) o, si no hay, uno por defecto.
/// Para errores de validación (422) el API pone en "message" el primer error.
String mensajeDeError(Object e, String porDefecto) {
  if (e is DioException) {
    final datos = e.response?.data;
    if (datos is Map && datos['message'] is String) return datos['message'];
    if (e.response == null) return 'Sin conexión con el servidor de la pensión';
  }
  return porDefecto;
}

void avisar(BuildContext context, String texto, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(texto), backgroundColor: error ? Colors.red.shade700 : null),
  );
}

/// Pide confirmación antes de una acción que no se puede deshacer (eliminar).
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String texto,
  String accion = 'Eliminar',
}) async {
  final si = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(titulo, style: const TextStyle(color: AppTheme.accent)),
      content: Text(texto, style: const TextStyle(color: AppTheme.textLight)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(accion),
        ),
      ],
    ),
  );
  return si == true;
}

/// Encabezado y margen comunes de los formularios en hoja inferior.
class HojaFormulario extends StatelessWidget {
  final String titulo;
  final List<Widget> campos;
  final GlobalKey<FormState> form;
  const HojaFormulario({super.key, required this.titulo, required this.campos, required this.form});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(titulo, style: const TextStyle(color: AppTheme.accent, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...campos,
            ],
          ),
        ),
      ),
    );
  }
}
