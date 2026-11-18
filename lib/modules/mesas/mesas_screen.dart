import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/themes/app_theme.dart';
import '../../core/utils/avisos.dart';
import '../../core/widgets/transicion_carga.dart';

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

  /// Solo el administrador agrega, edita y elimina mesas (RF-07); el mesero y la
  /// caja solo cambian su estado.
  bool get _esAdmin => ModalRoute.of(context)?.settings.arguments == AppConstants.roleAdmin;

  Future<void> _formularioMesa([Map? mesa]) async {
    final guardado = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      builder: (_) => _FormularioMesa(mesa: mesa),
    );
    if (guardado != null && mounted) {
      avisar(context, guardado);
      _cargarMesas();
    }
  }

  Future<void> _eliminarMesa(Map mesa) async {
    final si = await confirmar(context,
        titulo: 'Eliminar mesa',
        texto: '¿Eliminar la mesa ${mesa['number']}? Solo se puede si no tiene pedidos. '
            'Esta acción no se puede deshacer.');
    if (!si) return;
    try {
      final r = await _apiService.delete('/tables/${mesa['id']}');
      if (mounted) avisar(context, r.data['message'] ?? 'Mesa eliminada');
      _cargarMesas();
    } catch (e) {
      if (mounted) avisar(context, mensajeDeError(e, 'No se pudo eliminar la mesa'), error: true);
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
            if (_esAdmin) ...[
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.edit, color: AppTheme.accent),
                title: const Text('Editar número y capacidad', style: TextStyle(color: AppTheme.textLight)),
                onTap: () {
                  Navigator.pop(context);
                  _formularioMesa(mesa);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Eliminar mesa', style: TextStyle(color: AppTheme.textLight)),
                onTap: () {
                  Navigator.pop(context);
                  _eliminarMesa(mesa);
                },
              ),
            ],
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
      floatingActionButton: _esAdmin && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: () => _formularioMesa(),
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.add),
              label: const Text('Nueva mesa'),
            )
          : null,
      body: _isLoading
          ? const Cargando()
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
                    padding: EdgeInsets.fromLTRB(16, 16, 16, _esAdmin ? 96 : 16),
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
class _FormularioMesa extends StatefulWidget {
  final Map? mesa;
  const _FormularioMesa({this.mesa});

  @override
  State<_FormularioMesa> createState() => _FormularioMesaState();
}

class _FormularioMesaState extends State<_FormularioMesa> {
  final _form = GlobalKey<FormState>();
  late final _numero = TextEditingController(text: widget.mesa == null ? '' : '${widget.mesa!['number']}');
  late final _capacidad = TextEditingController(text: widget.mesa == null ? '4' : '${widget.mesa!['capacity']}');
  bool _guardando = false;

  bool get _editando => widget.mesa != null;

  String? _entero(String? v, {required int max, required String nombre}) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null) return 'Escribe $nombre';
    if (n < 1) return 'Debe ser 1 o más';
    if (n > max) return 'No puede pasar de $max';
    return null;
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final datos = {'number': int.parse(_numero.text.trim()), 'capacity': int.parse(_capacidad.text.trim())};
    try {
      final api = ApiService();
      _editando ? await api.put('/tables/${widget.mesa!['id']}', datos) : await api.post('/tables', datos);
      if (mounted) Navigator.pop(context, _editando ? 'Mesa ${datos['number']} actualizada' : 'Mesa ${datos['number']} agregada');
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        avisar(context, mensajeDeError(e, 'No se pudo guardar la mesa'), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(color: AppTheme.textLight);
    return HojaFormulario(
      form: _form,
      titulo: _editando ? 'Editar mesa ${widget.mesa!['number']}' : 'Nueva mesa',
      campos: [
        TextFormField(
          controller: _numero,
          style: estilo,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Número de mesa'),
          validator: (v) => _entero(v, max: 999999, nombre: 'el número'),
        ),
        TextFormField(
          controller: _capacidad,
          style: estilo,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Capacidad (personas)'),
          validator: (v) => _entero(v, max: 50, nombre: 'la capacidad'),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          child: Text(_guardando ? 'Guardando…' : (_editando ? 'Guardar cambios' : 'Agregar mesa')),
        ),
      ],
    );
  }
}
