import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/piece_node.dart';
import 'app_logger.dart';

enum ProveedorIA {
  groq('Groq (Recomendado - Ultra rápido)', 'llama-3.3-70b-versatile'),
  openai('OpenAI', 'gpt-4o'),
  anthropic('Anthropic Claude', 'claude-3-5-sonnet-20241022'),
  gemini('Google Gemini', 'gemini-2.0-flash'),
  personalizado('Endpoint personalizado (OpenAI compatible)', 'custom');

  final String nombre;
  final String modeloPorDefecto;
  const ProveedorIA(this.nombre, this.modeloPorDefecto);
}

/// Servicio multi-proveedor de Inteligencia Artificial para el Canvas.
/// Soporta Groq por defecto para latencia ultra-baja y traducción a código Flutter nativo.
class AiService {
  static final AiService instance = AiService._();
  AiService._();

  ProveedorIA proveedor = ProveedorIA.groq;
  String modelo = ProveedorIA.groq.modeloPorDefecto;
  String apiKey = '';
  String customUrl = '';

  bool get estaConfigurado => apiKey.trim().isNotEmpty;

  /// Genera código Flutter nativo limpio para una pieza concreta según sus propiedades visuales y notas de comportamiento.
  Future<String> generarCodigoParaPieza({
    required PieceNode pieza,
    PieceNode? raizArbol,
    String? instruccionUsuario,
  }) async {
    if (!estaConfigurado) {
      throw Exception('Falta la API Key de ${proveedor.nombre}. Por favor, configúrala en el panel de IA.');
    }

    final promptSistema = '''
Eres un Arquitecto Senior Flutter con más de 15 años de experiencia y Google Developer Expert.
Tu objetivo es traducir bocetos y especificaciones visuales de componentes de canvas a código Flutter nativo de producción.
Reglas estrictas:
1. Usa Clean Architecture y Material 3 Expressive.
2. Si se solicitan propiedades no estándar, tradúcelas a la combinación idiomática correcta de widgets oficiales de Flutter (ej. Container con BoxDecoration, ListTile, Card, ElevatedButton, etc.).
3. Incluye soporte de colores, bordes redondeados, iconos, textos y lógica de comportamiento solicitada.
4. Devuelve ÚNICAMENTE el código Dart dentro de un bloque ```dart ... ```, sin saludos ni explicaciones obvias.
''';

    final promptUsuario = StringBuffer();
    promptUsuario.writeln('Genera el widget Flutter para este componente diseñado en el canvas:');
    promptUsuario.writeln('- Tipo de widget base: ${pieza.type}');
    if (pieza.texto != null && pieza.texto!.isNotEmpty) {
      promptUsuario.writeln('- Texto principal: "${pieza.texto}"');
    } else if (pieza.argumento != null) {
      promptUsuario.writeln('- Texto/argumento original: "${pieza.argumento}"');
    }
    if (pieza.subtexto != null && pieza.subtexto!.isNotEmpty) {
      promptUsuario.writeln('- Subtítulo/texto secundario: "${pieza.subtexto}"');
    }
    if (pieza.colorFondoHex != null) {
      promptUsuario.writeln('- Color de fondo (hex): ${pieza.colorFondoHex}');
    }
    if (pieza.colorIconoHex != null) {
      promptUsuario.writeln('- Color de icono/acento: ${pieza.colorIconoHex}');
    }
    if (pieza.customWidth != null) {
      promptUsuario.writeln('- Ancho solicitado: ${pieza.customWidth} px');
    }
    if (pieza.borderRadius != null) {
      promptUsuario.writeln('- Radio de borde (BorderRadius): ${pieza.borderRadius} px');
    }
    if (pieza.iconLeading != null) {
      promptUsuario.writeln('- Icono inicial (Leading): ${pieza.iconLeading}');
    }
    if (pieza.iconTrailing != null) {
      promptUsuario.writeln('- Icono final (Trailing): ${pieza.iconTrailing}');
    }
    if (pieza.tapAction != null && pieza.tapAction != 'none') {
      promptUsuario.writeln('- Acción al pulsar (Tap): ${pieza.tapAction}');
    }
    if (pieza.behaviorNote != null && pieza.behaviorNote!.trim().isNotEmpty) {
      promptUsuario.writeln('- Comportamiento e intención técnica: "${pieza.behaviorNote!.trim()}"');
    }
    if (instruccionUsuario != null && instruccionUsuario.trim().isNotEmpty) {
      promptUsuario.writeln('- Instrucción específica del desarrollador: "${instruccionUsuario.trim()}"');
    }
    if (raizArbol != null) {
      promptUsuario.writeln('- Contexto de la pantalla padre: ${raizArbol.nombreCompleto}');
    }

    return _llamarModelo(
      sistema: promptSistema,
      usuario: promptUsuario.toString(),
    );
  }

  /// Genera la implementación de código Flutter completa para toda la pantalla
  /// a partir del prompt quirúrgico exportado del canvas.
  Future<String> generarCodigoParaPantalla({
    required String promptExportado,
    String? instruccionUsuario,
  }) async {
    if (!estaConfigurado) {
      throw Exception('Falta la API Key de ${proveedor.nombre}. Por favor, configúrala en el panel de IA.');
    }

    final promptSistema = '''
Eres un Arquitecto Senior Flutter con más de 15 años de experiencia y Google Developer Expert.
Recibes una especificación visual exacta de una pantalla o vista Flutter (incluyendo archivo origen, widgets agregados, pasos de anotación numerados y cambios solicitados).
Tu objetivo es escribir el código Flutter nativo de producción completo o las modificaciones exactas solicitadas.
Reglas:
1. Sigue Clean Architecture estricta y Material 3 Expressive.
2. Integra los widgets nuevos exactamente en las posiciones y con los estilos definidos en las anotaciones.
3. Respeta la estructura de imports y componentes existentes en el archivo destino.
4. Devuelve el código Dart en un bloque ```dart ... ``` listo para copiar y pegar en el archivo destino.
''';

    final promptUsuario = StringBuffer();
    promptUsuario.writeln('Especificación y anotaciones de la pantalla:');
    promptUsuario.writeln(promptExportado);
    if (instruccionUsuario != null && instruccionUsuario.trim().isNotEmpty) {
      promptUsuario.writeln();
      promptUsuario.writeln('Instrucción adicional del desarrollador:');
      promptUsuario.writeln(instruccionUsuario.trim());
    }

    return _llamarModelo(
      sistema: promptSistema,
      usuario: promptUsuario.toString(),
    );
  }

  /// Refina y enriquece el prompt para usarlo con un agente de código externo
  /// (Cursor, Claude Code, Antigravity, Copilot).
  Future<String> refinarPromptConIA({
    required String promptExportado,
    String? instruccionUsuario,
  }) async {
    if (!estaConfigurado) {
      throw Exception('Falta la API Key de ${proveedor.nombre}. Por favor, configúrala en el panel de IA.');
    }

    final promptSistema = '''
Eres un Ingeniero Principal de Prompting especializado en desarrollo Flutter y agentes de código autónomos.
Tu objetivo es tomar un prompt de especificación visual de un canvas de Flutter y transformarlo en el mejor prompt posible para un agente de IA: ultra preciso, con tareas atómicas, pasos numerados, contratos de widgets y advertencias de no romper lógica de negocio existente.
Devuelve el prompt optimizado en formato Markdown.
''';

    final promptUsuario = StringBuffer();
    promptUsuario.writeln('Prompt base exportado del canvas:');
    promptUsuario.writeln(promptExportado);
    if (instruccionUsuario != null && instruccionUsuario.trim().isNotEmpty) {
      promptUsuario.writeln();
      promptUsuario.writeln('Enfoque deseado por el desarrollador:');
      promptUsuario.writeln(instruccionUsuario.trim());
    }

    return _llamarModelo(
      sistema: promptSistema,
      usuario: promptUsuario.toString(),
    );
  }

  /// Llama a la API correspondiente según el proveedor configurado.
  Future<String> _llamarModelo({
    required String sistema,
    required String usuario,
  }) async {
    AppLogger.i('Llamando a modelo IA con proveedor ${proveedor.name} ($modelo)...');

    switch (proveedor) {
      case ProveedorIA.groq:
        return _llamarOpenAiCompatible(
          url: 'https://api.groq.com/openai/v1/chat/completions',
          sistema: sistema,
          usuario: usuario,
        );
      case ProveedorIA.openai:
        return _llamarOpenAiCompatible(
          url: 'https://api.openai.com/v1/chat/completions',
          sistema: sistema,
          usuario: usuario,
        );
      case ProveedorIA.personalizado:
        final url = customUrl.isNotEmpty ? customUrl : 'https://api.groq.com/openai/v1/chat/completions';
        return _llamarOpenAiCompatible(
          url: url,
          sistema: sistema,
          usuario: usuario,
        );
      case ProveedorIA.anthropic:
        return _llamarAnthropic(sistema: sistema, usuario: usuario);
      case ProveedorIA.gemini:
        return _llamarGemini(sistema: sistema, usuario: usuario);
    }
  }

  Future<String> _llamarOpenAiCompatible({
    required String url,
    required String sistema,
    required String usuario,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${apiKey.trim()}',
        },
        body: jsonEncode({
          'model': modelo.isNotEmpty ? modelo : proveedor.modeloPorDefecto,
          'messages': [
            {'role': 'system', 'content': sistema},
            {'role': 'user', 'content': usuario},
          ],
          'temperature': 0.2,
        }),
      );

      if (response.statusCode != 200) {
        AppLogger.e('Error en API ${proveedor.name}: ${response.statusCode} - ${response.body}');
        throw Exception('Error en ${proveedor.nombre} (${response.statusCode}): ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw Exception('Respuesta vacía del proveedor ${proveedor.nombre}');
      }

      final message = choices.first['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String? ?? '';
      return content.trim();
    } catch (e, st) {
      AppLogger.e('Fallo al invocar IA', e, st);
      rethrow;
    }
  }

  Future<String> _llamarAnthropic({
    required String sistema,
    required String usuario,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey.trim(),
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': modelo.isNotEmpty ? modelo : 'claude-3-5-sonnet-20241022',
          'max_tokens': 2048,
          'system': sistema,
          'messages': [
            {'role': 'user', 'content': usuario},
          ],
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Error en Anthropic (${response.statusCode}): ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final contentList = data['content'] as List<dynamic>?;
      if (contentList == null || contentList.isEmpty) {
        throw Exception('Respuesta vacía de Anthropic');
      }

      final first = contentList.first as Map<String, dynamic>;
      return (first['text'] as String? ?? '').trim();
    } catch (e, st) {
      AppLogger.e('Fallo al invocar Anthropic', e, st);
      rethrow;
    }
  }

  Future<String> _llamarGemini({
    required String sistema,
    required String usuario,
  }) async {
    try {
      final url = 'https://generativelanguage.googleapis.com/v1beta/models/$modelo:generateContent?key=${apiKey.trim()}';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'systemInstruction': {
            'parts': [
              {'text': sistema}
            ]
          },
          'contents': [
            {
              'parts': [
                {'text': usuario}
              ]
            }
          ],
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Error en Gemini (${response.statusCode}): ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('Respuesta vacía de Gemini');
      }

      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) return '';

      return (parts.first['text'] as String? ?? '').trim();
    } catch (e, st) {
      AppLogger.e('Fallo al invocar Gemini', e, st);
      rethrow;
    }
  }
}
