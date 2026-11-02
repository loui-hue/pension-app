import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/services/api_service.dart';
import '../../core/themes/app_theme.dart';
import '../../core/constants/app_constants.dart';

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen>
    with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  List _pedidos = [];
  bool _isLoading = true;
  late TabController _tabController;
  String _role = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is String) {
      _role = args;
    }
  }

  List _filtrarPorEstado(List estados) {
    return _pedidos.where((p) => estados.contains(p['status'])).toList();
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

  Future<void> _actualizarEstado(int id, String nuevoEstado) async {
    try {
      await _apiService.patch('/orders/$id/status', {'status': nuevoEstado});
      _cargarDatos();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pedido: ${_getStatusLabel(nuevoEstado)}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al actualizar'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmarCancelacion(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          '¿Cancelar pedido?',
          style: TextStyle(color: AppTheme.textLight),
        ),
        content: const Text(
          'El pedido será cancelado y eliminado de cocina.',
          style: TextStyle(color: AppTheme.textLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(color: AppTheme.accent)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _actualizarEstado(id, 'cancelado');
    }
  }

  Widget _buildBotones(Map pedido) {
    final status = pedido['status'];
    final id = pedido['id'];

    // COCINA - solo puede marcar como listo
    if (_role == AppConstants.roleCocina) {
      if (status == 'en_preparacion') {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _actualizarEstado(id, 'listo'),
            icon: const Icon(Icons.check_circle, size: 16),
            label: const Text('Marcar como Listo'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    // MESERO y ADMIN
    if (status == 'pendiente') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _actualizarEstado(id, 'en_preparacion'),
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Enviar a Cocina'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _confirmarCancelacion(id),
            icon: const Icon(Icons.cancel, size: 16),
            label: const Text('Cancelar'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      );
    }

    if (status == 'en_preparacion') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.soup_kitchen, size: 16),
              label: const Text('En cocina...'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.withOpacity(0.4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _confirmarCancelacion(id),
            icon: const Icon(Icons.cancel, size: 16),
            label: const Text('Cancelar'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      );
    }

    if (status == 'listo') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _actualizarEstado(id, 'entregado'),
          icon: const Icon(Icons.delivery_dining, size: 16),
          label: const Text('Recoger y Entregar'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPedidoCard(Map pedido) {
    final status = pedido['status'];
    final items = pedido['items'] as List? ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(status).withOpacity(0.6),
          width: 2,
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
            Row(
              children: [
                const Icon(Icons.table_restaurant, color: AppTheme.accent, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Mesa ${pedido['table']?['number'] ?? 'N/A'}',
                  style: const TextStyle(color: AppTheme.accent),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.attach_money, color: AppTheme.accent, size: 16),
                Text(
                  'Bs. ${pedido['total']}',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '• ${item['product']?['name']} x${item['quantity']}',
                style: TextStyle(
                  color: AppTheme.textLight.withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
            )),
            if (pedido['notes'] != null &&
                pedido['notes'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Nota: ${pedido['notes']}',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _buildBotones(pedido),
          ],
        ),
      ),
    );
  }

  Widget _buildLista(List estados) {
    final lista = _filtrarPorEstado(estados);
    if (lista.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: AppTheme.primary),
            SizedBox(height: 16),
            Text(
              'No hay pedidos aquí',
              style: TextStyle(color: AppTheme.textLight, fontSize: 16),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: lista.length,
        itemBuilder: (context, index) => _buildPedidoCard(lista[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = _filtrarPorEstado(['pendiente']).length;
    final enPreparacion = _filtrarPorEstado(['en_preparacion']).length;
    final listos = _filtrarPorEstado(['listo']).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textLight,
          isScrollable: true,
          tabs: [
            Tab(
              child: Row(
                children: [
                  const Text('Nuevos', style: TextStyle(fontSize: 12)),
                  if (pendientes > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$pendientes',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ]
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  const Text('Cocina', style: TextStyle(fontSize: 12)),
                  if (enPreparacion > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$enPreparacion',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ]
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  const Text('Listos', style: TextStyle(fontSize: 12)),
                  if (listos > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$listos',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ]
                ],
              ),
            ),
            const Tab(child: Text('Historial', style: TextStyle(fontSize: 12))),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: () async {
          const storage = FlutterSecureStorage();
          final role = await storage.read(key: AppConstants.userKey) ?? 'cliente';
          if (context.mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/dashboard',
              (route) => false,
              arguments: role,
            );
          }
        },
        child: const Icon(Icons.home, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLista(['pendiente']),
                _buildLista(['en_preparacion']),
                _buildLista(['listo']),
                _buildLista(['entregado', 'pagado', 'cancelado']),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}