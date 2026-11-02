import 'package:flutter/material.dart';
import 'core/themes/app_theme.dart';
import 'modules/auth/login_screen.dart';
import 'modules/dashboard/dashboard_screen.dart';
import 'modules/productos/productos_screen.dart';
import 'modules/pedidos/pedidos_screen.dart';
import 'modules/pedidos/crear_pedido_screen.dart';
import 'modules/pedidos/mis_pedidos_screen.dart';
import 'modules/cobranzas/cobranza_screen.dart';
import 'modules/fidelizacion/fidelizacion_screen.dart';
import 'modules/mesas/mesas_screen.dart';
import 'modules/clientes/usuarios_screen.dart';
import 'modules/reportes/reportes_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pensión Doña Roberta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/productos': (context) => const ProductosScreen(),
        '/pedidos': (context) => const PedidosScreen(),
        '/crear-pedido': (context) => const CrearPedidoScreen(),
        '/mis-pedidos': (context) => const MisPedidosScreen(),
        '/cobranza': (context) => const CobranzaScreen(),
        '/fidelizacion': (context) => const FidelizacionScreen(),
        '/mesas': (context) => const MesasScreen(),
        '/usuarios': (context) => const UsuariosScreen(),
        '/reportes': (context) => const ReportesScreen(),
      },
    );
  }
}
