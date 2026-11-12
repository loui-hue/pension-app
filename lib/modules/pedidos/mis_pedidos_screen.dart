import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/cache_service.dart';
import '../../core/themes/app_theme.dart';
import '../../core/widgets/transicion_carga.dart';
import '../../core/widgets/aviso_sin_conexion.dart';

class MisPedidosScreen extends StatefulWidget {
  const MisPedidosScreen({super.key});

  @override
  State<MisPedidosScreen> createState() => _MisPedidosScreenState();
}

class _MisPedidosScreenState extends State<MisPedidosScreen> {
  final _apiService = ApiService();
  List _pedidos = [];
  bool _isLoading = true;
  DateTime? _desdeCache;

  @override
  void initState() {
    super.initState();
    _cargarPedidos();
  }

  Future<void> _cargarPedidos() async {
    const storage = FlutterSecureStorage();
    final usuarioId = int.tryParse(await storage.read(key: AppConstants.userIdKey) ?? '');
    final claveCache = CacheService.clave(usuarioId, 'mis_pedidos');

    // Primero el historial guardado, al instante; luego se actualiza con el servidor.
    final guardado = await CacheService.leer(claveCache);
    if (_isLoading && guardado != null && mounted) {
      setState(() {
        _pedidos = guardado.datos as List;
        _isLoading = false;
      });
    }

    await _apiService.init();
    try {
      final res = await _apiService.get('/orders/my-orders');
      await CacheService.guardar(claveCache, res.data);
      if (!mounted) return;
      setState(() {
        _pedidos = res.data;
        _desdeCache = null;
        _isLoading = false;
      });
    } catch (e) {
      // Sin conexión: el historial guardado la última vez.
      final cache = await CacheService.leer(claveCache);
      if (!mounted) return;
      setState(() {
        if (cache != null) {
          _pedidos = cache.datos as List;
          _desdeCache = cache.guardado;
        }
        _isLoading = false;
      });
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
      case 'listo': return '¡Listo!';
      case 'entregado': return 'Entregado';
      case 'pagado': return 'Pagado';
      case 'cancelado': return 'Cancelado';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Pedidos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarPedidos,
          )
        ],
      ),
      body: Column(
        children: [
          if (_desdeCache != null)
            AvisoSinConexion(desde: _desdeCache!, onReintentar: _cargarPedidos),
          Expanded(
            child: _isLoading
          ? const Cargando()
          : _pedidos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long, size: 80, color: AppTheme.primary),
                      const SizedBox(height: 16),
                      const Text(
                        'No tienes pedidos aún',
                        style: TextStyle(color: AppTheme.textLight, fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/crear-pedido'),
                        child: const Text('Hacer un pedido'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _pedidos.length,
                  itemBuilder: (context, index) {
                    final pedido = _pedidos[index];
                    final status = pedido['status'];
                    final items = pedido['items'] as List? ?? [];
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
                            const SizedBox(height: 4),
                            ...items.map((item) => Text(
                              '• ${item['product']?['name']} x${item['quantity']} — Bs. ${item['subtotal']}',
                              style: TextStyle(
                                color: AppTheme.textLight.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            )),
                            const SizedBox(height: 8),
                            Text(
                              'Total: Bs. ${pedido['total']}',
                              style: const TextStyle(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
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