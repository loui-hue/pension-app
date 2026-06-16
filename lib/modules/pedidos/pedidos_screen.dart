import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/themes/app_theme.dart';

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  final _apiService = ApiService();
  List _pedidos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarPedidos();
  }

  Future<void> _cargarPedidos() async {
    await _apiService.init();
    try {
      final res = await _apiService.get('/orders');
      setState(() {
        _pedidos = res.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pendiente': return Colors.orange;
      case 'en_preparacion': return Colors.blue;
      case 'listo': return Colors.green;
      case 'entregado': return Colors.teal;
      case 'pagado': return Colors.purple;
      case 'cancelado': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pendiente': return 'Pendiente';
      case 'en_preparacion': return 'En preparación';
      case 'listo': return 'Listo';
      case 'entregado': return 'Entregado';
      case 'pagado': return 'Pagado';
      case 'cancelado': return 'Cancelado';
      default: return status;
    }
  }

  Future<void> _actualizarEstado(int id, String nuevoEstado) async {
    try {
      await _apiService.patch('/orders/$id/status', {'status': nuevoEstado});
      _cargarPedidos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al actualizar'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarPedidos,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _pedidos.isEmpty
              ? const Center(
                  child: Text('No hay pedidos', style: TextStyle(color: AppTheme.textLight)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _pedidos.length,
                  itemBuilder: (context, index) {
                    final pedido = _pedidos[index];
                    final status = pedido['status'];
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Pedido #${pedido['id']}',
                                  style: const TextStyle(
                                    color: AppTheme.textLight,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _getStatusLabel(status),
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Mesa: ${pedido['table']?['number'] ?? 'N/A'}',
                              style: TextStyle(color: AppTheme.textLight.withOpacity(0.7)),
                            ),
                            Text(
                              'Total: Bs. ${pedido['total']}',
                              style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
                            ),
                            if (pedido['notes'] != null)
                              Text(
                                'Nota: ${pedido['notes']}',
                                style: TextStyle(color: AppTheme.textLight.withOpacity(0.7), fontSize: 12),
                              ),
                            const SizedBox(height: 12),
                            // Botones de estado
                            if (status == 'pendiente')
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _actualizarEstado(pedido['id'], 'en_preparacion'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                  child: const Text('Iniciar preparación'),
                                ),
                              ),
                            if (status == 'en_preparacion')
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _actualizarEstado(pedido['id'], 'listo'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  child: const Text('Marcar como listo'),
                                ),
                              ),
                            if (status == 'listo')
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _actualizarEstado(pedido['id'], 'entregado'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                                  child: const Text('Marcar como entregado'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}