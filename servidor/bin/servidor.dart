import 'dart:convert';
import 'dart:io';

import 'package:extractor/extractor.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

/// Servidor LOCAL (solo escucha en localhost, nunca en la red) que expone
/// el extractor por HTTP. Existe por una limitacion real: el canvas es
/// Flutter WEB, y un navegador no puede lanzar procesos locales (`dart
/// run`) por si mismo -- este servidor es el puente.
///
/// Uso: el canvas, al tocar "expandir" en un widget propio, llama a
/// `GET /extraer?archivo=RUTA&clase=NOMBRE` y recibe el mismo formato
/// JSON que ya produce `dart run bin/extractor.dart --json`.
void main(List<String> args) async {
  final router = Router();

  router.get('/salud', (Request req) => Response.ok('ok'));

  router.get('/extraer', (Request req) {
    final archivo = req.url.queryParameters['archivo'];
    final clase = req.url.queryParameters['clase'];

    if (archivo == null || clase == null) {
      return Response(400, body: jsonEncode({'error': 'Faltan "archivo" y/o "clase" en la query.'}));
    }

    try {
      final arbol = extraerArbol(filePath: archivo, className: clase);
      final body = jsonEncode({'archivo': archivo, 'clase': clase, 'arbol': arbol.toJson()});
      return Response.ok(body, headers: {'content-type': 'application/json'});
    } on StateError catch (e) {
      return Response(422, body: jsonEncode({'error': e.message}));
    } catch (e) {
      return Response(500, body: jsonEncode({'error': 'Error inesperado: $e'}));
    }
  });

  // Explorador de carpetas: el navegador no puede saber la ruta real de un
  // archivo que el usuario elige (limitacion de seguridad de todo navegador,
  // no de Flutter) -- por eso el "seleccionar archivo" pasa por aqui, que si
  // ve el disco de verdad.
  router.get('/listar', (Request req) {
    final rutaPedida = req.url.queryParameters['ruta'];
    final dir = Directory(rutaPedida ?? Platform.environment['HOME'] ?? '.');

    if (!dir.existsSync()) {
      return Response(404, body: jsonEncode({'error': 'La carpeta no existe: ${dir.path}'}));
    }

    try {
      final entradas = <Map<String, String>>[];
      for (final entidad in dir.listSync().whereType<FileSystemEntity>()) {
        final nombre = entidad.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (nombre.startsWith('.')) continue; // oculta .git, .dart_tool, etc.
        if (entidad is Directory) {
          entradas.add({'nombre': nombre, 'tipo': 'carpeta', 'ruta': entidad.path});
        } else if (entidad is File && nombre.endsWith('.dart')) {
          entradas.add({'nombre': nombre, 'tipo': 'archivo', 'ruta': entidad.path});
        }
      }
      entradas.sort((a, b) {
        if (a['tipo'] != b['tipo']) return a['tipo'] == 'carpeta' ? -1 : 1;
        return a['nombre']!.compareTo(b['nombre']!);
      });

      final padre = dir.parent.path == dir.path ? null : dir.parent.path;
      final body = jsonEncode({'ruta': dir.path, 'padre': padre, 'entradas': entradas});
      return Response.ok(body, headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500, body: jsonEncode({'error': 'No se pudo listar la carpeta: $e'}));
    }
  });

  // Sugiere que clases Widget hay en un archivo, para no tener que
  // escribirlas de memoria tras elegir el archivo en el explorador.
  router.get('/clases', (Request req) {
    final archivo = req.url.queryParameters['archivo'];
    if (archivo == null) {
      return Response(400, body: jsonEncode({'error': 'Falta "archivo" en la query.'}));
    }
    try {
      final clases = clasesWidgetEn(archivo);
      return Response.ok(jsonEncode({'clases': clases}), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500, body: jsonEncode({'error': 'No se pudo analizar el archivo: $e'}));
    }
  });

  // Escanea todo el proyecto Flutter: recorre lib/ recursivamente, detecta
  // clases Widget con el AST y clasifica entre Pantallas y Componentes.
  router.get('/escanear_proyecto', (Request req) {
    final rutaPedida = req.url.queryParameters['ruta'];
    final baseDir = Directory(rutaPedida ?? Platform.environment['HOME'] ?? '.');
    if (!baseDir.existsSync()) {
      return Response(404, body: jsonEncode({'error': 'La ruta no existe: ${baseDir.path}'}));
    }

    try {
      Directory proyectoDir = baseDir;
      final libDirs = <Directory>[];

      // 1. ¿Es la carpeta lib directamente?
      if (baseDir.path.endsWith('/lib') || baseDir.path.endsWith('\\lib')) {
        libDirs.add(baseDir);
        proyectoDir = baseDir.parent;
      }
      // 2. ¿Tiene una carpeta lib/ dentro?
      else if (Directory('${baseDir.path}/lib').existsSync()) {
        libDirs.add(Directory('${baseDir.path}/lib'));
        proyectoDir = baseDir;
      }
      // 3. ¿Tiene subcarpetas con lib/ (ej. canvas/lib, app/lib)?
      else {
        for (final sub in baseDir.listSync().whereType<Directory>()) {
          final subLib = Directory('${sub.path}/lib');
          if (subLib.existsSync()) {
            libDirs.add(subLib);
          }
        }
      }

      if (libDirs.isEmpty) {
        return Response(404, body: jsonEncode({
          'error': 'No se encontró carpeta "lib/" en ${baseDir.path}. Asegúrate de seleccionar la raíz de un proyecto Flutter.'
        }));
      }

      final pantallas = <Map<String, dynamic>>[];
      final widgets = <Map<String, dynamic>>[];

      for (final libDir in libDirs) {
        for (final entity in libDir.listSync(recursive: true).whereType<File>()) {
          final path = entity.path;
          if (!path.endsWith('.dart')) continue;
          if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) continue;

          try {
            final clases = clasesWidgetEn(path);
            if (clases.isEmpty) continue;

            final relativo = path.startsWith(proyectoDir.path)
                ? path.substring(proyectoDir.path.length + 1)
                : path;

            final contenido = entity.readAsStringSync();
            final nombreArchivo = entity.uri.pathSegments.last;

            for (final clase in clases) {
              final esPrivada = clase.startsWith('_');
              bool tieneScaffold = false;
              final idx = contenido.indexOf('class $clase');
              if (idx != -1) {
                final nextClass = contenido.indexOf('\nclass ', idx + 1);
                final block = nextClass == -1 ? contenido.substring(idx) : contenido.substring(idx, nextClass);
                tieneScaffold = block.contains('Scaffold(');
              }

              final esPantalla = !esPrivada && (tieneScaffold ||
                  clase.endsWith('Screen') ||
                  clase.endsWith('Page') ||
                  clase.endsWith('View') ||
                  clase.endsWith('Canvas') ||
                  relativo.contains('/screens/') ||
                  relativo.contains('/pages/') ||
                  relativo.contains('/views/'));

              final item = {
                'archivo': relativo,
                'ruta': path,
                'nombreArchivo': nombreArchivo,
                'clase': clase,
                'esPantalla': esPantalla,
                'tieneScaffold': tieneScaffold,
              };

              if (esPantalla) {
                pantallas.add(item);
              } else {
                widgets.add(item);
              }
            }
          } catch (_) {
            // Ignora archivos que no puedan parsearse
          }
        }
      }

      final nombreProyecto = proyectoDir.uri.pathSegments.where((s) => s.isNotEmpty).last;

      final body = jsonEncode({
        'proyecto': nombreProyecto,
        'ruta': proyectoDir.path,
        'totalPantallas': pantallas.length,
        'totalWidgets': widgets.length,
        'pantallas': pantallas,
        'widgets': widgets,
      });

      return Response.ok(body, headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500, body: jsonEncode({'error': 'Error al escanear proyecto: $e'}));
    }
  });

  // Guardar boceto de sesión visual en la carpeta .awc/ del proyecto
  router.post('/guardar_boceto', (Request req) async {
    try {
      final payload = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final rutaProyecto = payload['proyecto'] as String?;
      final nombre = payload['nombre'] as String? ?? 'boceto';
      final datos = payload['datos'] as Map<String, dynamic>?;

      if (rutaProyecto == null || datos == null) {
        return Response(400, body: jsonEncode({'error': 'Faltan "proyecto" o "datos" en la solicitud.'}));
      }

      final awcDir = Directory('$rutaProyecto/.awc');
      if (!awcDir.existsSync()) {
        awcDir.createSync(recursive: true);
      }

      final nombreLimpio = nombre.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final archivo = File('${awcDir.path}/$nombreLimpio.awc.json');
      archivo.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(datos));

      return Response.ok(jsonEncode({
        'ok': true,
        'ruta': archivo.path,
        'nombre': '$nombreLimpio.awc.json',
      }), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500, body: jsonEncode({'error': 'No se pudo guardar el boceto: $e'}));
    }
  });

  // Listar bocetos guardados en .awc/ del proyecto
  router.get('/listar_bocetos', (Request req) {
    final rutaProyecto = req.url.queryParameters['proyecto'];
    if (rutaProyecto == null) {
      return Response(400, body: jsonEncode({'error': 'Falta "proyecto" en la query.'}));
    }

    final awcDir = Directory('$rutaProyecto/.awc');
    if (!awcDir.existsSync()) {
      return Response.ok(jsonEncode({'bocetos': []}), headers: {'content-type': 'application/json'});
    }

    try {
      final bocetos = <Map<String, dynamic>>[];
      for (final f in awcDir.listSync().whereType<File>()) {
        if (f.path.endsWith('.awc.json')) {
          final nombre = f.uri.pathSegments.last;
          bocetos.add({
            'nombre': nombre,
            'ruta': f.path,
            'modificado': f.lastModifiedSync().toIso8601String(),
            'tamanio': f.lengthSync(),
          });
        }
      }
      bocetos.sort((a, b) => (b['modificado'] as String).compareTo(a['modificado'] as String));
      return Response.ok(jsonEncode({'bocetos': bocetos}), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500, body: jsonEncode({'error': 'Error al listar bocetos: $e'}));
    }
  });

  // Cargar un boceto guardado
  router.get('/cargar_boceto', (Request req) {
    final rutaArchivo = req.url.queryParameters['ruta'];
    if (rutaArchivo == null) {
      return Response(400, body: jsonEncode({'error': 'Falta "ruta" en la query.'}));
    }

    final archivo = File(rutaArchivo);
    if (!archivo.existsSync()) {
      return Response(404, body: jsonEncode({'error': 'El archivo de boceto no existe.'}));
    }

    try {
      final contenido = archivo.readAsStringSync();
      return Response.ok(contenido, headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500, body: jsonEncode({'error': 'Error al leer el boceto: $e'}));
    }
  });

  // CORS: el canvas (Flutter Web) corre en otro puerto/origen durante
  // desarrollo -- sin esto el navegador bloquea la llamada.
  final handler = const Pipeline().addMiddleware(_cors()).addHandler(router.call);

  const puerto = 8799;
  final server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, puerto);
  stdout.writeln('Servidor local del extractor escuchando en http://${server.address.host}:${server.port}');
  stdout.writeln('Solo accesible desde esta maquina (loopback) -- nunca expuesto a la red.');
}

Middleware _cors() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      final response = await innerHandler(request);
      return response.change(headers: _corsHeaders);
    };
  };
}

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};
