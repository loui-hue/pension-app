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
  // Menú del día de toda la semana, para consultar otros días (solo se pide el de hoy).
  List _menuSemana = [];
  int? _diaVisto;   // 1 = lunes … 6 = sábado; null = hoy

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    await _apiService.init();
    try {
      final r = await Future.wait([
        _apiService.get('/products'),
        _apiService.get('/categories'),
        _apiService.get('/products/menu-semana'),
      ]);
      final resProd = r[0];
      final resCat = r[1];
      setState(() {
        _productos = resProd.data;
        _categorias = resCat.data;
        _menuSemana = r[2].data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  int get _hoy => DateTime.now().weekday;   // 1 = lunes … 7 = domingo

  /// En Menú del día, mirando otro día: se muestra para consultar, sin poder pedirlo.
  bool get _soloVer => _esMenuDelDia && _diaVisto != null && _diaVisto != _hoy;

  List get _productosFiltrados {
    if (_soloVer) return _menuSemana.where((p) => p['day_of_week'] == _diaVisto).toList();
    if (_categoriaSeleccionada == 0) return _productos;
    return _productos.where((p) =>
      p['category_id'] == _categorias[_categoriaSeleccionada - 1]['id']
    ).toList();
  }

  bool get _esMenuDelDia =>
      _categoriaSeleccionada > 0 && _categorias[_categoriaSeleccionada - 1]['name'] == 'Menú del día';

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

  /// Lista de lunes a sábado para ver el menú de otro día.
  Future<void> _elegirDia() async {
    final elegido = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Menú del día de la semana',
                  style: TextStyle(color: AppTheme.accent, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            for (var dia = 1; dia <= 6; dia++)
              ListTile(
                leading: Icon(
                  dia == (_diaVisto ?? _hoy) ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: AppTheme.primary,
                ),
                title: Text(
                  _AvisoMenuDelDia.capitalizar(_AvisoMenuDelDia.dias[dia - 1]) + (dia == _hoy ? '  (hoy)' : ''),
                  style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _menuSemana.where((p) => p['day_of_week'] == dia).map((p) => p['name']).join(' · '),
                  style: TextStyle(color: AppTheme.textLight.withValues(alpha: 0.6), fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(context, dia),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (elegido != null) setState(() => _diaVisto = elegido == _hoy ? null : elegido);
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
                if (_esMenuDelDia)
                  _AvisoMenuDelDia(
                    dia: _diaVisto ?? _hoy,
                    esHoy: !_soloVer,
                    hayMenu: _productosFiltrados.isNotEmpty,
                    onTap: _elegirDia,
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
                                        if (_soloVer)
                                          Text(
                                            'Se pide el ${_AvisoMenuDelDia.dias[_diaVisto! - 1]}',
                                            style: const TextStyle(color: AppTheme.accent, fontSize: 12),
                                          )
                                        else
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
/// Encabezado de la pestaña Menú del día. Es un botón: abre la lista de lunes a
/// sábado para consultar el menú de otro día (solo se puede pedir el de hoy).
class _AvisoMenuDelDia extends StatelessWidget {
  final int dia; // 1 = lunes … 7 = domingo
  final bool esHoy;
  final bool hayMenu;
  final VoidCallback onTap;
  const _AvisoMenuDelDia({required this.dia, required this.esHoy, required this.hayMenu, required this.onTap});

  static const dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  static String capitalizar(String t) => t[0].toUpperCase() + t.substring(1);

  @override
  Widget build(BuildContext context) {
    final nombre = dias[dia - 1];
    final String titulo;
    final String detalle;
    if (!esHoy) {
      titulo = 'Menú del $nombre';
      detalle = 'Solo para consultar: se pide el $nombre. Toca para ver otro día.';
    } else if (hayMenu) {
      titulo = 'Menú del $nombre (hoy)';
      detalle = 'Toca para ver el menú de otros días';
    } else {
      titulo = 'Hoy $nombre no hay menú del día';
      detalle = 'La pensión atiende de lunes a sábado. Toca para ver el menú de la semana.';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Material(
        color: AppTheme.primary.withValues(alpha: esHoy ? 0.18 : 0.30),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: AppTheme.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(detalle, style: TextStyle(color: AppTheme.textLight.withValues(alpha: 0.7), fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.expand_more, color: AppTheme.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
