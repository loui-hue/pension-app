import 'package:flutter/material.dart';
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
  Map<int, int> _carrito = {};
  int? _mesaSeleccionada;
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

  Future<void> _cargarDatos() async {
    await _apiService.init();
    try {
      final resProd = await _apiService.get('/products');
      final resMesas = await _apiService.get('/tables');
      setState(() {
        _productos = resProd.data;
        _mesas = resMesas.data
            .where((m) => m['status'] == 'disponible')
            .toList();
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

  Future<void> _enviarPedido() async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al enviar pedido'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmar Pedido'),
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