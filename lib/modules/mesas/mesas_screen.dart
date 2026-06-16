import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/themes/app_theme.dart';

class MesasScreen extends StatefulWidget {
  const MesasScreen({super.key});

  @override
  State<MesasScreen> createState() => _MesasScreenState();
}

class _MesasScreenState extends State<MesasScreen> {
  final _apiService = ApiService();
  List _mesas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarMesas();
  }

  Future<void> _cargarMesas() async {
    await _apiService.init();
    try {
      final res = await _apiService.get('/tables');
      setState(() {
        _mesas = res.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cambiarEstado(int id, String nuevoEstado) async {
    try {
      await _apiService.patch('/tables/$id/status', {'status': nuevoEstado});
      _cargarMesas();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al actualizar mesa'), backgroundColor: Colors.red),
      );
    }
  }

  Color _getColor(String status) {
    switch (status) {
      case 'disponible': return Colors.green;
      case 'ocupada': return Colors.red;
      case 'reservada': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _getIcon(String status) {
    switch (status) {
      case 'disponible': return Icons.check_circle;
      case 'ocupada': return Icons.people;
      case 'reservada': return Icons.bookmark;
      default: return Icons.table_restaurant;
    }
  }

  void _mostrarOpciones(Map mesa) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Mesa ${mesa['number']}',
              style: const TextStyle(
                color: AppTheme.textLight,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (mesa['status'] != 'disponible')
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Marcar disponible', style: TextStyle(color: AppTheme.textLight)),
                onTap: () {
                  Navigator.pop(context);
                  _cambiarEstado(mesa['id'], 'disponible');
                },
              ),
            if (mesa['status'] != 'ocupada')
              ListTile(
                leading: const Icon(Icons.people, color: Colors.red),
                title: const Text('Marcar ocupada', style: TextStyle(color: AppTheme.textLight)),
                onTap: () {
                  Navigator.pop(context);
                  _cambiarEstado(mesa['id'], 'ocupada');
                },
              ),
            if (mesa['status'] != 'reservada')
              ListTile(
                leading: const Icon(Icons.bookmark, color: Colors.orange),
                title: const Text('Marcar reservada', style: TextStyle(color: AppTheme.textLight)),
                onTap: () {
                  Navigator.pop(context);
                  _cambiarEstado(mesa['id'], 'reservada');
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarMesas,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                // Leyenda
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildLeyenda('Disponible', Colors.green),
                      _buildLeyenda('Ocupada', Colors.red),
                      _buildLeyenda('Reservada', Colors.orange),
                    ],
                  ),
                ),
                // Grid de mesas
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _mesas.length,
                    itemBuilder: (context, index) {
                      final mesa = _mesas[index];
                      final status = mesa['status'];
                      return GestureDetector(
                        onTap: () => _mostrarOpciones(mesa),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _getColor(status),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_getIcon(status), size: 48, color: _getColor(status)),
                              const SizedBox(height: 8),
                              Text(
                                'Mesa ${mesa['number']}',
                                style: const TextStyle(
                                  color: AppTheme.textLight,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${mesa['capacity']} personas',
                                style: TextStyle(
                                  color: AppTheme.textLight.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getColor(status).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: _getColor(status),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
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

  Widget _buildLeyenda(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppTheme.textLight, fontSize: 12)),
      ],
    );
  }
}