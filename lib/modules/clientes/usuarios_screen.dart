import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/themes/app_theme.dart';
import '../../core/utils/avisos.dart';
import '../../core/utils/contrasena.dart';
import '../../core/widgets/transicion_carga.dart';

/// Usuarios (RF-08, solo administrador). Pestaña «Personal»: crea cuentas del
/// personal con contraseña temporal, las edita y las elimina (no la propia).
/// Pestaña «Comensales»: solo consulta (los registra el mesero o la caja).
class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

const _rolesPersonal = {
  'mesero': 'Mesero',
  'cocina': 'Cocina',
  'caja': 'Caja',
  'administrador': 'Administrador',
};

String _rolDe(Map u) {
  final roles = u['roles'] as List? ?? [];
  return roles.isNotEmpty ? '${roles[0]['name']}' : 'sin rol';
}

Color _colorRol(String rol) {
  switch (rol) {
    case 'administrador': return Colors.purple;
    case 'mesero': return Colors.blue;
    case 'cocina': return Colors.orange;
    case 'caja': return Colors.green;
    case 'cliente': return Colors.teal;
    default: return Colors.grey;
  }
}

IconData _iconoRol(String rol) {
  switch (rol) {
    case 'administrador': return Icons.admin_panel_settings;
    case 'mesero': return Icons.room_service;
    case 'cocina': return Icons.soup_kitchen;
    case 'caja': return Icons.point_of_sale;
    default: return Icons.person;
  }
}

class _UsuariosScreenState extends State<UsuariosScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late final TabController _pestanas = TabController(length: 2, vsync: this)..addListener(() => setState(() {}));
  List _usuarios = [];
  int? _miId;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _pestanas.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      await _api.init();
      final r = await Future.wait([_api.get('/users'), _api.get('/me')]);
      if (mounted) {
        setState(() {
          _usuarios = r[0].data as List;
          _miId = r[1].data['id'];
          _error = null;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = mensajeDeError(e, 'No se pudieron cargar los usuarios'); _cargando = false; });
    }
  }

  List get _personal => _usuarios.where((u) => _rolDe(u) != 'cliente').toList();
  List get _comensales => _usuarios.where((u) => _rolDe(u) == 'cliente').toList();

  Future<void> _formulario([Map? usuario]) async {
    final guardado = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      builder: (_) => _FormularioPersonal(usuario: usuario, esMiCuenta: usuario != null && usuario['id'] == _miId),
    );
    if (guardado != null && mounted) {
      avisar(context, guardado);
      _cargar();
    }
  }

  Future<void> _eliminar(Map u) async {
    final si = await confirmar(context,
        titulo: 'Eliminar cuenta',
        texto: '¿Eliminar la cuenta de ${u['name']} (${_rolesPersonal[_rolDe(u)] ?? _rolDe(u)})? '
            'Ya no podrá entrar a la app. Esta acción no se puede deshacer.');
    if (!si) return;
    try {
      final r = await _api.delete('/users/${u['id']}');
      if (mounted) avisar(context, r.data['message'] ?? 'Cuenta eliminada');
      _cargar();
    } catch (e) {
      if (mounted) avisar(context, mensajeDeError(e, 'No se pudo eliminar la cuenta'), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        bottom: TabBar(
          controller: _pestanas,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textLight,
          tabs: const [Tab(text: 'Personal'), Tab(text: 'Comensales')],
        ),
      ),
      floatingActionButton: _cargando || _error != null || _pestanas.index != 0
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _formulario(),
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.person_add),
              label: const Text('Nuevo usuario'),
            ),
      body: _cargando
          ? const Cargando()
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : TabBarView(
                  controller: _pestanas,
                  children: [
                    _lista(_personal, gestionable: true),
                    _lista(_comensales, gestionable: false),
                  ],
                ),
    );
  }

  Widget _lista(List usuarios, {required bool gestionable}) {
    return RefreshIndicator(
      onRefresh: _cargar,
      child: usuarios.isEmpty
          ? ListView(children: const [
              SizedBox(height: 80),
              Center(child: Text('No hay usuarios', style: TextStyle(color: Colors.white54))),
            ])
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: usuarios.length,
              itemBuilder: (context, i) => _tarjeta(usuarios[i], gestionable),
            ),
    );
  }

  Widget _tarjeta(Map u, bool gestionable) {
    final rol = _rolDe(u);
    final color = _colorRol(rol);
    final esYo = u['id'] == _miId;
    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: gestionable ? () => _formulario(u) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.2),
                radius: 24,
                child: Icon(_iconoRol(rol), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(esYo ? '${u['name']} (tú)' : '${u['name']}',
                        style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('${u['email']}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    if (u['phone'] != null)
                      Text('${u['phone']}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color),
                ),
                child: Text(_rolesPersonal[rol] ?? (rol == 'cliente' ? 'Comensal' : rol),
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              if (gestionable)
                IconButton(
                  tooltip: esYo ? 'No puedes eliminar tu propia cuenta' : 'Eliminar',
                  icon: Icon(Icons.delete_outline, color: esYo ? Colors.white24 : Colors.white54),
                  onPressed: esYo ? null : () => _eliminar(u),
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormularioPersonal extends StatefulWidget {
  final Map? usuario;
  final bool esMiCuenta;
  const _FormularioPersonal({this.usuario, required this.esMiCuenta});

  @override
  State<_FormularioPersonal> createState() => _FormularioPersonalState();
}

class _FormularioPersonalState extends State<_FormularioPersonal> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.usuario?['name'] ?? '');
  late final _correo = TextEditingController(text: widget.usuario?['email'] ?? '');
  late final _celular = TextEditingController(text: widget.usuario?['phone'] ?? '');
  final _password = TextEditingController();
  late String _rol = widget.usuario == null ? 'mesero' : _rolDe(widget.usuario!);
  bool _verPassword = false;
  bool _guardando = false;

  bool get _editando => widget.usuario != null;

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final datos = {
      'name': _nombre.text.trim(),
      'email': _correo.text.trim(),
      'phone': _celular.text.trim().isEmpty ? null : _celular.text.trim(),
      'role': _rol,
      if (!_editando) 'password': _password.text,
    };
    try {
      final api = ApiService();
      _editando ? await api.put('/users/${widget.usuario!['id']}', datos) : await api.post('/users', datos);
      if (mounted) {
        Navigator.pop(context, _editando
            ? 'Cuenta de ${datos['name']} actualizada'
            : 'Cuenta creada: ${datos['name']} cambiará la contraseña temporal al entrar');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        avisar(context, mensajeDeError(e, 'No se pudo guardar la cuenta'), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(color: AppTheme.textLight);
    return HojaFormulario(
      form: _form,
      titulo: _editando ? 'Editar usuario' : 'Nuevo usuario del personal',
      campos: [
        TextFormField(
          controller: _nombre,
          style: estilo,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre completo'),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe el nombre' : null,
        ),
        TextFormField(
          controller: _correo,
          style: estilo,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Correo'),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return 'Escribe el correo';
            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'El correo no es válido';
            return null;
          },
        ),
        TextFormField(
          controller: _celular,
          style: estilo,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Celular (opcional)'),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isNotEmpty && !RegExp(r'^[0-9]{7,15}$').hasMatch(t)) return 'Solo números (7 a 15 dígitos)';
            return null;
          },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _rolesPersonal.containsKey(_rol) ? _rol : 'mesero',
          dropdownColor: AppTheme.surface,
          style: estilo,
          decoration: const InputDecoration(labelText: 'Rol'),
          items: _rolesPersonal.entries
              .map((r) => DropdownMenuItem(value: r.key, child: Text(r.value)))
              .toList(),
          // El administrador no puede quitarse su propio rol.
          onChanged: widget.esMiCuenta ? null : (v) => setState(() => _rol = v!),
        ),
        if (widget.esMiCuenta)
          const Text('No puedes cambiar tu propio rol.', style: TextStyle(color: Colors.white54, fontSize: 12)),
        if (!_editando) ...[
          TextFormField(
            controller: _password,
            style: estilo,
            obscureText: !_verPassword,
            decoration: InputDecoration(
              labelText: 'Contraseña temporal',
              suffixIcon: IconButton(
                icon: Icon(_verPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                onPressed: () => setState(() => _verPassword = !_verPassword),
              ),
            ),
            validator: (v) => problemaDeContrasena(v ?? '', cual: 'La contraseña temporal'),
          ),
          const Text('Al menos 8 caracteres, con letras y números. Entrégasela en persona: '
              'deberá cambiarla en su primer ingreso.',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          child: Text(_guardando ? 'Guardando…' : (_editando ? 'Guardar cambios' : 'Crear cuenta')),
        ),
      ],
    );
  }
}
