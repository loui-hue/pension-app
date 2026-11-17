import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/themes/app_theme.dart';
import '../../core/widgets/transicion_carga.dart';

/// Gestionar retos (RF-20, solo administrador): lista los retos, crea retos nuevos
/// y registra en persona el avance de los retos especiales ("Sumar 1").
/// Los retos de visitas, compras y gastronómicos avanzan solos al cobrar.
class GestionarRetosScreen extends StatefulWidget {
  const GestionarRetosScreen({super.key});

  @override
  State<GestionarRetosScreen> createState() => _GestionarRetosScreenState();
}

const _tipos = {
  'visitas': 'Visitas',
  'compras': 'Compras',
  'gastronomico': 'Gastronómico',
  'especial': 'Especial',
};

String _mensajeDeError(Object e, String porDefecto) {
  if (e is DioException) {
    final datos = e.response?.data;
    if (datos is Map && datos['message'] is String) return datos['message'];
  }
  return porDefecto;
}

String _fecha(dynamic valor) {
  final f = DateTime.tryParse('${valor ?? ''}');
  if (f == null) return '—';
  return '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
}

class _GestionarRetosScreenState extends State<GestionarRetosScreen> {
  final _api = ApiService();
  List _retos = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      await _api.init();
      final r = await _api.get('/challenges/gestion');
      if (mounted) setState(() { _retos = r.data as List; _error = null; _cargando = false; });
    } catch (e) {
      if (mounted) setState(() { _error = _mensajeDeError(e, 'No se pudieron cargar los retos'); _cargando = false; });
    }
  }

  Future<void> _nuevoReto() async {
    final creado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      builder: (_) => const _FormularioReto(),
    );
    if (creado == true) {
      _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reto creado')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar retos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevoReto,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo reto'),
      ),
      body: _cargando
          ? const Cargando()
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: _retos.length,
                    itemBuilder: (context, i) => _TarjetaReto(
                      reto: _retos[i],
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(
                          builder: (_) => _ParticipantesScreen(reto: _retos[i]),
                        ));
                        _cargar();
                      },
                    ),
                  ),
                ),
    );
  }
}

class _TarjetaReto extends StatelessWidget {
  final Map reto;
  final VoidCallback onTap;
  const _TarjetaReto({required this.reto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final especial = reto['type'] == 'especial';
    final activo = reto['active'] == true;
    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(especial ? Icons.how_to_reg : Icons.autorenew, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${reto['name']}',
                        style: const TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: activo ? Colors.green.shade700 : Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(activo ? 'Activo' : 'Inactivo',
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
              if ((reto['description'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('${reto['description']}', style: const TextStyle(color: Colors.white70)),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _Dato(Icons.category, _tipos[reto['type']] ?? '${reto['type']}'),
                  _Dato(Icons.flag, 'Meta: ${reto['goal']}'),
                  _Dato(Icons.star, '${reto['xp_reward']} XP'),
                  _Dato(Icons.people, 'Unidos: ${reto['participantes'] ?? 0}'),
                  _Dato(Icons.date_range, '${_fecha(reto['start_date'])} – ${_fecha(reto['end_date'])}'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                especial
                    ? 'Avance registrado por el administrador'
                    : 'Avanza solo al cobrar los pedidos',
                style: TextStyle(color: especial ? AppTheme.accent : Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Dato(this.icono, this.texto);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 16, color: AppTheme.primary),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(color: AppTheme.textLight, fontSize: 13)),
      ],
    );
  }
}

/// Comensales unidos a un reto. En los especiales, "Sumar 1" registra un avance
/// verificado en persona; al llegar a la meta el reto se completa y da su XP.
class _ParticipantesScreen extends StatefulWidget {
  final Map reto;
  const _ParticipantesScreen({required this.reto});

  @override
  State<_ParticipantesScreen> createState() => _ParticipantesScreenState();
}

class _ParticipantesScreenState extends State<_ParticipantesScreen> {
  final _api = ApiService();
  List _participantes = [];
  bool _cargando = true;
  int? _sumando;

  bool get _especial => widget.reto['type'] == 'especial';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await _api.get('/challenges/${widget.reto['id']}/participantes');
      if (mounted) setState(() { _participantes = r.data['participantes'] as List; _cargando = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        _aviso(_mensajeDeError(e, 'No se pudieron cargar los participantes'));
      }
    }
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _sumarUno(Map p) async {
    final nombre = p['user']?['name'] ?? 'el comensal';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar avance'),
        content: Text('¿Verificaste en persona el avance de $nombre en «${widget.reto['name']}»?\n'
            'Quedará en ${p['current_count'] + 1} de ${p['goal']}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sumar 1')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _sumando = p['id']);
    try {
      final r = await _api.patch('/challenges/${p['id']}/progress', {});
      final completado = r.data['status'] == 'completado';
      _aviso(completado
          ? '¡$nombre completó el reto! Recibe ${widget.reto['xp_reward']} XP'
          : 'Avance registrado: ${r.data['current_count']} de ${p['goal']}');
      await _cargar();
    } catch (e) {
      _aviso(_mensajeDeError(e, 'No se pudo registrar el avance'));
    } finally {
      if (mounted) setState(() => _sumando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.reto['name']}')),
      body: _cargando
          ? const Cargando()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _especial ? const Color(0xFF1E3A5F) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _especial
                        ? 'Reto especial: verifica en persona y pulsa «Sumar 1» por cada avance. '
                            'Al llegar a la meta (${widget.reto['goal']}) el comensal recibe ${widget.reto['xp_reward']} XP.'
                        : 'Este reto avanza solo cuando caja cobra los pedidos del comensal: no se registra a mano.',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                if (_participantes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Todavía no se unió ningún comensal.',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                  ),
                for (final p in _participantes) _filaParticipante(p as Map),
              ],
            ),
    );
  }

  Widget _filaParticipante(Map p) {
    final completado = p['status'] == 'completado';
    final cuenta = (p['current_count'] as num).toInt();
    final meta = (p['goal'] as num).toInt();
    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${p['user']?['name'] ?? '—'}',
                      style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(completado ? 'Completado: $cuenta de $meta' : '$cuenta de $meta',
                      style: TextStyle(color: completado ? Colors.greenAccent : Colors.white70)),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: (cuenta / meta).clamp(0, 1).toDouble(),
                    color: completado ? Colors.green : AppTheme.primary,
                    backgroundColor: Colors.white12,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (completado)
              const Icon(Icons.verified, color: Colors.greenAccent)
            else if (_especial)
              ElevatedButton.icon(
                onPressed: _sumando == null ? () => _sumarUno(p) : null,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                icon: _sumando == p['id']
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.plus_one),
                label: const Text('Sumar 1'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Formulario de reto nuevo (POST /challenges).
class _FormularioReto extends StatefulWidget {
  const _FormularioReto();

  @override
  State<_FormularioReto> createState() => _FormularioRetoState();
}

class _FormularioRetoState extends State<_FormularioReto> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _descripcion = TextEditingController();
  final _meta = TextEditingController(text: '1');
  final _xp = TextEditingController(text: '100');
  String _tipo = 'especial';
  DateTime _inicio = DateTime.now();
  DateTime _fin = DateTime.now().add(const Duration(days: 30));
  bool _guardando = false;

  String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _elegirFecha(bool inicio) async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: inicio ? _inicio : _fin,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (elegida == null) return;
    setState(() {
      if (inicio) {
        _inicio = elegida;
        if (_fin.isBefore(_inicio)) _fin = _inicio;
      } else {
        _fin = elegida;
      }
    });
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await ApiService().post('/challenges', {
        'name': _nombre.text.trim(),
        'description': _descripcion.text.trim(),
        'type': _tipo,
        'goal': int.parse(_meta.text),
        'xp_reward': int.parse(_xp.text),
        'start_date': _iso(_inicio),
        'end_date': _iso(_fin),
        'active': true,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_mensajeDeError(e, 'No se pudo crear el reto'))),
        );
      }
    }
  }

  String? _entero(String? v) {
    final n = int.tryParse(v ?? '');
    return n == null || n < 1 ? 'Número mayor a 0' : null;
  }

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(color: AppTheme.textLight);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Nuevo reto',
                  style: TextStyle(color: AppTheme.accent, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nombre,
                style: estilo,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe el nombre' : null,
              ),
              TextFormField(
                controller: _descripcion,
                style: estilo,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _tipo,
                dropdownColor: AppTheme.surface,
                style: estilo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: _tipos.entries
                    .map((t) => DropdownMenuItem(value: t.key, child: Text(t.value)))
                    .toList(),
                onChanged: (v) => setState(() => _tipo = v!),
              ),
              Text(
                _tipo == 'especial'
                    ? 'El administrador registra el avance en persona.'
                    : 'Avanza solo al cobrar los pedidos del comensal.',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _meta,
                      style: estilo,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Meta'),
                      validator: _entero,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _xp,
                      style: estilo,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'XP de recompensa'),
                      validator: _entero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _elegirFecha(true),
                      icon: const Icon(Icons.event),
                      label: Text('Desde ${_fecha(_iso(_inicio))}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _elegirFecha(false),
                      icon: const Icon(Icons.event),
                      label: Text('Hasta ${_fecha(_iso(_fin))}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(_guardando ? 'Guardando…' : 'Crear reto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
