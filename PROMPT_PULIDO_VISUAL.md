# Prompt para delegar el pulido visual del canvas

Copia y pega esto en ChatGPT/Codex o MiniMax Code, con acceso al directorio
`/Users/apliarte/trabajo/apliarte-widget-canvas/canvas/`.

---

Estás trabajando en una app Flutter Web (`/Users/apliarte/trabajo/apliarte-widget-canvas/canvas/`), un
editor visual tipo boceto para widgets de Flutter. La lógica y los tests YA ESTÁN HECHOS Y
VALIDADOS — tu tarea es SOLO pulir el aspecto visual, sin tocar el comportamiento.

## No toques
- `lib/models/piece_node.dart` — el modelo de datos y el algoritmo de layout ya están probados
  contra un proyecto real (CalcaApp). No cambies su lógica.
- La regla de negocio: un widget "propio" (marcado `propio: true`) empieza cerrado como
  placeholder, y solo se expande si el usuario toca la caja. No cambies este comportamiento.
- Los 5 tests en `test/widget_test.dart` deben seguir pasando tal cual (`flutter test`).

## Sí puedes tocar
- `lib/widgets/piece_renderer.dart` — cómo se ve cada pieza (colores, tipografía, sombras,
  bordes, espaciado). Apunta a un nivel de acabado premium: bordes suaves, transiciones,
  jerarquía visual clara y estilo Material 3 Expressive.
- `lib/widgets/canvas_view.dart` — el lienzo en sí: cuadrícula de fondo, guías de alineación,
  feedback visual al arrastrar (sombra/elevación mientras se mueve una pieza), zoom más suave.
- `lib/main.dart` — el panel lateral izquierdo (donde se pega el JSON): que se vea como un panel
  de herramientas serio, no un formulario improvisado.
- Tema global (`MaterialApp.theme`): puedes ajustar la paleta de color semilla, tipografía, etc.

## Reglas
- Sigue Material 3 Expressive (mismo lenguaje visual que el editor original, pero con widgets
  Flutter reales, no dibujados).
- Después de cualquier cambio: `flutter analyze` debe salir limpio y `flutter test` debe seguir
  dando 5/5 en verde. Si rompes un test por un cambio visual legítimo (ej. cambiaste un texto),
  actualiza el test, no lo borres.
- No añadas paquetes/dependencias nuevas sin necesidad real — es una app pequeña, que siga siendo
  Flutter puro si se puede.
- Al terminar, corre `flutter build web --release` y confirma que compila sin errores.

## Contexto de por qué existe este proyecto
Ver `/Users/apliarte/trabajo/apliarte-widget-canvas/DECISIONES_DE_DISENO.md` si necesitas entender el
propósito completo (no hace falta para esta tarea de solo estilo, pero está ahí).
