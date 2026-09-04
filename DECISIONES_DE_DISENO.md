# Decisiones de diseño — Flutter Canvas

> Registro de por qué este proyecto existe y por qué se descartaron otros caminos.
> Fuente: conversación con Claude Code, 2026-09-04. Ver `ESTADO.md` para la hoja de ruta.

## 1. Origen y pivote

Punto de partida: editores web de boceto para pantallas **Material 3 Expressive**, que exportan un prompt de
texto para pasarle a una IA de código. Sin backend, todo en `localStorage`.

**Por qué NO se hace fork de editores React/Web existentes:**
- Su target de salida es Android nativo o Web — no Flutter. El proyecto real de Javier (CalcaApp,
  MeLlaman, etc.) está en Flutter.
- No leen ni parsean código Dart real. Todos sus componentes son dibujos propios (SVG/React) desde
  cero — no tienen ninguna relación con el árbol de widgets de un proyecto existente.

**Pivote:** en vez de sketch-desde-cero, el proyecto lee un proyecto Flutter **real y existente**
y reconstruye sus pantallas como boceto editable, curado por el propio usuario.

## 2. Descartado antes de llegar aquí: editor bidireccional en vivo

Primera idea (demasiado ambiciosa para v1): abrir CalcaApp, mover widgets reales con el ratón,
que eso parchee el código fuente en caliente, y alternar a un modo "correr la app de verdad" tipo
`flutter run`, todo dentro del editor.

**Por qué se descartó para v1:** requeriría un parser de AST de Dart, un puente en vivo con el
motor de Flutter (protocolo de hot-reload/DevTools) y sincronización bidireccional código↔canvas.
Es un proyecto de meses, no una base para arrancar. Se aparcó como posible v-lejana, no v1.

## 3. Alcance real de v1 (validado)

1. Javier elige una clase Flutter concreta (ej. `BarraPrincipal`).
2. Un agente de código la lee y construye un árbol de sus widgets.
3. **Regla de clasificación (mecánica, ya verificada contra código real de CalcaApp):** si el
   import del widget empieza por el nombre del propio paquete (`package:calca_app/...`) es "mío";
   si es `package:flutter/...` o cualquier paquete externo, es estándar y ya tiene equivalente
   directo en la paleta del editor (no hace falta expandirlo).
4. **Regla de "más de un camino → preguntar":** si al nivel actual hay más de un widget propio
   compuesto, el agente PARA y pregunta cuál expandir ahora, en vez de volcarlos todos — evita
   saturar el canvas y evita que el agente decida por su cuenta cuánto profundizar.
5. Por cada widget propio elegido para expandir: se abre en **pestaña aparte** (recursión), sin
   mezclar su edición con la vista padre. Los que no se expanden quedan como pieza "placeholder"
   (tamaño/posición real, movible, sin editar por dentro).
6. Edición visual con la paleta de piezas Material del canvas:
   botones, chips, app bars, navigation bars, tarjetas, listas, diálogos, campos de texto, cajas...
7. Al terminar, exporta un **prompt detallado** (texto) para pegar en Claude Code / Codex / Antigravity
   / Copilot sobre el proyecto Flutter real, y que ese agente aplique los cambios al código real.
8. **Fuera de v1, explícitamente aparcado:** navegación/conexión entre pantallas distintas (cómo se
   comunican `BarraPrincipal` con las 3 vistas que carga) — se deja para una versión futura.

## 4. Validación real contra código de CalcaApp

Extracción de prueba sobre `lib/pages/00_Principal/barra_principal.dart` (clase `BarraPrincipal`):

```
BarraPrincipal.build()
└─ FondoApli (custom, wrapper de tema — no es "pieza de canvas")
   └─ Scaffold
      ├─ AppBar
      │  ├─ Text "CalcaApp.Com"                    → mapea directo
      │  └─ actions:
      │     ├─ IconButton (headset_mic_outlined)    → mapea directo
      │     └─ TrofeoPuntosChica (custom, mío)      → candidato a expandir
      ├─ Drawer: DrawerPrincipal (custom, mío)      → candidato a expandir
      ├─ body: PageView.builder (3 páginas)
      │  ├─ VistaPrincipal (custom, mío)
      │  ├─ VistaAccesosDirectos (custom, mío)
      │  └─ SettingsScreen (custom, mío)
      └─ NavigationBar (3 destinos: Inicio/Más info/Configuración) → mapea directo
```

Confirmado: `TrofeoPuntosChica`, `DrawerPrincipal`, `FondoApli` viven en `calca_app/lib/...` —
la regla de clasificación por import funciona sin ambigüedad sobre código real, no es teoría.

## 5. Por qué no basta con lo que ya existe (verificado, no asumido)

### Flutter Widget Previewer (oficial, gratis, `flutter widget-preview start`)
- Estable desde **Flutter 3.47**. CalcaApp está en 3.38.7, `afinar_de_oido` en 3.44.8 — ambos por
  debajo. Probado en vivo con Flutter 3.47.2 vía `fvm` (proyecto desechable, no toca ningún
  proyecto real de Javier).
- Requiere anotar `@Preview` manualmente por widget, uno a uno — no hace extracción automática ni
  curada de una clase completa.
- Widgets con `context.watch<XBloc>()` fallan si no se mockea el provider a mano (probado con un
  caso que falla a propósito, ver demo).
- Corre en motor web: `dart:io`, `dart:ffi` y plugins nativos (Firebase, RevenueCat, P2P — todos
  presentes en CalcaApp) no funcionan ahí.
- **Veredicto de Javier tras verlo en vivo:** "lo mío va a otro nivel y sí que merece la pena."

### Widgetbook (widgetbook.io, open source, activamente mantenido)
- Resuelve la parte de "previsualizar mis widgets reales con dependencias mockeadas" mejor que el
  Previewer oficial. **Núcleo gratis y open source** — lo de pago ($149/mes+) es solo el servicio
  cloud de snapshots/colaboración de equipo, no hace falta para uso local en solitario.
- No hace edición visual de posición ni exporta prompts — es catálogo/preview, no editor.

### FlutterViz (github.com/iqonic-design/flutter_viz)
- Constructor visual drag-and-drop que exporta Dart limpio. Por su documentación, construye
  **desde cero** — no confirmado que lea un proyecto Flutter existente arbitrario. No profundizado
  del todo; revisar antes de descartarlo por completo si se busca reusar piezas.

### flutter_ide / "Flutter Widget-Maker" (github.com/Norbert515/flutter_ide, 2019)
- El intento histórico más parecido a la idea original (editar widgets Y código a la vez). Su
  propio autor lo describió como "demo, ni cerca de terminado". Sin evidencia de mantenimiento
  activo desde entonces. Señal de que la versión más ambiciosa es genuinamente difícil — refuerza
  la decisión de la sección 2 de no intentar esa versión en v1.

**Conclusión:** ningún proyecto existente cubre la combinación completa (leer proyecto real →
extracción curada y recursiva de solo las clases propias → edición en canvas → prompt de salida).
No es reinventar la rueda — es la pieza que falta entre "Widgetbook/Previewer" (preview aislado) y
"un editor visual genérico" (construye desde cero).

## 6. Público, no privado

Decisión explícita de Javier: el proyecto se publica (con marca propia, enlaces de apoyo, redes),
no se queda como herramienta interna. Esto activa el **pipeline público completo** de
`erbolamm-trabajo/INBOX.md` antes de publicar (landing de 10 bloques, verificación de seguridad
npm/Node, auditoría de marketing, registro en `universe.json`) — no el modo reducido de "proyecto
privado" (Paso 3.9) que se había planteado brevemente cuando la idea era solo de uso interno.

**Checklist legal — actualizado 04-09-2026:**
Como al final todo el código se construyó desde cero en Dart (extractor, servidor, canvas),
no aplica reutilización de código de terceros. Checklist real:
- ✅ `LICENSE` propio (MIT, © 2026 Javier Mateo / ApliArte) — creado en la raíz del proyecto.
- Las dependencias de pub.dev (`analyzer`, `shelf`, `http`, etc.) son estándar del ecosistema
  Dart/Flutter, con licencias permisivas (BSD-3 en su mayoría) — no requieren NOTICE manual, se
  cumplen automáticamente al declararlas en `pubspec.yaml` (Flutter genera su propia página de
  licencias de terceros en la app).
