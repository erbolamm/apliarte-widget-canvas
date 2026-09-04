import 'dart:convert';
import 'dart:typed_data';

import 'piece_node.dart';

/// Modelo para persistir y restaurar una sesión de diseño visual (boceto) en Apliarte Widget Canvas.
/// Permite guardar widgets, anotaciones, captura de pantalla y metadatos para recuperarlos más tarde.
class BocetoSesion {
  final String version;
  final String? archivoOrigen;
  final String? claseOrigen;
  final PieceNode raiz;
  final Uint8List? capturaFondoBytes;
  final double opacidadCaptura;
  final bool fondoDispositivoBlanco;
  final DateTime fechaCreacion;
  final String? nota;

  BocetoSesion({
    this.version = '1.0',
    this.archivoOrigen,
    this.claseOrigen,
    required this.raiz,
    this.capturaFondoBytes,
    this.opacidadCaptura = 0.85,
    this.fondoDispositivoBlanco = true,
    DateTime? fechaCreacion,
    this.nota,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'archivoOrigen': archivoOrigen,
      'claseOrigen': claseOrigen,
      'raiz': raiz.toJson(),
      'capturaFondoBase64': capturaFondoBytes != null ? base64Encode(capturaFondoBytes!) : null,
      'opacidadCaptura': opacidadCaptura,
      'fondoDispositivoBlanco': fondoDispositivoBlanco,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'nota': nota,
    };
  }

  factory BocetoSesion.fromJson(Map<String, dynamic> json) {
    Uint8List? bytes;
    final b64 = json['capturaFondoBase64'] as String?;
    if (b64 != null && b64.isNotEmpty) {
      try {
        bytes = base64Decode(b64);
      } catch (_) {}
    }

    final raizJson = json['raiz'] as Map<String, dynamic>? ?? {'type': 'Pantalla', 'propio': true, 'children': []};
    final raizNode = PieceNode.fromJson(raizJson);

    DateTime fecha = DateTime.now();
    if (json['fechaCreacion'] is String) {
      try {
        fecha = DateTime.parse(json['fechaCreacion'] as String);
      } catch (_) {}
    }

    return BocetoSesion(
      version: json['version'] as String? ?? '1.0',
      archivoOrigen: json['archivoOrigen'] as String?,
      claseOrigen: json['claseOrigen'] as String?,
      raiz: raizNode,
      capturaFondoBytes: bytes,
      opacidadCaptura: (json['opacidadCaptura'] as num?)?.toDouble() ?? 0.85,
      fondoDispositivoBlanco: json['fondoDispositivoBlanco'] as bool? ?? true,
      fechaCreacion: fecha,
      nota: json['nota'] as String?,
    );
  }

  String toJsonString() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  factory BocetoSesion.fromJsonString(String str) {
    final map = jsonDecode(str) as Map<String, dynamic>;
    return BocetoSesion.fromJson(map);
  }
}
