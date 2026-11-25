import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/themes/app_theme.dart';
import '../../core/utils/auditoria.dart';
import '../../core/utils/avisos.dart';
import '../../core/widgets/transicion_carga.dart';

/// Auditoría (solo administrador): quién hizo qué y cuándo. Inicios de sesión,
/// pedidos, cobros, comensales registrados, gestión y fidelización manual.
/// Lo más reciente primero; se filtra por categoría y se cargan más al bajar.
class AuditoriaScreen extends StatefulWidget {
  const AuditoriaScreen({super.key});

  @override
  State<AuditoriaScreen> createState() => _AuditoriaScreenState();
}

const _iconos = {
  'sesion': Icons.login,
  'pedido': Icons.receipt_long,
  'cobro': Icons.payments,
  'usuario': Icons.person_add,
  'gestion': Icons.settings,
  'fidelizacion': Icons.emoji_events,
};

/// Acciones que conviene resaltar (pueden indicar un problema).
const _alertas = {'sesion.fallida', 'sesion.bloqueada', 'pedido.cancelado', 'pedido.eliminado', 'cobro.rechazado', 'cobro.eliminado'};

class _AuditoriaScreenState extends State<AuditoriaScreen> {
  final _api = ApiService();
  final _scroll = ScrollController();
  Map<String, String> _categorias = {};
  String? _categoria;   // null = todas
  final List<Map> _registros = [];
  int _pagina = 0;
  int _ultimaPagina = 1;
  int _total = 0;
  bool _cargando = true;
  bool _cargandoMas = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _cargarMas();
    });
    _cargar();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String get _filtro => _categoria == null ? '' : '&categoria=$_categoria';

  Future<void> _cargar() async {
    setState(() => _cargando = _registros.isEmpty);
    try {
      await _api.init();
      final r = await _api.get('/auditoria?page=1$_filtro');
      final datos = r.data as Map;
      if (!mounted) return;
      setState(() {
        _categorias = Map<String, String>.from(datos['categorias'] ?? {});
        _registros
          ..clear()
          ..addAll((datos['registros'] as List).cast<Map>());
        _pagina = datos['pagina'] ?? 1;
        _ultimaPagina = datos['ultima_pagina'] ?? 1;
        _total = datos['total'] ?? _registros.length;
        _error = null;
        _cargando = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = mensajeDeError(e, 'No se pudo cargar la auditoría'); _cargando = false; });
    }
  }

  Future<void> _cargarMas() async {
    if (_cargandoMas || _cargando || _pagina >= _ultimaPagina) return;
    setState(() => _cargandoMas = true);
    try {
      final r = await _api.get('/auditoria?page=${_pagina + 1}$_filtro');
      final datos = r.data as Map;
      if (!mounted) return;
      setState(() {
        _registros.addAll((datos['registros'] as List).cast<Map>());
        _pagina = datos['pagina'] ?? _pagina + 1;
        _ultimaPagina = datos['ultima_pagina'] ?? _ultimaPagina;
        _cargandoMas = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _cargandoMas = false);
        avisar(context, mensajeDeError(e, 'No se pudieron cargar más registros'), error: true);
      }
    }
  }

  void _elegir(String? categoria) {
    if (categoria == _categoria) return;
    setState(() {
      _categoria = categoria;
      _registros.clear();
      _cargando = true;
    });
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auditoría')),
      body: Column(
        children: [
          _filtros(),
          Expanded(
            child: _cargando
                ? const Cargando()
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                        ),
                      )
                    : RefreshIndicator(onRefresh: _cargar, child: _lista()),
          ),
        ],
      ),
    );
  }

  Widget _filtros() {
    final opciones = <String?, String>{null: 'Todo', ..._categorias};
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: opciones.entries.map((o) {
          final elegido = o.key == _categoria;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(o.value),
              selected: elegido,
              onSelected: (_) => _elegir(o.key),
              selectedColor: AppTheme.primary,
              backgroundColor: AppTheme.surface,
              labelStyle: TextStyle(color: elegido ? Colors.white : AppTheme.textLight),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _lista() {
    if (_registros.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 80),
        Center(child: Text('Todavía no hay acciones registradas', style: TextStyle(color: Colors.white54))),
      ]);
    }

    // Encabezado por día («Hoy», «Ayer», 24/11/2026) y las acciones de ese día.
    final ahora = DateTime.now();
    final filas = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
        child: Text(_total == 1 ? '1 acción' : '$_total acciones',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ),
    ];
    String? diaAnterior;
    for (final r in _registros) {
      final fecha = fechaLocal(r['created_at']);
      final dia = fecha == null ? '—' : etiquetaDia(fecha, ahora);
      if (dia != diaAnterior) {
        filas.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
          child: Text(dia, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 15)),
        ));
        diaAnterior = dia;
      }
      filas.add(_tarjeta(r, fecha));
    }
    if (_cargandoMas) {
      filas.add(const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      ));
    } else if (_pagina >= _ultimaPagina) {
      filas.add(const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('No hay más registros', style: TextStyle(color: Colors.white38, fontSize: 12))),
      ));
    }
    return ListView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: filas,
    );
  }

  Widget _tarjeta(Map r, DateTime? fecha) {
    final accion = '${r['action']}';
    final alerta = _alertas.contains(accion);
    final color = alerta ? Colors.redAccent : AppTheme.accent;
    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: alerta ? const BorderSide(color: Colors.redAccent, width: 1) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.18),
              child: Icon(_iconos[categoriaDe(accion)] ?? Icons.history, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${r['description']}', style: const TextStyle(color: AppTheme.textLight, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(autorDe(r), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(fecha == null ? '' : horaCorta(fecha), style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
