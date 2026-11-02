import 'package:flutter/material.dart';
import '../../core/themes/app_theme.dart';
import '../../core/constants/app_constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
      body: Column(
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

    final items = allItems[role] ?? [];
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

class _MenuItem {
  final IconData icon;
  final String label;
  final String route;
  const _MenuItem({required this.icon, required this.label, required this.route});
}
