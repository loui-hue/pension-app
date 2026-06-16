import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/themes/app_theme.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  final _apiService = ApiService();
  List _usuarios = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    await _apiService.init();
    try {
      final res = await _apiService.get('/users');
      setState(() {
        _usuarios = res.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Color _getRolColor(String rol) {
    switch (rol) {
      case 'administrador': return Colors.purple;
      case 'mesero': return Colors.blue;
      case 'cocina': return Colors.orange;
      case 'caja': return Colors.green;
      case 'cliente': return Colors.teal;
      default: return Colors.grey;
    }
  }

  IconData _getRolIcon(String rol) {
    switch (rol) {
      case 'administrador': return Icons.admin_panel_settings;
      case 'mesero': return Icons.room_service;
      case 'cocina': return Icons.soup_kitchen;
      case 'caja': return Icons.point_of_sale;
      case 'cliente': return Icons.person;
      default: return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarUsuarios,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _usuarios.isEmpty
              ? const Center(
                  child: Text('No hay usuarios', style: TextStyle(color: AppTheme.textLight)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _usuarios.length,
                  itemBuilder: (context, index) {
                    final usuario = _usuarios[index];
                    final roles = usuario['roles'] as List? ?? [];
                    final rol = roles.isNotEmpty ? roles[0]['name'] : 'sin rol';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getRolColor(rol).withOpacity(0.5),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: _getRolColor(rol).withOpacity(0.2),
                              radius: 28,
                              child: Icon(_getRolIcon(rol), color: _getRolColor(rol), size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    usuario['name'],
                                    style: const TextStyle(
                                      color: AppTheme.textLight,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    usuario['email'],
                                    style: TextStyle(
                                      color: AppTheme.textLight.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (usuario['phone'] != null)
                                    Text(
                                      usuario['phone'],
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
                                color: _getRolColor(rol).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _getRolColor(rol)),
                              ),
                              child: Text(
                                rol,
                                style: TextStyle(
                                  color: _getRolColor(rol),
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
    );
  }
}