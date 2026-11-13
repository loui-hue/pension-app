import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/themes/app_theme.dart';
import '../../core/widgets/transicion_carga.dart';

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  final _apiService = ApiService();
  List _productos = [];
  List _categorias = [];
  bool _isLoading = true;
  int _categoriaSeleccionada = 0;
  Map<int, int> _carrito = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    await _apiService.init();
    try {
      final r = await Future.wait([_apiService.get('/products'), _apiService.get('/categories')]);
      final resProd = r[0];
      final resCat = r[1];
      setState(() {
        _productos = resProd.data;
        _categorias = resCat.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List get _productosFiltrados {
    if (_categoriaSeleccionada == 0) return _productos;
    return _productos.where((p) =>
      p['category_id'] == _categorias[_categoriaSeleccionada - 1]['id']
    ).toList();
  }

  int get _totalCarrito => _carrito.values.fold(0, (a, b) => a + b);

  double get _totalPrecio {
    double total = 0;
    _carrito.forEach((productId, cantidad) {
      final producto = _productos.firstWhere((p) => p['id'] == productId);
      total += double.parse(producto['price'].toString()) * cantidad;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menú'),
        actions: [
          if (_carrito.isNotEmpty)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/crear-pedido',
                    arguments: _carrito,
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_totalCarrito',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Cargando()
          : Column(
              children: [
                // Tabs de categorías
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _categorias.length + 1,
                    itemBuilder: (context, index) {
                      final isSelected = _categoriaSeleccionada == index;
                      final label = index == 0 ? 'Todos' : _categorias[index - 1]['name'];
                      return GestureDetector(
                        onTap: () => setState(() => _categoriaSeleccionada = index),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primary : AppTheme.surface,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Center(
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Lista de productos
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _productosFiltrados.length,
                    itemBuilder: (context, index) {
                      final producto = _productosFiltrados[index];
                      final cantidad = _carrito[producto['id']] ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: cantidad > 0
                              ? Border.all(color: AppTheme.primary, width: 2)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.3),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  bottomLeft: Radius.circular(12),
                                ),
                              ),
                              child: const Icon(Icons.fastfood, size: 48, color: AppTheme.primary),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      producto['name'],
                                      style: const TextStyle(
                                        color: AppTheme.textLight,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (producto['description'] != null)
                                      Text(
                                        producto['description'],
                                        style: TextStyle(
                                          color: AppTheme.textLight.withOpacity(0.7),
                                          fontSize: 12,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            'Bs. ${producto['price']}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              onPressed: () => _quitarProducto(producto['id']),
                                              icon: const Icon(Icons.remove_circle, color: Colors.red, size: 28),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '$cantidad',
                                              style: const TextStyle(
                                                color: AppTheme.textLight,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              onPressed: () => _agregarProducto(producto['id']),
                                              icon: const Icon(Icons.add_circle, color: Colors.green, size: 28),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Botón ir al carrito
                if (_carrito.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/crear-pedido',
                          arguments: _carrito,
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'Ver carrito ($_totalCarrito) — Bs. ${_totalPrecio.toStringAsFixed(2)}',
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