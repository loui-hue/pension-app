import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/themes/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    await _apiService.init();
    try {
      final resPuntos = await _apiService.get('/loyalty');
      final resTodasInsignias = await _apiService.get('/badges');
      final resInsigniasUsuario = await _apiService.get('/badges/user');
      final resTodosRetos = await _apiService.get('/challenges');
      final resRetosUsuario = await _apiService.get('/challenges/user');
      final resRacha = await _apiService.post('/loyalty/streak', {});

      final puntos = (resPuntos.data as List)
          .fold<int>(0, (sum, p) => sum + ((p['points'] ?? 0) as num).toInt());

      setState(() {
        _totalXp = puntos;
        _todasInsignias = resTodasInsignias.data;
        _insigniasObtenidas = resInsigniasUsuario.data;
        _todosRetos = resTodosRetos.data;
        _retosUsuario = resRetosUsuario.data;
        _racha = resRacha.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
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
          : RefreshIndicator(
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

  Widget _buildInsigniasTab() {
    if (_todasInsignias.isEmpty) {
      return const Center(child: Text('Aún no hay insignias configuradas.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _todasInsignias.length,
      itemBuilder: (context, index) {
        final insignia = _todasInsignias[index];
        final obtenida = _tieneInsignia(insignia['id']);
        final color = obtenida ? AppTheme.primary : AppTheme.textLight.withOpacity(0.3);

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events,
                    size: 48,
                    color: obtenida ? AppTheme.accent : AppTheme.textLight.withOpacity(0.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    insignia['name'],
                    style: TextStyle(
                      color: obtenida ? AppTheme.textLight : AppTheme.textLight.withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    obtenida ? 'Obtenida' : '${insignia['xp_required']} XP requeridos',
                    style: TextStyle(
                      color: obtenida ? AppTheme.primary : AppTheme.textLight.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (obtenida)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                ),
            ],
          ),
        );
      },
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
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
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
                              color: AppTheme.textLight.withOpacity(0.7),
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
                      backgroundColor: AppTheme.textLight.withOpacity(0.15),
                      color: completado ? Colors.green : AppTheme.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    completado ? '¡Reto completado!' : 'Progreso: ${progreso.toInt()}%',
                    style: TextStyle(
                      color: completado ? Colors.green : AppTheme.textLight.withOpacity(0.7),
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
