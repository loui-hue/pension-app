import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/cache_service.dart';
import '../../core/themes/app_theme.dart';
import '../../core/widgets/aviso_sin_conexion.dart';

class FidelizacionScreen extends StatefulWidget {
  const FidelizacionScreen({super.key});

  @override
  State<FidelizacionScreen> createState() => _FidelizacionScreenState();
}

class _FidelizacionScreenState extends State<FidelizacionScreen>
    with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  late TabController _tabController;

  List _todasInsignias = [];
  List _insigniasObtenidas = [];
  List _todosRetos = [];
  List _retosUsuario = [];
  Map _racha = {};
  int _totalXp = 0;
  bool _isLoading = true;
  bool _uniendoReto = false;
  // Fecha de la copia guardada cuando no hay conexión (null = datos en vivo).
  DateTime? _desdeCache;
  bool _actualizando = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    const storage = FlutterSecureStorage();
    final usuarioId = int.tryParse(await storage.read(key: AppConstants.userIdKey) ?? '');
    final claveCache = CacheService.clave(usuarioId, 'fidelizacion');
    final cache = await CacheService.leer(claveCache);

    // Primero lo guardado en el celular, al instante (sin pantalla en blanco);
    // luego se actualiza con el servidor y solo se ve una barra fina arriba.
    if (_isLoading && cache != null) _aplicarDatos(cache.datos as Map, desdeCache: null);
    if (mounted) setState(() => _actualizando = true);

    await _apiService.init();
    try {
      // Las seis consultas a la vez, no una tras otra: carga más rápido.
      final r = await Future.wait([
        _apiService.get('/loyalty'),
        _apiService.get('/badges'),
        _apiService.get('/badges/user'),
        _apiService.get('/challenges'),
        _apiService.get('/challenges/user'),
        _apiService.post('/loyalty/streak', {}),
      ]);
      final datos = {
        'puntos': r[0].data,
        'insignias': r[1].data,
        'insigniasUsuario': r[2].data,
        'retos': r[3].data,
        'retosUsuario': r[4].data,
        'racha': r[5].data,
      };
      await CacheService.guardar(claveCache, datos);
      _aplicarDatos(datos, desdeCache: null);
    } catch (e) {
      // Sin conexión con el servidor: se muestra lo último que se guardó.
      if (cache != null) {
        _aplicarDatos(cache.datos as Map, desdeCache: cache.guardado);
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } finally {
      if (mounted) setState(() => _actualizando = false);
    }
  }

  void _aplicarDatos(Map datos, {required DateTime? desdeCache}) {
    if (!mounted) return;
    final puntos = (datos['puntos'] as List)
        .fold<int>(0, (sum, p) => sum + ((p['points'] ?? 0) as num).toInt());
    setState(() {
      _totalXp = puntos;
      // De menor a mayor XP requerido, para que se lea como una progresión.
      _todasInsignias = List.of(datos['insignias'] as List)
        ..sort((a, b) => ((a['xp_required'] ?? 0) as num).compareTo((b['xp_required'] ?? 0) as num));
      _insigniasObtenidas = datos['insigniasUsuario'];
      _todosRetos = datos['retos'];
      _retosUsuario = datos['retosUsuario'];
      _racha = datos['racha'];
      _desdeCache = desdeCache;
      _isLoading = false;
    });
  }

  bool _tieneInsignia(int badgeId) {
    return _insigniasObtenidas.any((b) => b['id'] == badgeId);
  }

  Map? _progresoDelReto(int challengeId) {
    try {
      return _retosUsuario.firstWhere((r) => r['id'] == challengeId) as Map;
    } catch (_) {
      return null;
    }
  }

  Future<void> _unirseAReto(int challengeId) async {
    setState(() => _uniendoReto = true);
    try {
      await _apiService.post('/challenges/join', {'challenge_id': challengeId});
      await _cargarDatos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo unir al reto')),
        );
      }
    } finally {
      if (mounted) setState(() => _uniendoReto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fidelización'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textLight,
          tabs: const [
            Tab(icon: Icon(Icons.local_fire_department), text: 'Racha'),
            Tab(icon: Icon(Icons.emoji_events), text: 'Insignias'),
            Tab(icon: Icon(Icons.flag), text: 'Retos'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                // Barra fina mientras se actualiza (en vez de vaciar la pantalla).
                SizedBox(
                  height: 3,
                  child: _actualizando
                      ? const LinearProgressIndicator(color: AppTheme.primary, backgroundColor: Colors.transparent)
                      : null,
                ),
                if (_desdeCache != null)
                  AvisoSinConexion(desde: _desdeCache!, onReintentar: _cargarDatos),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _cargarDatos,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildRachaTab(),
                        _buildInsigniasTab(),
                        _buildRetosTab(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRachaTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Column(
            children: [
              const Icon(Icons.local_fire_department, size: 80, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                '${_racha['current_streak'] ?? 0}',
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const Text(
                'días seguidos',
                style: TextStyle(color: AppTheme.textLight, fontSize: 18),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.star, color: AppTheme.accent),
                        Text(
                          '$_totalXp',
                          style: const TextStyle(
                            color: AppTheme.textLight,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('XP total', style: TextStyle(color: AppTheme.accent, fontSize: 12)),
                      ],
                    ),
                    Column(
                      children: [
                        const Icon(Icons.emoji_events, color: AppTheme.accent),
                        Text(
                          '${_racha['longest_streak'] ?? 0}',
                          style: const TextStyle(
                            color: AppTheme.textLight,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('Mejor racha', style: TextStyle(color: AppTheme.accent, fontSize: 12)),
                      ],
                    ),
                    Column(
                      children: [
                        const Icon(Icons.calendar_today, color: AppTheme.accent),
                        Text(
                          _racha['last_visit']?.toString().substring(0, 10) ?? 'N/A',
                          style: const TextStyle(color: AppTheme.textLight, fontSize: 14),
                        ),
                        const Text('Última visita', style: TextStyle(color: AppTheme.accent, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Ícono y colores propios de cada insignia (medalla), según su nombre o tipo.
  ({IconData icono, List<Color> colores}) _estiloInsignia(Map insignia) {
    final nombre = insignia['name'].toString().toLowerCase();
    final tipo = (insignia['type'] ?? '').toString();
    if (nombre.contains('primer')) {
      return (icono: Icons.restaurant, colores: const [Color(0xFFE0A26B), Color(0xFFA0522D)]); // bronce
    }
    if (nombre.contains('racha')) {
      return (icono: Icons.local_fire_department, colores: const [Color(0xFFFFB74D), Color(0xFFE64A19)]);
    }
    if (nombre.contains('frecuente')) {
      return (icono: Icons.favorite, colores: const [Color(0xFFF48FB1), Color(0xFFC2185B)]);
    }
    if (nombre.contains('gourmet')) {
      return (icono: Icons.ramen_dining, colores: const [Color(0xFFAED581), Color(0xFF558B2F)]);
    }
    if (nombre.contains('vip') || tipo == 'especial') {
      return (icono: Icons.workspace_premium, colores: const [Color(0xFFFFE082), Color(0xFFFFA000)]); // oro
    }
    if (tipo == 'retos') {
      return (icono: Icons.flag, colores: const [Color(0xFF81D4FA), Color(0xFF1976D2)]);
    }
    return (icono: Icons.emoji_events, colores: const [Color(0xFFFFCC80), Color(0xFFE07B39)]);
  }

  Widget _buildInsigniasTab() {
    if (_todasInsignias.isEmpty) {
      return const Center(child: Text('Aún no hay insignias configuradas.'));
    }
    final obtenidas = _todasInsignias.where((i) => _tieneInsignia(i['id'])).length;

    return CustomScrollView(
      slivers: [
        // Resumen: cuántas lleva y el XP acumulado.
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.military_tech, color: AppTheme.accent, size: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$obtenidas de ${_todasInsignias.length} insignias',
                        style: const TextStyle(
                          color: AppTheme.textLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: obtenidas / _todasInsignias.length,
                          minHeight: 8,
                          backgroundColor: Colors.white12,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Tienes $_totalXp XP', style: const TextStyle(color: AppTheme.accent, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent: 236,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildInsignia(_todasInsignias[index]),
              childCount: _todasInsignias.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInsignia(Map insignia) {
    final obtenida = _tieneInsignia(insignia['id']);
    final estilo = _estiloInsignia(insignia);
    final requerido = ((insignia['xp_required'] ?? 0) as num).toInt();
    final progreso = requerido == 0 ? 1.0 : (_totalXp / requerido).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: obtenida ? estilo.colores.last.withValues(alpha: 0.8) : Colors.white10,
          width: obtenida ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Medalla: círculo con degradado y anillo; bloqueada se ve en gris con candado.
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: obtenida
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: estilo.colores,
                        )
                      : null,
                  color: obtenida ? null : Colors.white10,
                  border: Border.all(
                    color: obtenida ? Colors.white.withValues(alpha: 0.6) : Colors.white12,
                    width: 3,
                  ),
                  boxShadow: obtenida
                      ? [BoxShadow(color: estilo.colores.last.withValues(alpha: 0.5), blurRadius: 14)]
                      : null,
                ),
                child: Icon(
                  estilo.icono,
                  size: 40,
                  color: obtenida ? Colors.white : Colors.white24,
                ),
              ),
              if (!obtenida)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(color: AppTheme.background, shape: BoxShape.circle),
                    child: const Icon(Icons.lock, size: 16, color: Colors.white54),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insignia['name'],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: obtenida ? AppTheme.textLight : Colors.white60,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            insignia['description'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.25),
          ),
          const Spacer(),
          if (obtenida)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                  SizedBox(width: 4),
                  Text('Obtenida', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                ],
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 6,
                backgroundColor: Colors.white10,
                color: estilo.colores.last,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_totalXp.clamp(0, requerido)} / $requerido XP',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRetosTab() {
    if (_todosRetos.isEmpty) {
      return const Center(child: Text('No hay retos activos por el momento.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _todosRetos.length,
      itemBuilder: (context, index) {
        final reto = _todosRetos[index];
        final progresoUsuario = _progresoDelReto(reto['id']);
        final estado = progresoUsuario?['pivot']?['status'] as String?;
        final progreso = (progresoUsuario?['pivot']?['progress'] ?? 0) as num;
        final unido = progresoUsuario != null;
        final completado = estado == 'completado';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      completado ? Icons.flag_circle : Icons.flag,
                      color: completado ? Colors.green : AppTheme.primary,
                      size: 40,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reto['name'],
                            style: const TextStyle(
                              color: AppTheme.textLight,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            reto['description'] ?? '',
                            style: TextStyle(
                              color: AppTheme.textLight.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '+${reto['xp_reward']} XP',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (unido) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progreso / 100,
                      minHeight: 8,
                      backgroundColor: AppTheme.textLight.withValues(alpha: 0.15),
                      color: completado ? Colors.green : AppTheme.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    completado ? '¡Reto completado!' : 'Progreso: ${progreso.toInt()}%',
                    style: TextStyle(
                      color: completado ? Colors.green : AppTheme.textLight.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _uniendoReto ? null : () => _unirseAReto(reto['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                      ),
                      child: const Text('Unirse al reto'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
