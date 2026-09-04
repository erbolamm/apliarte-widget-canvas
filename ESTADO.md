# ESTADO — ApliArte Widget Canvas

## 🎯 Propósito
Editor visual local (público en el futuro, gratis) que lee un proyecto Flutter **real y existente**
(ej. CalcaApp), extrae de forma curada y recursiva los widgets propios (compuestos por Material)
de una clase que elijas, te los muestra en árbol, te deja decidir cuáles expandir y cuáles dejar
como placeholder, los edita visualmente en un canvas tipo boceto, y al terminar genera un **prompt
detallado** para pasárselo a un agente de código (Claude Code, Codex, Antigravity, Copilot...) que
aplique esos cambios al proyecto Flutter real.

Inspirado visualmente en diseño **Material 3 Expressive**, pero **nativo
para Flutter** — con un alcance enfocado en código real: lee código real, no parte de un lienzo en blanco.

## 📊 Estado actual
- **Completado**:
  - Validación conceptual completa (conversación con Claude Code, 2026-09-04).
  - Prueba real de extracción de árbol de widgets sobre `BarraPrincipal` de CalcaApp — funcionó bien
    para widgets estándar de Material (AppBar, IconButton, NavigationBar, Text); confirmó el hueco
    real con widgets propios compuestos (`TrofeoPuntosChica`, `DrawerPrincipal`, etc.).
  - Verificado por qué **Flutter Widget Previewer** (oficial, gratis, desde Flutter 3.47) no cubre
    esta necesidad: requiere mockear a mano cada dependencia de BLoC/Provider, no soporta plugins
    nativos (motor web), y no hace extracción curada ni recursiva de clases compuestas — vista una
    demo real funcionando en local (fvm + Flutter 3.47.2).
  - Comparado contra proyectos existentes para no reinventar la rueda (ver `DECISIONES_DE_DISENO.md`).
  - **Extractor v0.1 funcionando** (`extractor/`, Dart puro + `package:analyzer`, sin necesidad de
    resolver tipos ni de `pub get` del proyecto objetivo): dado un archivo y una clase, encuentra
    su `build()` (siguiendo `createState()` si es StatefulWidget), reconstruye el árbol de widgets,
    clasifica cada uno como "propio" (declarado en `lib/` del propio paquete, por índice real de
    clases) o no, y detecta cuándo hay más de un widget propio en el árbol para preguntar cuál
    expandir — regla validada, no solo diseñada. 5 tests automatizados pasan, `dart analyze` limpio.
  - **Validado contra `BarraPrincipal` real de CalcaApp** (no solo contra fixtures): reproduce el
    árbol correctamente, incluyendo el caso difícil de `PageView.builder` con contenido generado
    dinámicamente (`NavigationDestination` vía `.map().toList()`), marcado honestamente como tal.
  - **Decisión de stack tomada**: landing pública con el pipeline HTML-native ya existente de
    `erbolamm-trabajo` (no SEO/DOM en Flutter); el editor en sí en **Flutter Web** (justificado:
    es una app interactiva, no un sitio de contenido — la crítica real a Flutter Web es sobre SEO
    y accesibilidad de sitios de contenido, no sobre apps; el propio equipo de Flutter reconstruyó
    SUS webs con Jaspr por ese motivo, pero un editor no necesita SEO).
  - **Canvas v0.1 funcionando** (`canvas/`, Flutter Web puro, sin dependencias nuevas): pega el
    JSON del extractor, dibuja cada pieza en un lienzo con pan/zoom, con **widgets Material reales**
    (no dibujos aproximados) para los que tienen equivalente directo, caja "PROPIO" cerrada para
    los que no — tocar la caja la expande. Arrastre libre para reposicionar. Compila limpio a web
    (`flutter build web`, incluye chequeo WASM). 5 tests pasan, incluyendo uno con el JSON REAL de
    `BarraPrincipal` (no solo fixtures) — carga, detecta el punto de decisión con los 3 widgets
    propios reales, y coloca coordenadas distintas para cada uno.
  - **Export de prompt funcionando** (`lib/services/prompt_exporter.dart`): botón "Exportar
    prompt" en el canvas genera texto listo para copiar/pegar en cualquier agente de código,
    describiendo el árbol en el **orden visual tras el arrastre** (no el orden original del
    código), distinguiendo qué widgets propios se revisaron (expandidos) de los que no se tocaron,
    y avisando honestamente de contenido generado dinámicamente. 9 tests pasan.
  - **Bug real encontrado y corregido**: la clase raíz que el usuario elige extraer, si resultaba
    ser técnicamente "propia" (ej. `FondoApli`, un wrapper de tema), salía cerrada por defecto —
    igual que cualquier widget propio anidado — y el export salía casi vacío. Se corrigió: la raíz
    siempre empieza abierta (el usuario ya "decidió mirarla" al elegir esa clase); solo los
    widgets propios *anidados* dentro empiezan cerrados como placeholder.
  - **Expansión recursiva real funcionando** (`servidor/`, Dart puro con `shelf` + `shelf_router`,
    localhost únicamente): al tocar una caja "PROPIO" cerrada, el canvas pide por HTTP
    (`GET /extraer?archivo=...&clase=...`) el árbol real de ESE widget al servidor local, que
    reusa el extractor como librería (sin relanzar procesos) y devuelve el mismo formato JSON.
    Mismo patrón arquitectónico que usa **Flutter DevTools oficial** (web UI + servicio local en
    `127.0.0.1`) — no es una chapuza, es el estándar para este tipo de herramienta. Probado de
    verdad contra `TrofeoPuntosChica` real (no solo BarraPrincipal): la expansión trae su
    `GestureDetector` interno correctamente. Loading indicator mientras se espera la respuesta.
    Simplificación consciente frente al diseño original: expansión **in-place** (los hijos
    aparecen cerca del padre en el mismo lienzo), no pestañas separadas — cubre la necesidad real
    sin la complejidad extra de una UI de pestañas; se puede añadir después si hace falta.
  - **Explorador de archivos real** (petición de Javier: "un botón y que te haga buscar el
    archivo"). Nuevo botón "Elegir archivo .dart..." abre un diálogo que navega el disco real vía
    el servidor local (`GET /listar`) — necesario porque **ningún navegador expone la ruta real de
    un archivo elegido** (limitación de seguridad de todo navegador, no de Flutter). Al elegir un
    `.dart`, se sugieren automáticamente sus clases Widget (`GET /clases`, heurística: extiende
    `StatelessWidget`/`StatefulWidget`) y se autocompleta el campo si hay una sola candidata.
  - **Verificado por primera vez en un navegador real** (no solo tests automatizados): instalado
    `claude-in-chrome`, build real + servido localmente, recorrido completo con capturas —
    explorador de archivos navegando el disco real, carga de `BarraPrincipal` (CalcaApp) real,
    expansión de `TrofeoPuntosChica` real, export de prompt real. Encontrado y corregido un bug
    real en el camino:
    - **Bug de posicionamiento en cascada**: al expandir un widget, el servidor devuelve el árbol
      COMPLETO debajo (varios niveles), no solo uno — pero solo se posicionaban los hijos directos;
      los nietos se quedaban todos en `(0,0)` por defecto y se amontonaban en la esquina superior
      izquierda, encima de otras piezas (visto literalmente en la captura: "TextStyle" solapado con
      la cabecera). Corregido: cada hijo directo se trata como raíz de su propio sub-árbol con
      `autoLayout`, sin mover la posición del nodo padre (que controla el usuario arrastrando).
      Test de regresión añadido. 11 tests pasan.
  - **Demo real incrustada en la landing** (petición de Javier: "una vista limpia... una demo de lo
    que se va a ver" antes de instalar nada). Captura real (no mockup) guardada en
    `trabajo/assets/demo-canvas.jpg`, insertada justo debajo del hero en ambos idiomas — verificado
    renderizando la landing servida localmente, imagen carga correctamente en ambos ES/EN.
  - **Rediseño visual tras aplicar estándares Material 3 Expressive** (Javier: "no puedo publicar
    eso así"). Cambios reales:
    - **Marco de dispositivo** (`_MarcoDispositivo` en `canvas_view.dart`): silueta de teléfono
      (borde redondeado, "notch" arriba) detrás del árbol, con etiqueta explícita — "Árbol de tu
      código real — no una pantalla ya montada" — porque esto es un diagrama de código real y puede
      desbordar el marco al expandir. Aclarado a propósito, no se finge ser lo que no es.
    - **Espaciado mucho más compacto**: columnas de 220→156px, filas de 140→96px en
      `autoLayout`; separación entre hijos expandidos de 260→180px.
    - **Piezas con acabado expresivo**: sombra real (elevación 4, antes 2), esquinas mucho más
      redondeadas (20px). Las cajas "PROPIO" con sombra propia y esquinas más redondas (24px).
    - **Cajas estructurales (Scaffold, SafeArea, Duration...) discretas a propósito**: más
      pequeñas, semitransparentes, texto atenuado — para que no compitan visualmente con los
      widgets Material reales (AppBar, NavigationBar...), que ahora sí destacan.
  - **Un solo clic real para cargar** (pregunta de Javier: "¿corregiste todo el lateral... a un
    solo botón?"). Antes: elegir archivo → (se autocompletaba la clase) → había que pulsar
    "Cargar en el canvas" aparte. Ahora: elegir archivo → si hay una sola clase candidata (o eliges
    una del diálogo cuando hay varias), se carga solo, sin paso extra. El botón "Cargar en el
    canvas" sigue existiendo para cuando se edita la ruta/clase a mano.
  - **Aclarado (pregunta de Javier): la extracción es 100% mecánica, no usa IA.** Parseo real del
    AST de Dart vía `package:analyzer` — determinista, gratis, sin latencia de modelo. La IA solo
    entra si el usuario decide pegar el prompt final en su agente de código; el propio extractor
    nunca la necesita.
    - Verificado de nuevo en el navegador real tras el cambio — captura enviada a Javier para
      comparación directa, y actualizada en `trabajo/assets/demo-canvas.jpg` (landing).
    - **Pendiente / no resuelto del todo**: la pieza `NavigationBar` real dentro de `SafeArea` se
      ve rara en la captura (un círculo suelto en una caja gris) — necesita revisión aparte, no es
      parte de este pase de rediseño.
  - **Tres bugs reales del extractor, encontrados por Javier probando con su propio archivo**
    (`descripciones_desplegables.dart` de CalcaApp — no una fixture inventada):
    1. **`createState()` con tipo de retorno genérico** (`State<X> createState() => _XState();`,
       el patrón MÁS común en Flutter moderno — 10+ archivos solo en `calca_app/lib/widgets/`
       lo usan). Antes se buscaba una clase llamada literalmente `"State<DescriDesplegables>"`,
       que nunca existe. Corregido: se mira qué clase se instancia de verdad en el `return` del
       método, no la anotación de tipo declarada.
    2. **Condicionales `? :` no se extraían en absoluto** (`child: condicion ? A() : B()`, muy
       común). Ahora se extraen las DOS ramas, marcadas honestamente como no garantizadas
       (`generadoDinamicamente: true` + etiqueta "(si)"/"(si no)" en el argumento).
    3. **Ambigüedad real del parser sin resolver tipos**: `EdgeInsets.all(...)` se parseaba igual
       que "prefijo de import EdgeInsets + tipo all", saliendo `"all"` en vez de
       `"EdgeInsets.all"`. Corregido con la convención Dart (prefijos en minúscula, tipos en
       mayúscula) para desambiguar.
    - Los 3 con test de regresión nuevo en fixtures reales (no solo el caso que falló). 10 tests
      en extractor, 11 en canvas. Fixture de canvas (`barra_principal_arbol.json`) regenerada con
      el extractor corregido. Servidor local reiniciado con el código nuevo y verificado por HTTP
      real contra el archivo exacto que le dio el error a Javier.
  - **Nombre completo de constructores con nombre conservado**: `PageView.builder`,
    `ListView.builder`, etc. ya no se muestran solo como `PageView`/`ListView` — se guarda el
    campo `constructorNombrado` por separado (para no romper la clasificación propio/no-propio,
    que sigue mirando solo la clase base) y se expone `nombreCompleto` para mostrar en el canvas
    y en el prompt exportado. Verificado contra `BarraPrincipal` real: ahora sale
    `body: PageView.builder`, no `body: PageView`.
- **En progreso**: pulido visual del canvas (delegado, ver `PROMPT_PULIDO_VISUAL.md`).
- **Pendiente**:
  - **Aparcado a propósito** (no resuelto, no olvidado): distinguir "wrapper de tema" (`FondoApli`)
    de widget con contenido visual real. Es heurístico y difuso (¿un widget que solo reenvía
    `child` es "wrapper"? ¿y si además pinta un fondo?) — no se fuerza una solución a medias;
    se revisa si hace falta cuando tengamos más casos reales que CalcaApp con los que contrastar.
  - ~~Checklist de licencia~~ ✅ hecho: `LICENSE` (MIT) creado en la raíz. Se confirmó que todo
    el código se construyó desde cero en Dart, así que no aplica atribución de terceros.
  - ~~Nombre definitivo~~ ✅ **ApliArte Widget Canvas** (decidido por Javier, 04-09-2026). Propagado
    a: carpeta del proyecto (`~/trabajo/apliarte-widget-canvas/`, antes `flutter-canvas/`), paquete
    Dart del canvas (`apliarte_widget_canvas`, antes `flutter_canvas`, con todos sus imports),
    título de la app/pestaña del navegador, `web/manifest.json`, `README.md`, este documento.
    ⚠️ Si `PROMPT_PULIDO_VISUAL.md` ya se le había pasado a otra IA con la ruta vieja, esa tarea
    necesita la ruta nueva o se rompe.
  - **Idea de landing (Javier, 04-09-2026): "hoja de bonificaciones" por estrellas de GitHub** — la
    landing anuncia que al llegar a ciertos hitos de ⭐ el proyecto avanza de versión documentada
    (ej. 100★ → v2, 500★ → v3, y así sucesivamente). Anotado para incluir como contenido cuando se
    redacte la landing (Paso 3.13 abajo) — mecánica de incentivo comunitario, no requiere código,
    solo copy y quizás un contador de estrellas en vivo en la propia landing.
  - **`README.md` borrador creado** (raíz del proyecto), siguiendo el formato obligatorio de
    `INBOX.md` Paso 3.5 (bloque final Autor/Nota personal/Apoya el proyecto/Licencia/About). La
    "nota personal" está marcada explícitamente como borrador — Javier debe revisarla/reescribirla
    con su propia voz antes de publicar, no se inventó como definitiva.
  - **Pipeline público — lo que aplica ya hecho, lo que no aplica descartado explícitamente:**
    - Paso 3.7 (seguridad npm/Node): **no aplica** — verificado, cero `package.json` en todo el
      proyecto, es 100% Dart/Flutter.
    - Paso 3.13 (landing 10 bloques, Filosofía ApliArte Link): ✅ creada en
      `trabajo/landing.html`, paleta y tipografía de `APLIARTE_BRAND_KIT.md`. Incluye la hoja de
      bonificaciones por estrellas (100★→v2, 500★→v3...).
    - Paso 4 (auditoría de marketing / screenshots): **no hecho** — requiere una web ya publicada
      con Playwright, no aplica mientras el proyecto no tenga URL desplegada (el repo de GitHub ya
      existe, pero aún no hay GitHub Pages / hosting sirviendo la landing).
    - Paso 5 (registro local): ✅ añadido a `erbolamm-trabajo/universe.json` (id
      `apliarte-widget-canvas`, pilar `herramientas`, status `wip`, con `urls.github` real).
  - **Repo de GitHub creado por Javier**: `https://github.com/erbolamm/apliarte-widget-canvas`
    (público, vacío — sin push todavía). Botones de compartir y `git clone` de la landing/README ya
    apuntan a la URL real, siguiendo el mismo patrón (enlaces de intent reales por JS) que usa
    `apliarte-link` — verificado contra su código fuente real, no inventado.
  - **Landing y README bilingües ES/EN** (petición explícita de Javier: "sepan cómo funciona en
    inglés y español"). Landing: selector de idioma con JS (`[data-i18n]` + botones ES/EN en el
    header), todo el contenido explicativo duplicado (hero, beneficios, cómo funciona, FAQ,
    descargas, apoyo, roadmap, planes). README: secciones `## Español` / `## English` con anclas de
    salto arriba. La nota personal del autor (bloque 9) se queda como estaba, con las 6 banderas
    siempre visibles en acordeón — no depende del selector ES/EN de la página.
    HTML y JS verificados: etiquetas balanceadas, `node --check` sobre el script inline sin errores.
  - **Banner flotante de comunidad** (petición de Javier, viendo `FabricaDeAgentesApliarte`):
    portado desde su `CommunityBanner.tsx` real (React) a HTML/CSS/JS plano — mismo comportamiento
    (rotación cada 10s, cerrar con ✕), mensajes propios de este proyecto (apoyo/Ko-fi, issues de
    GitHub, hoja de bonificaciones por estrellas, compartir), bilingüe ES/EN siguiendo el selector
    de idioma. Verificado: HTML balanceado, `node --check` limpio.
  - **Nuevo estándar formalizado en `erbolamm-trabajo/INBOX.md` (Paso 3.14)**: a petición de
    Javier, el Banner de Comunidad y la página/sección de Apoyo (`/apoyar`) dejan de ser algo
    ad-hoc de este proyecto — quedan documentados como paso obligatorio del pipeline, extraído del
    código fuente real de `FabricaDeAgentesApliarte` (`CommunityBanner.tsx` y `Pricing.tsx`), para
    que se aplique a todos los proyectos futuros que pasen por INBOX, no solo a este.
  - **Bloque 6 de nuestra propia landing reescrito** para cumplir ese nuevo estándar: hero con
    misión, callout "Realidad vs Humo", 3 niveles de apoyo (Café/Co-Creador/Mecenas Fundador) con
    enlaces honestos directos a Ko-fi/PayPal (sin fingir una pasarela de pago que no existe), y
    otros canales (GitHub, Twitch, Tips). Bilingüe ES/EN. HTML re-verificado balanceado tras el cambio.
  - **Bug real encontrado por Javier probando de verdad** (no en código, en las instrucciones):
    siguió los comandos de la landing (`trabajo/landing.html`, sección "Empezar ahora") pegados en
    la misma terminal — `cd servidor && ...` deja el shell dentro de `servidor/`, así que el
    siguiente `cd canvas` falla porque no existe ahí (es `../canvas`). Además, el puerto 8799 lo
    tenía ocupado un servidor de pruebas mío que dejé corriendo sin cerrar de antes en esta misma
    sesión — no relacionado con su comando, corregido matando ese proceso. Corregido en README.md
    (ES+EN) y en la landing (ES+EN): cada bloque de comando ahora asume terminal nueva desde la
    raíz del repo, con nota de troubleshooting para "Address already in use".
  - **Segundo bug real encontrado por Javier probando de verdad**: `flutter run -d chrome` sin
    prefijo `fvm` coge el Flutter global de su máquina (3.44.8, Dart 3.12.2) en vez del pinado
    del proyecto (3.47.2, Dart 3.13.2 — requerido por `canvas/pubspec.yaml`), y falla resolviendo
    dependencias. Corregido en README.md y landing (ES+EN): ahora es `fvm flutter run -d chrome`
    en los 4 sitios donde aparecía. `fvm` en sí ya no necesita ajustar el PATH — quedó instalado en
    `/opt/homebrew/bin/fvm` (vía Homebrew, en esta misma sesión), que ya está en el PATH normal.
  - **Carga directa desde el servidor — ya no hace falta una tercera terminal** (petición de
    Javier: "que algo sea fácil"). El panel del canvas tiene ahora dos campos (ruta del archivo +
    nombre de la clase) y un botón "Cargar en el canvas" que pide el árbol directo al servidor
    local (`ExtractorClient.extraerClase`, nuevo método) — sin correr el extractor a mano ni
    copiar/pegar JSON. La opción de pegar JSON sigue disponible, colapsada, como alternativa si el
    servidor no está corriendo. Verificado extremo a extremo contra `BarraPrincipal` real (servidor
    corriendo, petición HTTP real, árbol correcto recibido). 9 tests pasan (uno reescrito para el
    nuevo flujo). README y landing (ES+EN) actualizados: la Terminal 3 ya no es un paso obligatorio.
  - **Paleta de widgets NUEVOS** (petición de Javier: panel para arrastrar piezas nuevas al
    lienzo). Panel lateral "Añadir widget nuevo" (solo visible con un árbol cargado): chips por
    cada tipo Material soportado por `PieceRenderer` (AppBar, NavigationBar, IconButton, Icon,
    Text, ElevatedButton, Card, TextField, Switch, Drawer, FloatingActionButton). Al pulsar uno,
    se añade como hijo de la raíz con `PieceNode.creadoPorUsuario = true` -- distingue "esto ya
    existe en tu código, reordénalo" (extraído) de "esto es nuevo, hay que crearlo" (añadido a
    mano). Marca visual: borde de color + badge "NUEVO" + botón (X) para quitarlo si fue un error
    (`PieceRenderer`/`CanvasView`, `onEliminar` encadenado desde `main.dart`). El export de prompt
    (`prompt_exporter.dart`) etiqueta cada nodo nuevo con
    "(NUEVO -- no existe en el código, hay que crearlo)" y añade un párrafo final explícito para
    que el agente de código no confunda "reordenar" con "crear". 15 tests pasan (4 nuevos:
    creación con `creadoPorUsuario`, nodo extraído sin esa marca por defecto, aviso NUEVO en el
    prompt, ausencia del aviso cuando no se añadió nada, más un test de widget que agrega y borra
    desde la paleta en pantalla). `flutter analyze` limpio. Sin verificación en navegador real
    todavía (pendiente).
  - **Paso previo de `fvm` añadido** (petición de Javier): antes de los comandos, README y landing
    (ES+EN) ahora explican qué es `fvm`, por qué hace falta, cómo comprobar si ya lo tienes
    (`fvm --version`) y cómo instalarlo si no (`brew install fvm` en macOS, `dart pub global
    activate fvm` en cualquier sistema con Dart, enlace a la doc oficial verificada por búsqueda,
    no inventada). Para alguien sin `fvm` instalado, ya no se topa con el comando fallando sin
    contexto — sabe qué es y qué hacer antes de intentarlo.

## 🚀 Fase v2 (documentada, NO para la v1 — decisión de Javier 04-09-2026)

**Integración con GitHub (login + leer repos remotos, sin servidor local).**

Pregunta de Javier: "¿cualquiera podrá usarlo sin instalar nada, como app web pura?" — respuesta
honesta: para leer un proyecto Flutter REAL hace falta algo local (servidor), inevitable, mismo
patrón que Flutter DevTools oficial. PERO existe una vía para acercarse más al "cero instalación":

- **GitHub Device Flow** (OAuth sin backend propio ni secretos expuestos) para que el usuario
  inicie sesión con su cuenta de GitHub directamente desde el navegador.
- Reemplazar la lectura de disco (`dart:io`, solo funciona en el servidor local) por lectura vía
  API de GitHub (HTTP) — el paquete `analyzer` es Dart puro, puede parsear TEXTO recibido por HTTP
  **dentro del propio navegador**, sin necesitar `dart:io`.
- Consecuencia importante: **para repos alojados en GitHub, esta vía podría eliminar por completo
  la necesidad del servidor local** — la respuesta más cercana posible a "cero instalación, app web pura",
  pero solo viable para proyectos ya subidos a GitHub (no proyectos 100% locales).
- Coste estimado: comparable a todo lo construido para la v1 junta (extractor + servidor + canvas)
  — arquitectura distinta (HTTP en vez de disco), autenticación, límites de tasa de la API de
  GitHub (60/hora sin login, 5000/hora con login), selector de repo/rama/archivo en la UI.
- **Decisión (04-09-2026):** no se aborda en v1. Se cierra primero la v1 local, que ya funciona de
  punta a punta. Esto se retoma como fase v2 bien planificada aparte.

## 🗺️ Hoja de ruta (siguientes pasos)
1. ~~Prototipo del **extractor**~~ ✅ hecho y validado (`extractor/`, ver arriba).
2. Decidir nombre definitivo y confirmar checklist de licencia (MIT propio).
3. ~~Prototipo del **canvas visual**~~ ✅ hecho y validado (`canvas/`, ver arriba).
3b. Pulido visual (spacing, tipografía, color, micro-interacciones) — EN CURSO, delegado.
4. ~~Export de **prompt**~~ ✅ hecho y validado (`lib/services/prompt_exporter.dart`, ver arriba).
5. ~~Recursión / expansión de widgets propios anidados~~ ✅ hecho (servidor local + expansión
   in-place, ver arriba) — se simplificó de "pestañas separadas" a expansión en el mismo lienzo.
6. ~~Conservar el nombre del constructor con nombre completo~~ ✅ hecho (`PageView.builder`, ver
   arriba). Lo de distinguir "wrapper de tema" queda aparcado a propósito (ver sección Pendiente).
7. Decidir nombre definitivo del proyecto y checklist de licencia.
8. Pipeline público completo de `erbolamm-trabajo` antes de publicar: Paso 3.13 (landing 10 bloques),
   Paso 3.7 (seguridad npm/Node, es proyecto Next.js/TS), auditoría de marketing, registro en
   `universe.json`.
9. (v2, aparte) Integración GitHub — ver sección propia arriba.

## ⚠️ Bloqueos / Dependencias
- ~~Nombre final~~ ✅ ApliArte Widget Canvas. Dominio/repo público de GitHub aún sin decidir.
- Arquitectura 100% nativa en Flutter y Dart validada.

## 📅 Fecha de última actualización
2026-09-04
