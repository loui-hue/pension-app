import 'package:flutter/material.dart';
import '../../core/themes/app_theme.dart';
import '../../core/widgets/transicion_carga.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/cache_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Se averigua una sola vez al abrir el menú (pensión o portal). Antes se repetía en
  // cada cambio de pantalla y el menú se vaciaba un instante: eso era el "destello".
  late final Future<void> _servidor = ApiService.elegirServidor();

  @override
  Widget build(BuildContext context) {
    final role = ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pensión Doña Roberta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              const storage = FlutterSecureStorage();
              await storage.deleteAll();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          )
        ],
      ),
      // Antes de armar el menú se averigua si está en la pensión o fuera (portal).
      body: FutureBuilder(
        future: _servidor,
        builder: (context, estado) {
          if (estado.connectionState != ConnectionState.done) {
            return const Cargando();
          }
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: AppTheme.surface,
                child: Text(
                  'Bienvenido: $role',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (ApiService.modoRemoto && role == AppConstants.roleCliente) const _AvisoModoRemoto(),
              // El personal opera solo dentro de la red de la pensión: fuera de ella se
              // explica en vez de mostrar un menú vacío.
              if (ApiService.modoRemoto && role != AppConstants.roleCliente)
                const Expanded(child: _AvisoPersonalFuera())
              else
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  padding: const EdgeInsets.all(16),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: _getMenuItems(role, context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _getMenuItems(String role, BuildContext context) {
    final allItems = {
      AppConstants.roleAdmin: [
        _MenuItem(icon: Icons.bar_chart, label: 'Reportes', route: '/reportes'),
        _MenuItem(icon: Icons.add_shopping_cart, label: 'Nuevo Pedido', route: '/crear-pedido'),
        _MenuItem(icon: Icons.people, label: 'Usuarios', route: '/usuarios'),
        _MenuItem(icon: Icons.fastfood, label: 'Productos', route: '/productos'),
        _MenuItem(icon: Icons.table_restaurant, label: 'Mesas', route: '/mesas'),
        _MenuItem(icon: Icons.receipt_long, label: 'Pedidos', route: '/pedidos'),
        _MenuItem(icon: Icons.payment, label: 'Cobranza', route: '/cobranza'),
        _MenuItem(icon: Icons.star, label: 'Fidelización', route: '/fidelizacion'),
        _MenuItem(icon: Icons.qr_code, label: 'Métodos de pago', route: '/metodos-pago'),
      ],
      AppConstants.roleMesero: [
        _MenuItem(icon: Icons.add_shopping_cart, label: 'Nuevo Pedido', route: '/crear-pedido'),
        _MenuItem(icon: Icons.table_restaurant, label: 'Mesas', route: '/mesas'),
        _MenuItem(icon: Icons.receipt_long, label: 'Pedidos', route: '/pedidos'),
        _MenuItem(icon: Icons.fastfood, label: 'Productos', route: '/productos'),
      ],
      AppConstants.roleCocina: [
        _MenuItem(icon: Icons.receipt_long, label: 'Pedidos', route: '/pedidos'),
      ],
      AppConstants.roleCaja: [
        _MenuItem(icon: Icons.payment, label: 'Cobranza', route: '/cobranza'),
        _MenuItem(icon: Icons.receipt_long, label: 'Pedidos', route: '/pedidos'),
      ],
      AppConstants.roleCliente: [
        _MenuItem(icon: Icons.fastfood, label: 'Menú', route: '/productos'),
        _MenuItem(icon: Icons.add_shopping_cart, label: 'Nuevo Pedido', route: '/crear-pedido'),
        _MenuItem(icon: Icons.receipt_long, label: 'Mis Pedidos', route: '/mis-pedidos'),
        _MenuItem(icon: Icons.star, label: 'Fidelización', route: '/fidelizacion'),
      ],
    };

    var items = allItems[role] ?? [];
    // Fuera de la pensión (portal en la nube) solo se puede consultar.
    if (ApiService.modoRemoto) {
      items = items.where((i) => i.route == '/mis-pedidos' || i.route == '/fidelizacion').toList();
    }
    return items.map((item) => _buildCard(item, context, role)).toList();
  }

  Widget _buildCard(_MenuItem item, BuildContext context, String role) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, item.route, arguments: role),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 48, color: AppTheme.primary),
            const SizedBox(height: 12),
            Text(
              item.label,
              style: const TextStyle(
                color: AppTheme.textLight,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvisoPersonalFuera extends StatelessWidget {
  const _AvisoPersonalFuera();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 72, color: AppTheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Estás fuera de la red de la pensión',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textLight, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Los pedidos, la cocina y la caja funcionan conectados al Wi-Fi '
              '"Pension-Dona-Roberta", para que la atención no dependa de Internet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                await ApiService.elegirServidor(forzar: true);
                if (context.mounted) {
                  final role = ModalRoute.of(context)!.settings.arguments;
                  Navigator.pushReplacementNamed(context, '/dashboard', arguments: role);
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Ya estoy conectado, reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvisoModoRemoto extends StatelessWidget {
  const _AvisoModoRemoto();

  @override
  Widget build(BuildContext context) {
    final fecha = ApiService.portalSincronizadoEn;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_done, color: Colors.lightBlueAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Estás fuera de la pensión: puedes consultar tu avance.'
              '${fecha != null ? '\nDatos actualizados ${CacheService.describirFecha(fecha)}.' : ''}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String route;
  const _MenuItem({required this.icon, required this.label, required this.route});
}