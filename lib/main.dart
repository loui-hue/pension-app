import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'core/constants/app_constants.dart';
import 'core/services/api_service.dart';
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
import 'modules/cobranzas/metodos_pago_screen.dart';
import 'modules/auth/cambiar_password_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Sesión recordada: si ya inició sesión, abre directo en su menú. Así el
  // comensal ve su avance (desde la caché) aunque esté fuera de la pensión.
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: AppConstants.tokenKey);
  final role = await storage.read(key: AppConstants.userKey);
  runApp(MyApp(rolConSesion: token != null ? role : null));
}

class MyApp extends StatelessWidget {
  final String? rolConSesion;
  const MyApp({super.key, this.rolConSesion});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pensión Doña Roberta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      navigatorKey: ApiService.navegador,
      initialRoute: rolConSesion != null ? '/dashboard' : '/login',
      onGenerateInitialRoutes: (ruta) => [
        rolConSesion != null
            ? MaterialPageRoute(
                builder: (_) => const DashboardScreen(),
                settings: RouteSettings(name: '/dashboard', arguments: rolConSesion),
              )
            : MaterialPageRoute(
                builder: (_) => const LoginScreen(),
                settings: const RouteSettings(name: '/login'),
              ),
      ],
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
        '/metodos-pago': (context) => const MetodosPagoScreen(),
        '/cambiar-password': (context) => const CambiarPasswordScreen(),
      },
    );
  }
}