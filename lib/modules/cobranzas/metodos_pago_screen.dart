import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/api_service.dart';
import '../../core/themes/app_theme.dart';
import 'qr_imagen.dart';

/// Configuración (solo administrador) de los datos de cobro de la pensión:
/// imagen del QR fijo del banco y datos de la cuenta para transferencias.
class MetodosPagoScreen extends StatefulWidget {
  const MetodosPagoScreen({super.key});

  @override
  State<MetodosPagoScreen> createState() => _MetodosPagoScreenState();
}

class _MetodosPagoScreenState extends State<MetodosPagoScreen> {
  final _apiService = ApiService();
  List _metodos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    await _apiService.init();
    try {
      final res = await _apiService.get('/payment-methods');
      setState(() {
        _metodos = (res.data as List).where((m) => m['requires_confirmation'] == true).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _mostrarMensaje(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: error ? Colors.red : Colors.green),
    );
  }

  String _mensajeDeError(Object e, String porDefecto) {
    return e is DioException && e.response?.data is Map
        ? (e.response!.data['message'] ?? porDefecto)
        : porDefecto;
  }

  Future<void> _subirQr(Map metodo) async {
    final imagen = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 90,
    );
    if (imagen == null) return;

    try {
      await _apiService.postMultipart(
        '/payment-methods/${metodo['id']}',
        FormData.fromMap({
          'qr_image': await MultipartFile.fromFile(imagen.path, filename: imagen.name),
        }),
      );
      QrImagen.invalidar(metodo['id']);
      await _cargar();
      if (mounted) _mostrarMensaje('QR actualizado');
    } catch (e) {
      if (mounted) _mostrarMensaje(_mensajeDeError(e, 'No se pudo subir el QR'), error: true);
    }
  }

  Future<void> _editarCuenta(Map metodo) async {
    final banco = TextEditingController(text: metodo['bank_name'] ?? '');
    final cuenta = TextEditingController(text: metodo['account_number'] ?? '');
    final titular = TextEditingController(text: metodo['account_holder'] ?? '');

    final guardar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Datos de cuenta — ${metodo['name']}',
            style: const TextStyle(color: AppTheme.accent, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _campo(banco, 'Banco'),
            const SizedBox(height: 10),
            _campo(cuenta, 'N° de cuenta', teclado: TextInputType.number),
            const SizedBox(height: 10),
            _campo(titular, 'Titular'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (guardar != true) return;

    try {
      await _apiService.postMultipart(
        '/payment-methods/${metodo['id']}',
        FormData.fromMap({
          'bank_name': banco.text.trim(),
          'account_number': cuenta.text.trim(),
          'account_holder': titular.text.trim(),
        }),
      );
      await _cargar();
      if (mounted) _mostrarMensaje('Datos guardados');
    } catch (e) {
      if (mounted) _mostrarMensaje(_mensajeDeError(e, 'No se pudieron guardar los datos'), error: true);
    }
  }

  Widget _campo(TextEditingController c, String etiqueta, {TextInputType? teclado}) {
    return TextField(
      controller: c,
      keyboardType: teclado,
      style: const TextStyle(color: AppTheme.textLight),
      decoration: InputDecoration(
        labelText: etiqueta,
        labelStyle: const TextStyle(color: AppTheme.accent),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Métodos de pago')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Estos datos se muestran al comensal cuando paga por QR o transferencia. '
                  'Caja confirma el pago al ver el depósito en la cuenta de la pensión.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                ..._metodos.map(_buildMetodo),
              ],
            ),
    );
  }

  Widget _buildMetodo(dynamic metodo) {
    final tieneQr = metodo['has_qr'] == true;
    final datosCuenta = [metodo['bank_name'], metodo['account_number'], metodo['account_holder']]
        .where((d) => d != null && d.toString().isNotEmpty)
        .join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metodo['name'],
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            datosCuenta.isEmpty ? 'Sin datos de cuenta' : datosCuenta,
            style: const TextStyle(color: AppTheme.textLight),
          ),
          const SizedBox(height: 12),
          if (tieneQr) Center(child: QrImagen(metodoId: metodo['id'], size: 200)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _subirQr(metodo),
                icon: const Icon(Icons.qr_code),
                label: Text(tieneQr ? 'Cambiar QR' : 'Cargar QR'),
              ),
              OutlinedButton.icon(
                onPressed: () => _editarCuenta(metodo),
                icon: const Icon(Icons.account_balance, color: AppTheme.accent),
                label: const Text('Datos de cuenta', style: TextStyle(color: AppTheme.accent)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
