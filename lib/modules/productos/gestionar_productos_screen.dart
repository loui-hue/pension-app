import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/themes/app_theme.dart';
import '../../core/utils/avisos.dart';
import '../../core/widgets/transicion_carga.dart';

/// Gestión de la carta (RF-06, solo administrador): productos y categorías.
/// Crear, editar, marcar disponible / no disponible y eliminar. Un producto no
/// disponible deja de aparecer en la carta y en «Nuevo Pedido».
class GestionarProductosScreen extends StatefulWidget {
  const GestionarProductosScreen({super.key});

  @override
  State<GestionarProductosScreen> createState() => _GestionarProductosScreenState();
}

const _dias = {
  0: 'Todos los días',
  1: 'Lunes',
  2: 'Martes',
  3: 'Miércoles',
  4: 'Jueves',
  5: 'Viernes',
  6: 'Sábado',
};

String _bs(dynamic precio) => 'Bs. ${(double.tryParse('$precio') ?? 0).toStringAsFixed(2)}';

class _GestionarProductosScreenState extends State<GestionarProductosScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late final TabController _pestanas = TabController(length: 2, vsync: this)..addListener(() => setState(() {}));
  List _productos = [];
  List _categorias = [];
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
      final r = await Future.wait([_api.get('/products/gestion'), _api.get('/categories')]);
      if (mounted) {
        setState(() {
          _productos = r[0].data as List;
          _categorias = r[1].data as List;
          _error = null;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = mensajeDeError(e, 'No se pudo cargar la carta'); _cargando = false; });
    }
  }

  // ---------- Productos ----------

  Future<void> _formularioProducto([Map? producto]) async {
    if (_categorias.isEmpty) {
      avisar(context, 'Primero crea una categoría', error: true);
      return;
    }
    final guardado = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      builder: (_) => _FormularioProducto(producto: producto, categorias: _categorias),
    );
    if (guardado != null && mounted) {
      avisar(context, guardado);
      _cargar();
    }
  }

  Future<void> _cambiarDisponible(Map p, bool disponible) async {
    setState(() => p['available'] = disponible);   // se ve al instante
    try {
      await _api.put('/products/${p['id']}', {'available': disponible});
      if (mounted) {
        avisar(context, disponible ? '«${p['name']}» disponible para pedir' : '«${p['name']}» ya no se puede pedir');
      }
    } catch (e) {
      if (mounted) {
        setState(() => p['available'] = !disponible);
        avisar(context, mensajeDeError(e, 'No se pudo cambiar la disponibilidad'), error: true);
      }
    }
  }

  Future<void> _eliminarProducto(Map p) async {
    final si = await confirmar(context,
        titulo: 'Eliminar producto',
        texto: '¿Eliminar «${p['name']}» de la carta? Esta acción no se puede deshacer.');
    if (!si) return;
    try {
      final r = await _api.delete('/products/${p['id']}');
      if (mounted) avisar(context, r.data['message'] ?? 'Producto eliminado');
      _cargar();
    } catch (e) {
      if (mounted) avisar(context, mensajeDeError(e, 'No se pudo eliminar el producto'), error: true);
    }
  }

  // ---------- Categorías ----------

  Future<void> _formularioCategoria([Map? categoria]) async {
    final guardado = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      builder: (_) => _FormularioCategoria(categoria: categoria),
    );
    if (guardado != null && mounted) {
      avisar(context, guardado);
      _cargar();
    }
  }

  Future<void> _eliminarCategoria(Map c) async {
    final si = await confirmar(context,
        titulo: 'Eliminar categoría',
        texto: '¿Eliminar la categoría «${c['name']}»? Esta acción no se puede deshacer.');
    if (!si) return;
    try {
      final r = await _api.delete('/categories/${c['id']}');
      if (mounted) avisar(context, r.data['message'] ?? 'Categoría eliminada');
      _cargar();
    } catch (e) {
      if (mounted) avisar(context, mensajeDeError(e, 'No se pudo eliminar la categoría'), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enProductos = _pestanas.index == 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
        bottom: TabBar(
          controller: _pestanas,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textLight,
          tabs: const [Tab(text: 'Productos'), Tab(text: 'Categorías')],
        ),
      ),
      floatingActionButton: _cargando || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => enProductos ? _formularioProducto() : _formularioCategoria(),
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.add),
              label: Text(enProductos ? 'Nuevo producto' : 'Nueva categoría'),
            ),
      body: _cargando
          ? const Cargando()
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : TabBarView(
                  controller: _pestanas,
                  children: [_listaProductos(), _listaCategorias()],
                ),
    );
  }

  Widget _listaProductos() {
    final filas = <Widget>[];
    for (final c in _categorias) {
      final deLaCategoria = _productos.where((p) => p['category_id'] == c['id']).toList();
      filas.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
        child: Text('${c['name']}',
            style: const TextStyle(color: AppTheme.accent, fontSize: 15, fontWeight: FontWeight.bold)),
      ));
      if (deLaCategoria.isEmpty) {
        filas.add(const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 4),
          child: Text('Sin productos', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ));
      }
      filas.addAll(deLaCategoria.map(_tarjetaProducto));
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 96), children: filas),
    );
  }

  Widget _tarjetaProducto(dynamic p) {
    final disponible = p['available'] == true;
    final dia = p['day_of_week'];
    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _formularioProducto(p),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p['name']}',
                        style: TextStyle(
                          color: disponible ? AppTheme.textLight : Colors.white38,
                          fontWeight: FontWeight.bold,
                          decoration: disponible ? null : TextDecoration.lineThrough,
                        )),
                    Text(
                      [
                        _bs(p['price']),
                        if (dia != null) 'menú del ${_dias[dia]?.toLowerCase()}',
                        if (!disponible) 'no disponible',
                      ].join(' · '),
                      style: TextStyle(color: disponible ? AppTheme.accent : Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: disponible,
                activeThumbColor: AppTheme.primary,
                onChanged: (v) => _cambiarDisponible(p, v),
              ),
              IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline, color: Colors.white54),
                onPressed: () => _eliminarProducto(p),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listaCategorias() {
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: _categorias.length,
        itemBuilder: (context, i) {
          final c = _categorias[i];
          final cantidad = _productos.where((p) => p['category_id'] == c['id']).length;
          return Card(
            color: AppTheme.surface,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.category, color: AppTheme.accent),
              title: Text('${c['name']}', style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold)),
              subtitle: Text(cantidad == 1 ? '1 producto' : '$cantidad productos',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () => _formularioCategoria(c),
              trailing: IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline, color: Colors.white54),
                onPressed: () => _eliminarCategoria(c),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FormularioProducto extends StatefulWidget {
  final Map? producto;
  final List categorias;
  const _FormularioProducto({this.producto, required this.categorias});

  @override
  State<_FormularioProducto> createState() => _FormularioProductoState();
}

class _FormularioProductoState extends State<_FormularioProducto> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.producto?['name'] ?? '');
  late final _descripcion = TextEditingController(text: widget.producto?['description'] ?? '');
  late final _precio = TextEditingController(
      text: widget.producto == null ? '' : (double.tryParse('${widget.producto!['price']}') ?? 0).toStringAsFixed(2));
  late int _categoria = widget.producto?['category_id'] ?? widget.categorias.first['id'];
  late int _dia = widget.producto?['day_of_week'] ?? 0;
  late bool _disponible = widget.producto?['available'] ?? true;
  bool _guardando = false;

  bool get _editando => widget.producto != null;

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final datos = {
      'name': _nombre.text.trim(),
      'description': _descripcion.text.trim().isEmpty ? null : _descripcion.text.trim(),
      'price': double.parse(_precio.text.replaceAll(',', '.')),
      'category_id': _categoria,
      'day_of_week': _dia == 0 ? null : _dia,
      'available': _disponible,
    };
    try {
      final api = ApiService();
      _editando ? await api.put('/products/${widget.producto!['id']}', datos) : await api.post('/products', datos);
      if (mounted) Navigator.pop(context, _editando ? 'Producto actualizado' : 'Producto creado');
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        avisar(context, mensajeDeError(e, 'No se pudo guardar el producto'), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(color: AppTheme.textLight);
    return HojaFormulario(
      form: _form,
      titulo: _editando ? 'Editar producto' : 'Nuevo producto',
      campos: [
        TextFormField(
          controller: _nombre,
          style: estilo,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nombre'),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe el nombre del producto' : null,
        ),
        TextFormField(
          controller: _descripcion,
          style: estilo,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
        ),
        TextFormField(
          controller: _precio,
          style: estilo,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Precio (Bs.)'),
          validator: (v) {
            final n = double.tryParse((v ?? '').replaceAll(',', '.'));
            if (n == null) return 'Escribe el precio';
            if (n < 0) return 'El precio no puede ser negativo';
            if (n > 10000) return 'El precio no puede pasar de Bs. 10 000';
            return null;
          },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _categoria,
          dropdownColor: AppTheme.surface,
          style: estilo,
          decoration: const InputDecoration(labelText: 'Categoría'),
          items: widget.categorias
              .map((c) => DropdownMenuItem<int>(value: c['id'], child: Text('${c['name']}')))
              .toList(),
          onChanged: (v) => setState(() => _categoria = v!),
        ),
        DropdownButtonFormField<int>(
          initialValue: _dia,
          dropdownColor: AppTheme.surface,
          style: estilo,
          decoration: const InputDecoration(labelText: 'Se sirve'),
          items: _dias.entries.map((d) => DropdownMenuItem(value: d.key, child: Text(d.value))).toList(),
          onChanged: (v) => setState(() => _dia = v!),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _disponible,
          activeThumbColor: AppTheme.primary,
          title: const Text('Disponible para pedir', style: estilo),
          subtitle: const Text('Si se agota, desactívalo: deja de aparecer en la carta.',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          onChanged: (v) => setState(() => _disponible = v),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          child: Text(_guardando ? 'Guardando…' : (_editando ? 'Guardar cambios' : 'Crear producto')),
        ),
      ],
    );
  }
}

class _FormularioCategoria extends StatefulWidget {
  final Map? categoria;
  const _FormularioCategoria({this.categoria});

  @override
  State<_FormularioCategoria> createState() => _FormularioCategoriaState();
}

class _FormularioCategoriaState extends State<_FormularioCategoria> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.categoria?['name'] ?? '');
  bool _guardando = false;

  bool get _editando => widget.categoria != null;

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final api = ApiService();
      final datos = {'name': _nombre.text.trim()};
      _editando ? await api.put('/categories/${widget.categoria!['id']}', datos) : await api.post('/categories', datos);
      if (mounted) Navigator.pop(context, _editando ? 'Categoría renombrada' : 'Categoría creada');
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        avisar(context, mensajeDeError(e, 'No se pudo guardar la categoría'), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return HojaFormulario(
      form: _form,
      titulo: _editando ? 'Renombrar categoría' : 'Nueva categoría',
      campos: [
        TextFormField(
          controller: _nombre,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textLight),
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nombre'),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe el nombre de la categoría' : null,
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          child: Text(_guardando ? 'Guardando…' : (_editando ? 'Guardar' : 'Crear categoría')),
        ),
      ],
    );
  }
}
