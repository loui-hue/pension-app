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
    if (elegido != null) setState(() => _comensalSeleccionado = elegido);
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                // Selector de comensal (solo personal)
                if (_debeElegirComensal)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    color: AppTheme.surface,
                    child: InkWell(
                      onTap: _elegirComensal,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Comensal',
                          labelStyle: const TextStyle(color: AppTheme.accent),
                          prefixIcon: const Icon(Icons.person, color: AppTheme.accent),
                          suffixIcon: const Icon(Icons.search, color: AppTheme.accent),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        child: Text(
                          _comensalSeleccionado == null
                              ? 'Toca para buscar al comensal'
                              : '${_comensalSeleccionado!['name']}'
                                  '${_comensalSeleccionado!['phone'] != null ? ' — ${_comensalSeleccionado!['phone']}' : ''}',
                          style: TextStyle(
                            color: _comensalSeleccionado == null
                                ? Colors.white54
                                : AppTheme.textLight,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Selector de mesa
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppTheme.surface,
                  child: DropdownButtonFormField<int>(
                    value: _mesaSeleccionada,
                    dropdownColor: AppTheme.surface,
                    style: const TextStyle(color: AppTheme.textLight),
                    decoration: InputDecoration(
                      labelText: 'Selecciona una mesa',
                      labelStyle: const TextStyle(color: AppTheme.accent),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
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
                ),
                // Productos en carrito
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _productos.length,
                    itemBuilder: (context, index) {
                      final producto = _productos[index];
                      final cantidad = _carrito[producto['id']] ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: cantidad > 0
                              ? Border.all(color: AppTheme.primary, width: 2)
                              : null,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.fastfood, color: AppTheme.primary, size: 36),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      producto['name'],
                                      style: const TextStyle(
                                        color: AppTheme.textLight,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Bs. ${producto['price']}',
                                      style: const TextStyle(color: AppTheme.accent),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () => _quitarProducto(producto['id']),
                                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                                  ),
                                  Text(
                                    '$cantidad',
                                    style: const TextStyle(
                                      color: AppTheme.textLight,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _agregarProducto(producto['id']),
                                    icon: const Icon(Icons.add_circle, color: Colors.green),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Notas
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    style: const TextStyle(color: AppTheme.textLight),
                    decoration: InputDecoration(
                      labelText: 'Notas del pedido (opcional)',
                      labelStyle: const TextStyle(color: AppTheme.accent),
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => _notas = val,
                  ),
                ),
                const SizedBox(height: 8),
                // Botón enviar
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _enviando ? null : _enviarPedido,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _enviando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Confirmar Pedido — Bs. ${_total.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _busqueda = val),
              ),
            ),
            Expanded(
              child: filtrados.isEmpty
                  ? const Center(
                      child: Text(
                        'No se encontraron comensales',
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