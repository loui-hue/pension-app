import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/themes/app_theme.dart';

class CrearPedidoScreen extends StatefulWidget {
  const CrearPedidoScreen({super.key});

  @override
  State<CrearPedidoScreen> createState() => _CrearPedidoScreenState();
}

class _CrearPedidoScreenState extends State<CrearPedidoScreen> {
  final _apiService = ApiService();
  List _productos = [];
  List _mesas = [];
  List _comensales = [];
  Map<int, int> _carrito = {};
  int? _mesaSeleccionada;
  Map? _comensalSeleccionado;
  String _role = AppConstants.roleCliente;
  String _notas = '';
  bool _isLoading = true;
  bool _enviando = false;
  bool _carritoRecibido = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_carritoRecibido) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map<int, int>) {
        _carrito = Map<int, int>.from(args);
        _carritoRecibido = true;
      }
    }
  }

  // El personal (mesero, admin) registra pedidos a nombre de un comensal;
  // el cliente los hace a su propio nombre.
  bool get _debeElegirComensal => _role != AppConstants.roleCliente;

  Future<void> _cargarDatos() async {
    await _apiService.init();
    try {
      const storage = FlutterSecureStorage();
      _role = await storage.read(key: AppConstants.userKey) ?? AppConstants.roleCliente;

      final resProd = await _apiService.get('/products');
      final resMesas = await _apiService.get('/tables');
      final resComensales = _debeElegirComensal
          ? await _apiService.get('/users?role=${AppConstants.roleCliente}')
          : null;
      setState(() {
        _productos = resProd.data;
        _mesas = resMesas.data
            .where((m) => m['status'] == 'disponible')
            .toList();
        _comensales = resComensales?.data ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  double get _total {
    double total = 0;
    _carrito.forEach((productId, cantidad) {
      try {
        final producto = _productos.firstWhere((p) => p['id'] == productId);
        total += double.parse(producto['price'].toString()) * cantidad;
      } catch (e) {}
    });
    return total;
  }

  void _agregarProducto(int productId) {
    setState(() {
      _carrito[productId] = (_carrito[productId] ?? 0) + 1;
    });
  }

  void _quitarProducto(int productId) {
    setState(() {
      if (_carrito[productId] != null && _carrito[productId]! > 0) {
        _carrito[productId] = _carrito[productId]! - 1;
        if (_carrito[productId] == 0) _carrito.remove(productId);
      }
    });
  }

  Future<void> _elegirComensal() async {
    final elegido = await showModalBottomSheet<Map>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SelectorComensal(comensales: _comensales),
    );
    if (elegido == null) return;
    setState(() {
      _comensalSeleccionado = elegido;
      // Si se acaba de registrar, que aparezca en la lista la próxima vez.
      if (!_comensales.any((c) => c['id'] == elegido['id'])) {
        _comensales = [elegido, ..._comensales];
      }
    });
  }

  Future<void> _enviarPedido() async {
    if (_debeElegirComensal && _comensalSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al comensal'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_mesaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una mesa'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega productos al pedido'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      final items = _carrito.entries.map((e) => {
        'product_id': e.key,
        'quantity': e.value,
      }).toList();

      await _apiService.post('/orders', {
        'table_id': _mesaSeleccionada,
        'notes': _notas,
        'items': items,
        if (_debeElegirComensal) 'user_id': _comensalSeleccionado!['id'],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Pedido enviado exitosamente!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      final mensaje = e is DioException && e.response?.data is Map
          ? (e.response!.data['message'] ?? 'Error al enviar pedido')
          : 'Error al enviar pedido';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Pedido'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                'Bs. ${_total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      // Toda la pantalla desplaza junta (comensal, mesa, productos y notas); solo el
      // botón de confirmar queda fijo abajo. Así la lista de productos usa casi todo el
      // alto del celular y el teclado de "Notas" no aplasta la pantalla.
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // Selector de comensal (solo personal)
                if (_debeElegirComensal) ...[
                  InkWell(
                    onTap: _elegirComensal,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: _decoracionCampo('Comensal', Icons.person)
                          .copyWith(suffixIcon: const Icon(Icons.search, color: AppTheme.accent)),
                      child: Text(
                        _comensalSeleccionado == null
                            ? 'Toca para buscar al comensal'
                            : '${_comensalSeleccionado!['name']}'
                                '${_comensalSeleccionado!['phone'] != null ? ' — ${_comensalSeleccionado!['phone']}' : ''}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _comensalSeleccionado == null ? Colors.white54 : AppTheme.textLight,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Selector de mesa
                DropdownButtonFormField<int>(
                  value: _mesaSeleccionada,
                  isExpanded: true,
                  dropdownColor: AppTheme.surface,
                  style: const TextStyle(color: AppTheme.textLight),
                  decoration: _decoracionCampo('Mesa', Icons.table_restaurant),
                  hint: const Text('Selecciona una mesa', style: TextStyle(color: Colors.white54)),
                  items: _mesas.map<DropdownMenuItem<int>>((mesa) {
                    return DropdownMenuItem<int>(
                      value: mesa['id'],
                      child: Text(
                        'Mesa ${mesa['number']} — ${mesa['capacity']} personas',
                        style: const TextStyle(color: AppTheme.textLight),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _mesaSeleccionada = val),
                ),
                // Productos agrupados por categoría
                ..._productosPorCategoria().entries.expand((grupo) => [
                      Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 8),
                        child: Row(
                          children: [
                            Icon(_iconoCategoria(grupo.key), color: AppTheme.accent, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              grupo.key,
                              style: const TextStyle(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...grupo.value.map(_buildProducto),
                    ]),
                const SizedBox(height: 12),
                // Notas
                TextField(
                  style: const TextStyle(color: AppTheme.textLight),
                  maxLines: 2,
                  minLines: 1,
                  decoration: _decoracionCampo('Notas del pedido (opcional)', Icons.edit_note),
                  onChanged: (val) => _notas = val,
                ),
              ],
            ),
      // Botón fijo con el total, siempre visible.
      bottomNavigationBar: _isLoading
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: AppTheme.background,
                  border: Border(top: BorderSide(color: Colors.white12)),
                ),
                child: ElevatedButton(
                  onPressed: _enviando ? null : _enviarPedido,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _enviando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _cantidadItems == 0
                              ? 'Confirmar Pedido — Bs. ${_total.toStringAsFixed(2)}'
                              : 'Confirmar $_cantidadItems ${_cantidadItems == 1 ? 'producto' : 'productos'} — Bs. ${_total.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ),
    );
  }

  InputDecoration _decoracionCampo(String etiqueta, IconData icono) => InputDecoration(
        labelText: etiqueta,
        labelStyle: const TextStyle(color: AppTheme.accent),
        prefixIcon: Icon(icono, color: AppTheme.accent),
        filled: true,
        fillColor: AppTheme.surface,
        border: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  int get _cantidadItems => _carrito.values.fold(0, (suma, c) => suma + c);

  /// Productos agrupados por el nombre de su categoría, en el orden en que llegan.
  Map<String, List> _productosPorCategoria() {
    final grupos = <String, List>{};
    for (final p in _productos) {
      final categoria = (p['category']?['name'] ?? 'Otros').toString();
      grupos.putIfAbsent(categoria, () => []).add(p);
    }
    return grupos;
  }

  IconData _iconoCategoria(String categoria) {
    final c = categoria.toLowerCase();
    if (c.contains('bebida')) return Icons.local_drink;
    if (c.contains('postre')) return Icons.icecream;
    if (c.contains('entrada') || c.contains('sopa')) return Icons.soup_kitchen;
    if (c.contains('menú') || c.contains('menu')) return Icons.restaurant_menu;
    return Icons.dinner_dining;
  }

  Widget _buildProducto(dynamic producto) {
    final cantidad = _carrito[producto['id']] ?? 0;
    final categoria = (producto['category']?['name'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cantidad > 0 ? AppTheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(_iconoCategoria(categoria), color: AppTheme.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto['name'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold),
                ),
                Text('Bs. ${producto['price']}', style: const TextStyle(color: AppTheme.accent)),
              ],
            ),
          ),
          IconButton(
            onPressed: cantidad == 0 ? null : () => _quitarProducto(producto['id']),
            icon: Icon(Icons.remove_circle, color: cantidad == 0 ? Colors.white24 : Colors.red),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$cantidad',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textLight, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: () => _agregarProducto(producto['id']),
            icon: const Icon(Icons.add_circle, color: Colors.green),
          ),
        ],
      ),
    );
  }
}

/// Hoja inferior para buscar al comensal por nombre, correo o teléfono.
class _SelectorComensal extends StatefulWidget {
  final List comensales;
  const _SelectorComensal({required this.comensales});

  @override
  State<_SelectorComensal> createState() => _SelectorComensalState();
}

class _SelectorComensalState extends State<_SelectorComensal> {
  String _busqueda = '';

  /// Recuperación asistida: el comensal olvidó su contraseña y está presente.
  /// Vuelve a ser temporal (su celular) y crea una nueva al entrar.
  Future<void> _restablecerPassword(Map comensal) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Restablecer contraseña', style: TextStyle(color: AppTheme.accent)),
        content: Text(
          '¿Verificaste en persona que es ${comensal['name']}?\n\n'
          'Su contraseña volverá a ser su celular (${comensal['phone']}) y '
          'la app le pedirá crear una nueva al entrar.',
          style: const TextStyle(color: AppTheme.textLight),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, restablecer'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await ApiService().post('/customers/${comensal['id']}/reset-password', {});
      messenger.showSnackBar(SnackBar(
        content: Text(res.data['message'] ?? 'Contraseña restablecida'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      final data = e is DioException ? e.response?.data : null;
      messenger.showSnackBar(SnackBar(
        content: Text((data is Map ? data['message'] : null) ?? 'No se pudo restablecer la contraseña'),
        backgroundColor: Colors.red,
      ));
    }
  }

  /// Registro rápido: nombre y teléfono (el correo es opcional). El comensal
  /// queda seleccionado para el pedido y luego entra a la app con su teléfono.
  Future<void> _registrar() async {
    final busqueda = _busqueda.trim();
    final esNumero = RegExp(r'^[0-9]+$').hasMatch(busqueda);
    final nombre = TextEditingController(text: esNumero ? '' : busqueda);
    final telefono = TextEditingController(text: esNumero ? busqueda : '');
    final correo = TextEditingController();
    String? error;
    bool guardando = false;

    final nuevo = await showDialog<Map>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> guardar() async {
            if (nombre.text.trim().isEmpty || telefono.text.trim().isEmpty) {
              setDialogState(() => error = 'Escribe el nombre y el teléfono');
              return;
            }
            setDialogState(() {
              guardando = true;
              error = null;
            });
            try {
              final res = await ApiService().post('/customers', {
                'name': nombre.text.trim(),
                'phone': telefono.text.trim(),
                if (correo.text.trim().isNotEmpty) 'email': correo.text.trim().toLowerCase(),
              });
              if (context.mounted) Navigator.pop(context, res.data as Map);
            } catch (e) {
              final data = e is DioException ? e.response?.data : null;
              final errores = data is Map ? data['errors'] : null;
              setDialogState(() {
                guardando = false;
                error = errores is Map && errores.isNotEmpty
                    ? (errores.values.first as List).first.toString()
                    : (data is Map ? data['message'] : null) ?? 'No se pudo registrar';
              });
            }
          }

          InputDecoration deco(String etiqueta, IconData icono) => InputDecoration(
                labelText: etiqueta,
                labelStyle: const TextStyle(color: AppTheme.accent),
                prefixIcon: Icon(icono, color: AppTheme.accent),
                filled: true,
                fillColor: Colors.white10,
                border: UnderlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              );

          return AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Text('Registrar comensal', style: TextStyle(color: AppTheme.accent)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nombre,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(color: AppTheme.textLight),
                    decoration: deco('Nombre completo', Icons.person),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: telefono,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: AppTheme.textLight),
                    decoration: deco('Celular', Icons.phone),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: correo,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    style: const TextStyle(color: AppTheme.textLight),
                    decoration: deco('Correo (opcional)', Icons.email),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Podrá entrar a la app con su celular. La primera vez su contraseña es '
                    'el mismo número y la app le pedirá crear una propia.',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: Colors.redAccent)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: guardando ? null : () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: guardando ? null : guardar,
                child: guardando
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Registrar'),
              ),
            ],
          );
        },
      ),
    );

    if (nuevo != null && mounted) Navigator.pop(context, nuevo);
  }

  List get _filtrados {
    final q = _busqueda.trim().toLowerCase();
    if (q.isEmpty) return widget.comensales;
    return widget.comensales.where((c) {
      return '${c['name']} ${c['email']} ${c['phone'] ?? ''}'.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Text(
              'Selecciona al comensal',
              style: TextStyle(
                color: AppTheme.accent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                style: const TextStyle(color: AppTheme.textLight),
                decoration: InputDecoration(
                  hintText: 'Nombre, correo o teléfono',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.accent),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: UnderlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _busqueda = val),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _registrar,
                  icon: const Icon(Icons.person_add, color: AppTheme.accent),
                  label: const Text('Registrar comensal nuevo',
                      style: TextStyle(color: AppTheme.accent)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtrados.isEmpty
                  ? const Center(
                      child: Text(
                        'No se encontraron comensales.\nRegístralo con el botón de arriba.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtrados.length,
                      itemBuilder: (context, index) {
                        final c = filtrados[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primary,
                            child: Text(
                              c['name'].toString().isNotEmpty
                                  ? c['name'].toString()[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(color: AppTheme.textLight),
                            ),
                          ),
                          title: Text(
                            c['name'],
                            style: const TextStyle(color: AppTheme.textLight),
                          ),
                          subtitle: Text(
                            c['phone'] ?? c['email'],
                            style: const TextStyle(color: Colors.white54),
                          ),
                          trailing: c['phone'] == null
                              ? null
                              : IconButton(
                                  tooltip: 'Restablecer contraseña',
                                  icon: const Icon(Icons.key, color: AppTheme.accent),
                                  onPressed: () => _restablecerPassword(c),
                                ),
                          onTap: () => Navigator.pop(context, c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}