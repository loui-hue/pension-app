import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/themes/app_theme.dart';

class CobranzaScreen extends StatefulWidget {
  const CobranzaScreen({super.key});

  @override
  State<CobranzaScreen> createState() => _CobranzaScreenState();
}

class _CobranzaScreenState extends State<CobranzaScreen> {
  final _apiService = ApiService();
  List _pagos = [];
  List _metodos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    await _apiService.init();
    try {
      final resPagos = await _apiService.get('/payments');
      final resMetodos = await _apiService.get('/payment-methods');
      setState(() {
        _pagos = resPagos.data;
        _metodos = resMetodos.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _registrarPago(int orderId, int metodoPagoId, double monto) async {
    try {
      await _apiService.post('/payments', {
        'order_id': orderId,
        'payment_method_id': metodoPagoId,
        'amount': monto,
      });
      _cargarDatos();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago registrado exitosamente'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al registrar pago'), backgroundColor: Colors.red),
      );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cobranza'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                // Métodos de pago
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppTheme.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Métodos de pago disponibles',
                        style: TextStyle(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: _metodos.map((m) => Column(
                          children: [
                            Icon(_getMetodoIcon(m['name']), color: AppTheme.primary, size: 32),
                            Text(m['name'], style: const TextStyle(color: AppTheme.textLight, fontSize: 12)),
                          ],
                        )).toList(),
                      ),
                    ],
                  ),
                ),
                // Lista de pagos
                Expanded(
                  child: _pagos.isEmpty
                      ? const Center(
                          child: Text('No hay pagos registrados',
                              style: TextStyle(color: AppTheme.textLight)),
                        )
                      : ListView.builder(
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
                        ),
                ),
              ],
            ),
    );
  }
}