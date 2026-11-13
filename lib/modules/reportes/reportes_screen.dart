import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/themes/app_theme.dart';
import '../../core/widgets/transicion_carga.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  final _apiService = ApiService();
  Map? _reporte;
  bool _isLoading = true;
  String? _error;

  // Periodo seleccionado: días hacia atrás desde hoy (0 = solo hoy).
  static const _periodos = {'Hoy': 0, '7 días': 6, '30 días': 29};
  String _periodo = '7 días';
  DateTimeRange? _rangoPersonalizado;

  @override
  void initState() {
    super.initState();
    _cargarReporte();
  }

  String _fecha(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Reportes ya consultados en esta visita, por rango: al volver a un periodo se
  // muestra al instante mientras se actualiza.
  final Map<String, Map> _porRango = {};
  bool _actualizando = false;

  Future<void> _cargarReporte() async {
    final hoy = DateTime.now();
    final desde = _rangoPersonalizado?.start ?? hoy.subtract(Duration(days: _periodos[_periodo]!));
    final hasta = _rangoPersonalizado?.end ?? hoy;
    final clave = '${_fecha(desde)}_${_fecha(hasta)}';

    // Si ya hay algo en pantalla se mantiene y solo aparece la barra fina arriba
    // (antes la pantalla se vaciaba en cada cambio de periodo: el destello).
    setState(() {
      _error = null;
      if (_porRango[clave] != null) _reporte = _porRango[clave];
      if (_reporte != null) {
        _actualizando = true;
      } else {
        _isLoading = true;
      }
    });
    await _apiService.init();

    try {
      final res = await _apiService.get('/reports/dashboard?from=${_fecha(desde)}&to=${_fecha(hasta)}');
      if (!mounted) return;
      _porRango[clave] = res.data;
      setState(() {
        _reporte = res.data;
        _isLoading = false;
        _actualizando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_reporte == null) {
          _error = e is DioException && e.response?.data is Map
              ? e.response!.data['message'] ?? 'No se pudo cargar el reporte'
              : 'No se pudo cargar el reporte';
        }
        _isLoading = false;
        _actualizando = false;
      });
    }
  }

  Future<void> _elegirRango() async {
    final hoy = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(hoy.year - 2),
      lastDate: hoy,
      initialDateRange: _rangoPersonalizado,
    );
    if (rango != null) {
      setState(() {
        _rangoPersonalizado = rango;
        _periodo = '';
      });
      _cargarReporte();
    }
  }

  double _num(dynamic v) => double.tryParse(v.toString()) ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarReporte),
        ],
      ),
      body: Column(
        children: [
          _buildSelectorPeriodo(),
          BarraActualizando(activa: _actualizando),
          Expanded(
            child: _isLoading
                ? const Cargando()
                : _error != null
                    ? Center(
                        child: Text(_error!, style: const TextStyle(color: Colors.white70)),
                      )
                    : RefreshIndicator(
                        onRefresh: _cargarReporte,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildResumen(),
                            const SizedBox(height: 20),
                            _buildVentasPorDia(),
                            const SizedBox(height: 20),
                            _buildTopProductos(),
                            const SizedBox(height: 20),
                            _buildVisitas(),
                            const SizedBox(height: 20),
                            _buildFidelizacion(),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorPeriodo() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ..._periodos.keys.map((p) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(p),
                    selected: _periodo == p,
                    selectedColor: AppTheme.primary,
                    onSelected: (_) {
                      setState(() {
                        _periodo = p;
                        _rangoPersonalizado = null;
                      });
                      _cargarReporte();
                    },
                  ),
                )),
            ActionChip(
              avatar: const Icon(Icons.date_range, size: 18, color: AppTheme.accent),
              label: Text(_rangoPersonalizado == null
                  ? 'Rango…'
                  : '${_fecha(_rangoPersonalizado!.start)} a ${_fecha(_rangoPersonalizado!.end)}'),
              backgroundColor: _rangoPersonalizado != null ? AppTheme.primary : null,
              onPressed: _elegirRango,
            ),
          ],
        ),
      ),
    );
  }

  Widget _titulo(String texto, IconData icono) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icono, color: AppTheme.accent, size: 20),
          const SizedBox(width: 8),
          Text(
            texto,
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(String etiqueta, String valor, IconData icono) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: AppTheme.primary, size: 22),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: const TextStyle(
                color: AppTheme.textLight,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            etiqueta,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.2),
          ),
        ],
      ),
    );
  }

  // Tarjetas de dos en dos; cada fila toma el alto de su tarjeta más alta,
  // así el contenido nunca se desborda (aunque el usuario agrande la letra).
  Widget _grid(List<Widget> tarjetas) {
    final filas = <Widget>[];
    for (var i = 0; i < tarjetas.length; i += 2) {
      if (i > 0) filas.add(const SizedBox(height: 12));
      filas.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: tarjetas[i]),
            const SizedBox(width: 12),
            Expanded(child: i + 1 < tarjetas.length ? tarjetas[i + 1] : const SizedBox()),
          ],
        ),
      ));
    }
    return Column(children: filas);
  }

  Widget _buildResumen() {
    final s = _reporte!['summary'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo('Pedidos y ventas', Icons.receipt_long),
        _grid([
          _tarjeta('Ventas (pagado)', 'Bs. ${_num(s['sales']).toStringAsFixed(2)}', Icons.payments),
          _tarjeta('Pedidos', '${s['orders']}', Icons.receipt),
          _tarjeta('Ticket promedio', 'Bs. ${_num(s['average_ticket']).toStringAsFixed(2)}', Icons.calculate),
          _tarjeta('Cancelados', '${s['cancelled_orders']}', Icons.cancel),
        ]),
      ],
    );
  }

  Widget _buildVentasPorDia() {
    final dias = _reporte!['sales_by_day'] as List;
    final maximo = dias.fold<double>(0, (m, d) => _num(d['sales']) > m ? _num(d['sales']) : m);
    // Con muchos días se muestran barras más delgadas y solo algunas etiquetas.
    final ancho = dias.length <= 7 ? 32.0 : 14.0;
    final cadaEtiqueta = dias.length <= 7 ? 1 : (dias.length / 6).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo('Ventas por día (Bs.)', Icons.bar_chart),
        Container(
          height: 200,
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: maximo == 0
              ? const Center(
                  child: Text('Sin ventas en el periodo', style: TextStyle(color: Colors.white54)),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(dias.length, (i) {
                    final d = dias[i];
                    final venta = _num(d['sales']);
                    final fecha = d['date'].toString();
                    return Tooltip(
                      message: '$fecha\nBs. ${venta.toStringAsFixed(2)} · ${d['orders']} pedidos',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: ancho,
                            height: 130 * (venta / maximo),
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 14,
                            child: Text(
                              i % cadaEtiqueta == 0 ? fecha.substring(8) : '',
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
        ),
      ],
    );
  }

  Widget _filaConBarra(String nombre, String detalle, double proporcion) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nombre,
                  style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(detalle, style: const TextStyle(color: AppTheme.accent, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: proporcion,
              minHeight: 8,
              backgroundColor: Colors.white10,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenedor(Widget child) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }

  Widget _buildTopProductos() {
    final productos = _reporte!['top_products'] as List;
    final maximo = productos.isEmpty ? 1.0 : _num(productos.first['quantity']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo('Productos más vendidos', Icons.restaurant_menu),
        _contenedor(
          productos.isEmpty
              ? const Text('Sin ventas en el periodo', style: TextStyle(color: Colors.white54))
              : Column(
                  children: productos
                      .map((p) => _filaConBarra(
                            p['name'],
                            '${p['quantity']} u. · Bs. ${_num(p['revenue']).toStringAsFixed(2)}',
                            _num(p['quantity']) / maximo,
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildVisitas() {
    final v = _reporte!['visits'];
    final frecuentes = v['frequent_diners'] as List;
    final maximo = frecuentes.isEmpty ? 1.0 : _num(frecuentes.first['visits']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo('Frecuencia de visitas', Icons.people),
        _grid([
          _tarjeta('Comensales atendidos', '${v['unique_diners']}', Icons.person),
          _tarjeta('Visitas promedio', _num(v['average_per_diner']).toStringAsFixed(1), Icons.repeat),
        ]),
        if (frecuentes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _contenedor(
            Column(
              children: frecuentes
                  .map((c) => _filaConBarra(
                        c['name'],
                        '${c['visits']} visitas',
                        _num(c['visits']) / maximo,
                      ))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFidelizacion() {
    final l = _reporte!['loyalty'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo('Programa de fidelización', Icons.star),
        _contenedor(
          _filaConBarra(
            'Participación',
            '${l['participants']} de ${l['registered_diners']} comensales (${_num(l['participation_rate']).toStringAsFixed(1)} %)',
            _num(l['participation_rate']) / 100,
          ),
        ),
        const SizedBox(height: 12),
        _grid([
          _tarjeta('XP otorgado', '${l['xp_awarded']}', Icons.bolt),
          _tarjeta('Insignias obtenidas', '${l['badges_awarded']}', Icons.military_tech),
          _tarjeta('Rachas activas', '${l['active_streaks']}', Icons.local_fire_department),
        ]),
      ],
    );
  }
}
