import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/piece_node.dart';

/// Cliente del servidor local (servidor/bin/servidor.dart). Existe porque
/// el canvas es Flutter WEB y no puede lanzar el extractor por si mismo --
/// necesita pedirselo a un proceso local que si puede.
class ExtractorClient {
  final String baseUrl;

  const ExtractorClient({this.baseUrl = 'http://127.0.0.1:8799'});

  /// Comprueba si el servidor local responde -- para avisar de entrada
  /// (al abrir el canvas) en vez de que el primer error confuso salga
  /// recien cuando el usuario intenta elegir un archivo. Nunca lanza
  /// excepcion: si algo falla, simplemente devuelve false.
  Future<bool> estaVivo() async {
    try {
      final respuesta = await http.get(Uri.parse('$baseUrl/salud')).timeout(const Duration(seconds: 3));
      return respuesta.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Pide el arbol de [clase] en [archivo] al servidor local. Devuelve
  /// solo los HIJOS del arbol recibido (la raiz que llega es la propia
  /// [clase] otra vez -- no queremos duplicarla, el nodo que se esta
  /// expandiendo ya la representa en el canvas).
  Future<List<PieceNode>> expandir({required String archivo, required String clase}) async {
    final json = await _pedir(archivo: archivo, clase: clase);
    final arbolJson = json['arbol'] as Map<String, dynamic>;
    final nodoRaiz = PieceNode.fromJson(arbolJson, esRaiz: false);
    return nodoRaiz.children;
  }

  /// Carga inicial: pide el arbol completo de [clase] en [archivo] al
  /// servidor local -- reemplaza tener que correr el extractor a mano en
  /// una terminal aparte y pegar el JSON. Devuelve la raiz (esRaiz: true,
  /// siempre abierta) junto con el archivo/clase de origen.
  Future<ArbolCargado> extraerClase({required String archivo, required String clase}) async {
    final json = await _pedir(archivo: archivo, clase: clase);
    final arbolJson = json['arbol'] as Map<String, dynamic>;
    return ArbolCargado(
      raiz: PieceNode.fromJson(arbolJson),
      archivoOrigen: json['archivo'] as String?,
      claseOrigen: json['clase'] as String?,
    );
  }

  Future<Map<String, dynamic>> _pedir({required String archivo, required String clase}) {
    return _get('/extraer', {'archivo': archivo, 'clase': clase});
  }

  /// Lista el contenido de [ruta] (o el home del usuario si es null):
  /// carpetas y archivos .dart. Es la base del explorador de archivos del
  /// canvas -- el navegador no puede saber rutas reales del disco, pero el
  /// servidor local si.
  Future<CarpetaListada> listar({String? ruta}) async {
    final json = await _get('/listar', ruta == null ? {} : {'ruta': ruta});
    return CarpetaListada(
      ruta: json['ruta'] as String,
      padre: json['padre'] as String?,
      entradas: (json['entradas'] as List<dynamic>)
          .map((e) => EntradaCarpeta(
                nombre: (e as Map<String, dynamic>)['nombre'] as String,
                esCarpeta: e['tipo'] == 'carpeta',
                ruta: e['ruta'] as String,
              ))
          .toList(),
    );
  }

  /// Sugiere las clases Widget declaradas en [archivo], para no tener que
  // escribirlas de memoria tras elegirlo en el explorador.
  Future<List<String>> clasesEn(String archivo) async {
    final json = await _get('/clases', {'archivo': archivo});
    return (json['clases'] as List<dynamic>).cast<String>();
  }

  /// Escanea un proyecto Flutter en busca de pantallas y widgets en lib/
  Future<ProyectoEscaneado> escanearProyecto({String? ruta}) async {
    final json = await _get('/escanear_proyecto', ruta == null ? {} : {'ruta': ruta});
    return ProyectoEscaneado.fromJson(json);
  }

  Future<Map<String, dynamic>> _get(String path, Map<String, String> params) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params.isEmpty ? null : params);

    final http.Response respuesta;
    try {
      respuesta = await http.get(uri).timeout(const Duration(seconds: 10));
    } catch (_) {
      throw ExtractorClientException(
        'No se pudo conectar al servidor local en $baseUrl. '
        '¿Está corriendo? (dart run bin/servidor.dart, dentro de servidor/)',
      );
    }

    final json = jsonDecode(respuesta.body) as Map<String, dynamic>;

    if (respuesta.statusCode != 200) {
      throw ExtractorClientException(json['error'] as String? ?? 'Error desconocido del servidor.');
    }

    return json;
  }
}

class CarpetaListada {
  final String ruta;
  final String? padre;
  final List<EntradaCarpeta> entradas;
  CarpetaListada({required this.ruta, required this.padre, required this.entradas});
}

class EntradaCarpeta {
  final String nombre;
  final bool esCarpeta;
  final String ruta;
  EntradaCarpeta({required this.nombre, required this.esCarpeta, required this.ruta});
}

class ArbolCargado {
  final PieceNode raiz;
  final String? archivoOrigen;
  final String? claseOrigen;
  ArbolCargado({required this.raiz, this.archivoOrigen, this.claseOrigen});
}

class ExtractorClientException implements Exception {
  final String mensaje;
  ExtractorClientException(this.mensaje);
  @override
  String toString() => mensaje;
}

class ElementoProyecto {
  final String archivo;
  final String ruta;
  final String nombreArchivo;
  final String clase;
  final bool esPantalla;
  final bool tieneScaffold;

  ElementoProyecto({
    required this.archivo,
    required this.ruta,
    required this.nombreArchivo,
    required this.clase,
    required this.esPantalla,
    required this.tieneScaffold,
  });

  factory ElementoProyecto.fromJson(Map<String, dynamic> json) {
    return ElementoProyecto(
      archivo: json['archivo'] as String,
      ruta: json['ruta'] as String,
      nombreArchivo: json['nombreArchivo'] as String,
      clase: json['clase'] as String,
      esPantalla: json['esPantalla'] as bool? ?? false,
      tieneScaffold: json['tieneScaffold'] as bool? ?? false,
    );
  }
}

class ProyectoEscaneado {
  final String proyecto;
  final String ruta;
  final int totalPantallas;
  final int totalWidgets;
  final List<ElementoProyecto> pantallas;
  final List<ElementoProyecto> widgets;

  ProyectoEscaneado({
    required this.proyecto,
    required this.ruta,
    required this.totalPantallas,
    required this.totalWidgets,
    required this.pantallas,
    required this.widgets,
  });

  factory ProyectoEscaneado.fromJson(Map<String, dynamic> json) {
    return ProyectoEscaneado(
      proyecto: json['proyecto'] as String,
      ruta: json['ruta'] as String,
      totalPantallas: json['totalPantallas'] as int? ?? 0,
      totalWidgets: json['totalWidgets'] as int? ?? 0,
      pantallas: (json['pantallas'] as List<dynamic>?)
              ?.map((e) => ElementoProyecto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      widgets: (json['widgets'] as List<dynamic>?)
              ?.map((e) => ElementoProyecto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
