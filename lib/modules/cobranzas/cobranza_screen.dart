import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/themes/app_theme.dart';
import 'qr_imagen.dart';

class CobranzaScreen extends StatefulWidget {
  const CobranzaScreen({super.key});

  @override
  State<CobranzaScreen> createState() => _CobranzaScreenState();
}

class _CobranzaScreenState extends State<CobranzaScreen> {
  final _apiService = ApiService();
  List _pagos = [];
  List _metodos = [];
  List _porCobrar = [];
  List _pendientes = [];
  bool _isLoading = true;

  // La cuenta regresiva parte de seconds_left (calculado por el servidor)
  // y avanza con el reloj local desde el momento de la carga.
  DateTime _cargadoEn = DateTime.now();
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _pendientes.isNotEmpty) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    await _apiService.init();
    try {
      final resPagos = await _apiService.get('/payments');
      final resMetodos = await _apiService.get('/payment-methods');
      final resPedidos = await _apiService.get('/orders');
      final pagos = resPagos.data as List;
      final pendientes = pagos.where((p) => p['status'] == 'pendiente').toList();
      final conPagoPendiente = pendientes.map((p) => p['order_id']).toSet();
      setState(() {
        _pagos = pagos.where((p) => p['status'] != 'pendiente').toList();
        _pendientes = pendientes;
        _metodos = resMetodos.data;
        // Pedidos activos sin pagar ni cancelar, que no estén esperando confirmación.
        _porCobrar = (resPedidos.data as List)
            .where((o) =>
                o['status'] != 'pagado' &&
                o['status'] != 'cancelado' &&
                !conPagoPendiente.contains(o['id']))
            .toList();
        _cargadoEn = DateTime.now();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  int _segundosRestantes(Map pago) {
    final base = (pago['seconds_left'] as num?)?.toInt() ?? 0;
    final restantes = base - DateTime.now().difference(_cargadoEn).inSeconds;
    return restantes < 0 ? 0 : restantes;
  }

  String _formatoTiempo(int segundos) =>
      '${(segundos ~/ 60).toString().padLeft(2, '0')}:${(segundos % 60).toString().padLeft(2, '0')}';

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

  Future<void> _mostrarQr(Map pago, Map pedido) async {
    final metodo = _metodos.firstWhere(
      (m) => m['id'] == pago['payment_method_id'],
      orElse: () => pago['payment_method'] ?? {},
    );
    final confirmarAhora = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _PantallaQr(
          metodo: metodo,
          monto: pago['amount'].toString(),
          pedidoId: pedido['id'],
          comensal: pedido['user']?['name'],
          segundos: _segundosRestantes(pago),
        ),
      ),
    );
    if (confirmarAhora == true) await _confirmar(pago);
  }

  Future<void> _confirmar(Map pago) async {
    final referencia = TextEditingController(text: pago['reference'] ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Confirmar pago', style: TextStyle(color: AppTheme.accent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verifica en la app del banco de la pensión que llegó el depósito de Bs. ${pago['amount']}.',
              style: const TextStyle(color: AppTheme.textLight),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: referencia,
              style: const TextStyle(color: AppTheme.textLight),
              decoration: const InputDecoration(
                labelText: 'N° de operación (opcional)',
                labelStyle: TextStyle(color: AppTheme.accent),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, llegó')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _apiService.patch('/payments/${pago['id']}/confirm', {
        if (referencia.text.trim().isNotEmpty) 'reference': referencia.text.trim(),
      });
      await _cargarDatos();
      if (!mounted) return;
      final monto = double.tryParse(pago['amount'].toString()) ?? 0;
      final xp = monto.round() < 5 ? 5 : monto.round();
      _mostrarMensaje(
          'Pago confirmado. ${pago['order']?['user']?['name'] ?? 'El comensal'} ganó $xp XP');
    } catch (e) {
      if (mounted) _mostrarMensaje(_mensajeDeError(e, 'No se pudo confirmar el pago'), error: true);
    }
  }

  Future<void> _rechazar(Map pago) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Rechazar pago', style: TextStyle(color: AppTheme.accent)),
        content: const Text(
          'El depósito no llegó. El pedido vuelve a "Por cobrar" para cobrarlo de otra forma.',
          style: TextStyle(color: AppTheme.textLight),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _apiService.patch('/payments/${pago['id']}/reject', {});
      await _cargarDatos();
      if (mounted) _mostrarMensaje('Pago rechazado. El pedido volvió a "Por cobrar"');
    } catch (e) {
      if (mounted) _mostrarMensaje(_mensajeDeError(e, 'No se pudo rechazar el pago'), error: true);
    }
  }

  Future<void> _registrarPago(Map pedido, int metodoPagoId, String? referencia) async {
    final monto = double.tryParse(pedido['total'].toString()) ?? 0;
    try {
      final res = await _apiService.post('/payments', {
        'order_id': pedido['id'],
        'payment_method_id': metodoPagoId,
        'amount': monto,
        if (referencia != null && referencia.isNotEmpty) 'reference': referencia,
      });
      await _cargarDatos();
      if (!mounted) return;

      // QR / transferencia: el pago queda pendiente; se muestra el QR al comensal.
      if (res.data['status'] == 'pendiente') {
        final pago = _pendientes.firstWhere((p) => p['id'] == res.data['id'], orElse: () => res.data);
        await _mostrarQr(pago, pedido);
        return;
      }

      // Mismo cálculo que PaymentController: 1 XP por boliviano, mínimo 5.
      final xp = monto.round() < 5 ? 5 : monto.round();
      _mostrarMensaje('Pago registrado. ${pedido['user']?['name'] ?? 'El comensal'} ganó $xp XP');
    } catch (e) {
      if (mounted) _mostrarMensaje(_mensajeDeError(e, 'Error al registrar pago'), error: true);
    }
  }

  Future<void> _abrirCobro(Map pedido) async {
    int? metodoId = _metodos.isNotEmpty ? _metodos.first['id'] : null;
    final referenciaController = TextEditingController();

    final confirmado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final metodo = _metodos.firstWhere((m) => m['id'] == metodoId, orElse: () => null);
          final requiereConfirmacion = metodo?['requires_confirmation'] == true;
          // Tarjeta: n° de voucher. QR/transferencia: el n° de operación se anota al confirmar.
          final pideReferencia = metodo != null &&
              !requiereConfirmacion &&
              metodo['name'].toString().toLowerCase() != 'efectivo';
          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cobrar pedido #${pedido['id']}',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${pedido['user']?['name'] ?? 'Sin comensal'} · Mesa ${pedido['table']?['number'] ?? '-'}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Text(
                  'Total: Bs. ${pedido['total']}',
                  style: const TextStyle(
                    color: AppTheme.textLight,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Método de pago', style: TextStyle(color: AppTheme.accent)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _metodos.map<Widget>((m) {
                    return ChoiceChip(
                      avatar: Icon(_getMetodoIcon(m['name']), size: 18),
                      label: Text(m['name']),
                      selected: metodoId == m['id'],
                      selectedColor: AppTheme.primary,
                      onSelected: (_) => setModalState(() => metodoId = m['id']),
                    );
                  }).toList(),
                ),
                if (pideReferencia) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: referenciaController,
                    style: const TextStyle(color: AppTheme.textLight),
                    decoration: InputDecoration(
                      labelText: 'Referencia / N° de comprobante (opcional)',
                      labelStyle: const TextStyle(color: AppTheme.accent),
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: metodoId == null ? null : () => Navigator.pop(context, true),
                    icon: const Icon(Icons.check),
                    label: Text(requiereConfirmacion
                        ? 'Mostrar ${metodo['name']} al comensal'
                        : 'Confirmar cobro — Bs. ${pedido['total']}'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (confirmado == true && metodoId != null) {
      await _registrarPago(pedido, metodoId!, referenciaController.text.trim());
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completado': return Colors.green;
      case 'pendiente': return Colors.orange;
      case 'rechazado': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color _getPedidoColor(String status) {
    switch (status) {
      case 'pendiente': return Colors.orange;
      case 'en_preparacion': return Colors.blue;
      case 'listo': return Colors.teal;
      case 'entregado': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _getMetodoIcon(String nombre) {
    switch (nombre.toLowerCase()) {
      case 'efectivo': return Icons.money;
      case 'qr': return Icons.qr_code;
      case 'transferencia': return Icons.account_balance;
      default: return Icons.payment;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cobranza'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _cargarDatos,
            )
          ],
          bottom: TabBar(
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.accent,
            unselectedLabelColor: Colors.white70,
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            tabs: [
              Tab(text: 'Por cobrar (${_porCobrar.length})'),
              Tab(text: 'Por confirmar (${_pendientes.length})'),
              const Tab(text: 'Historial'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : TabBarView(
                children: [
                  _buildPorCobrar(),
                  _buildPorConfirmar(),
                  _buildHistorial(),
                ],
              ),
      ),
    );
  }

  Widget _buildPorConfirmar() {
    if (_pendientes.isEmpty) {
      return const Center(
        child: Text('No hay pagos por confirmar', style: TextStyle(color: AppTheme.textLight)),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _pendientes.length,
        itemBuilder: (context, index) {
          final pago = _pendientes[index];
          final pedido = pago['order'] ?? {};
          final segundos = _segundosRestantes(pago);
          final vencido = segundos == 0;
          final color = vencido ? Colors.red : (segundos < 120 ? Colors.orange : Colors.blue);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_getMetodoIcon(pago['payment_method']?['name'] ?? ''),
                        color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pedido #${pago['order_id']} · ${pago['payment_method']?['name'] ?? ''}',
                        style: const TextStyle(
                          color: AppTheme.textLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(vencido ? Icons.warning_amber : Icons.timer,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            vencido ? 'Vencido — verificar' : _formatoTiempo(segundos),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Comensal: ${pedido['user']?['name'] ?? '-'} · Mesa ${pedido['table']?['number'] ?? '-'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bs. ${pago['amount']}',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _confirmar(pago),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Confirmar'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _rechazar(pago),
                      icon: const Icon(Icons.cancel, color: Colors.redAccent),
                      label: const Text('Rechazar', style: TextStyle(color: Colors.redAccent)),
                    ),
                    TextButton.icon(
                      onPressed: () => _mostrarQr(pago, pedido),
                      icon: const Icon(Icons.qr_code, color: AppTheme.accent),
                      label: const Text('Ver QR', style: TextStyle(color: AppTheme.accent)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPorCobrar() {
    if (_porCobrar.isEmpty) {
      return const Center(
        child: Text('No hay pedidos por cobrar', style: TextStyle(color: AppTheme.textLight)),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _porCobrar.length,
        itemBuilder: (context, index) {
          final pedido = _porCobrar[index];
          final status = pedido['status'].toString();
          final items = pedido['items'] as List? ?? [];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pedido #${pedido['id']} · Mesa ${pedido['table']?['number'] ?? '-'}',
                        style: const TextStyle(
                          color: AppTheme.textLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getPedidoColor(status),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.replaceAll('_', ' '),
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Comensal: ${pedido['user']?['name'] ?? '-'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                ...items.map((item) => Text(
                      '• ${item['product']?['name']} x${item['quantity']}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    )),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Bs. ${pedido['total']}',
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _abrirCobro(pedido),
                      icon: const Icon(Icons.point_of_sale),
                      label: const Text('Cobrar'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistorial() {
    if (_pagos.isEmpty) {
      return const Center(
        child: Text('No hay pagos registrados', style: TextStyle(color: AppTheme.textLight)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _pagos.length,
      itemBuilder: (context, index) {
        final pago = _pagos[index];
        final status = pago['status'];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getStatusColor(status).withOpacity(0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  _getMetodoIcon(pago['payment_method']?['name'] ?? ''),
                  color: AppTheme.primary,
                  size: 40,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedido #${pago['order_id']}',
                        style: const TextStyle(
                          color: AppTheme.textLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        pago['payment_method']?['name'] ?? 'N/A',
                        style: TextStyle(
                          color: AppTheme.textLight.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Bs. ${pago['amount']}',
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Pantalla que caja le muestra al comensal: QR fijo (o datos de la cuenta),
/// monto exacto y el tiempo que queda para verificar el depósito.
class _PantallaQr extends StatefulWidget {
  final Map metodo;
  final String monto;
  final int pedidoId;
  final String? comensal;
  final int segundos;

  const _PantallaQr({
    required this.metodo,
    required this.monto,
    required this.pedidoId,
    required this.comensal,
    required this.segundos,
  });

  @override
  State<_PantallaQr> createState() => _PantallaQrState();
}

class _PantallaQrState extends State<_PantallaQr> {
  late int _segundos = widget.segundos;
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_segundos > 0) setState(() => _segundos--);
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Widget _dato(String etiqueta, dynamic valor) {
    if (valor == null || valor.toString().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '$etiqueta: ', style: const TextStyle(color: Colors.white70)),
          TextSpan(
            text: valor.toString(),
            style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold),
          ),
        ]),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metodo = widget.metodo;
    final tieneQr = metodo['has_qr'] == true;
    final vencido = _segundos == 0;
    final minutos = (_segundos ~/ 60).toString().padLeft(2, '0');
    final segs = (_segundos % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(title: Text('Pago por ${metodo['name'] ?? 'QR'}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Pedido #${widget.pedidoId}${widget.comensal != null ? ' · ${widget.comensal}' : ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Bs. ${widget.monto}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            if (tieneQr)
              Center(child: QrImagen(metodoId: metodo['id'], size: 280))
            else
              const Text(
                'No hay QR cargado. El administrador puede subirlo en "Métodos de pago".',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.orangeAccent),
              ),
            const SizedBox(height: 20),
            _dato('Banco', metodo['bank_name']),
            _dato('Cuenta', metodo['account_number']),
            _dato('Titular', metodo['account_holder']),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(vencido ? Icons.warning_amber : Icons.timer,
                    color: vencido ? Colors.red : AppTheme.accent),
                const SizedBox(width: 8),
                Text(
                  vencido ? 'Tiempo vencido: verifica el depósito' : 'Tiempo para verificar: $minutos:$segs',
                  style: TextStyle(
                    color: vencido ? Colors.red : AppTheme.textLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.check_circle),
              label: const Text('Ya llegó el depósito — Confirmar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Confirmar después (queda en "Por confirmar")',
                  style: TextStyle(color: AppTheme.accent)),
            ),
          ],
        ),
      ),
    );
  }
}
