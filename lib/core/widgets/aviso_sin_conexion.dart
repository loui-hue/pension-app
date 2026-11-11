import 'package:flutter/material.dart';
import '../services/cache_service.dart';

/// Franja que avisa que se están mostrando datos guardados en el celular
/// porque no hay conexión con el servidor de la pensión.
class AvisoSinConexion extends StatelessWidget {
  final DateTime desde;
  final VoidCallback? onReintentar;
  const AvisoSinConexion({super.key, required this.desde, this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF6D4C41),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, color: Color(0xFFFFB74D), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sin conexión. Datos guardados ${CacheService.describirFecha(desde)}.',
                style: const TextStyle(color: Color(0xFFF5E6C8), fontSize: 13),
              ),
            ),
            if (onReintentar != null)
              TextButton(
                onPressed: onReintentar,
                child: const Text('Reintentar', style: TextStyle(color: Color(0xFFFFB74D))),
              ),
          ],
        ),
      ),
    );
  }
}
