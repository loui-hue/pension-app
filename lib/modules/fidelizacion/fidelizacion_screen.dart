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
  List _insignias = [];
  List _retos = [];
  Map _racha = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    await _apiService.init();
    try {
      final resInsignias = await _apiService.get('/badges');
      final resRetos = await _apiService.get('/challenges');
      final resRacha = await _apiService.post('/loyalty/streak', {});
      setState(() {
        _insignias = resInsignias.data;
        _retos = resRetos.data;
        _racha = resRacha.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRachaTab(),
                _buildInsigniasTab(),
                _buildRetosTab(),
              ],
            ),
    );
  }

  Widget _buildRachaTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }

  Widget _buildInsigniasTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _insignias.length,
      itemBuilder: (context, index) {
        final insignia = _insignias[index];
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, size: 48, color: AppTheme.accent),
              const SizedBox(height: 8),
              Text(
                insignia['name'],
                style: const TextStyle(
                  color: AppTheme.textLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '${insignia['xp_required']} XP',
                style: const TextStyle(color: AppTheme.primary, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRetosTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _retos.length,
      itemBuilder: (context, index) {
        final reto = _retos[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.flag, color: AppTheme.primary, size: 40),
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