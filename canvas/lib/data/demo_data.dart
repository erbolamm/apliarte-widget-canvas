import 'dart:convert';
import '../models/piece_node.dart';

/// Árbol de demostración real (BarraPrincipal de CalcaApp) para probar el canvas
/// directamente en la web sin requerir el servidor local activo.
const String kDemoBarraPrincipalJson = '''{
  "archivo": "/lib/pages/00_Principal/barra_principal.dart",
  "clase": "BarraPrincipal",
  "arbol": {
    "type": "FondoApli",
    "propio": true,
    "sourceFile": "lib/widgets/fondo_apli.dart",
    "children": [
      {
        "type": "Scaffold",
        "propio": false,
        "argumento": "child",
        "children": [
          {
            "type": "AppBar",
            "propio": false,
            "argumento": "appBar",
            "children": [
              {
                "type": "Text",
                "propio": false,
                "argumento": "title",
                "texto": "CalcaApp Principal"
              },
              {
                "type": "IconButton",
                "propio": false,
                "argumento": "actions",
                "iconLeading": "settings",
                "children": [
                  {
                    "type": "Icon",
                    "propio": false,
                    "argumento": "icon"
                  }
                ]
              },
              {
                "type": "TrofeoPuntosChica",
                "propio": true,
                "sourceFile": "lib/widgets/trofeo_punto_chica.dart",
                "argumento": "actions"
              }
            ]
          },
          {
            "type": "DrawerPrincipal",
            "propio": true,
            "sourceFile": "lib/pages/00_Principal/drawer_principal.dart",
            "argumento": "drawer"
          },
          {
            "type": "PageView",
            "propio": false,
            "argumento": "body",
            "constructorNombrado": "builder",
            "children": [
              {
                "type": "NeverScrollableScrollPhysics",
                "propio": false,
                "argumento": "physics"
              }
            ]
          },
          {
            "type": "SafeArea",
            "propio": false,
            "argumento": "bottomNavigationBar",
            "children": [
              {
                "type": "NavigationBar",
                "propio": false,
                "argumento": "child",
                "children": [
                  {
                    "type": "Duration",
                    "propio": false,
                    "argumento": "animationDuration"
                  },
                  {
                    "type": "NavigationDestination",
                    "propio": false,
                    "argumento": "destinations",
                    "generadoDinamicamente": true,
                    "children": [
                      {
                        "type": "Icon",
                        "propio": false,
                        "argumento": "icon"
                      }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}''';

/// Genera el nodo raíz de la demo real para el canvas.
PieceNode obtenerArbolDemo() {
  final mapa = jsonDecode(kDemoBarraPrincipalJson) as Map<String, dynamic>;
  final arbol = mapa['arbol'] as Map<String, dynamic>;
  final raiz = PieceNode.fromJson(arbol, esRaiz: true);
  autoLayout(raiz);
  return raiz;
}

/// Hijos pre-definidos para widgets propios cuando se corre en modo demo web
/// sin un servidor local conectado. Permite experimentar la expansión de AST
/// en vivo en el navegador.
List<PieceNode>? obtenerHijosDemoPara(String clase) {
  if (clase == 'TrofeoPuntosChica') {
    return [
      PieceNode(
        type: 'Container',
        propio: false,
        argumento: 'child',
        children: [
          PieceNode(
            type: 'Row',
            propio: false,
            children: [
              PieceNode(
                type: 'Icon',
                propio: false,
                iconLeading: 'emoji_events',
                argumento: 'children',
              ),
              PieceNode(
                type: 'Text',
                propio: false,
                texto: '120 pts',
                argumento: 'children',
              ),
            ],
          ),
        ],
      ),
    ];
  } else if (clase == 'DrawerPrincipal') {
    return [
      PieceNode(
        type: 'Drawer',
        propio: false,
        children: [
          PieceNode(
            type: 'ListView',
            propio: false,
            children: [
              PieceNode(
                type: 'DrawerHeader',
                propio: false,
                children: [
                  PieceNode(
                    type: 'Text',
                    propio: false,
                    texto: 'Menú CalcaApp',
                  ),
                ],
              ),
              PieceNode(
                type: 'ListTile',
                propio: false,
                iconLeading: 'home',
                texto: 'Inicio',
              ),
              PieceNode(
                type: 'ListTile',
                propio: false,
                iconLeading: 'palette',
                texto: 'Plantillas',
              ),
              PieceNode(
                type: 'ListTile',
                propio: false,
                iconLeading: 'settings',
                texto: 'Configuración',
              ),
            ],
          ),
        ],
      ),
    ];
  } else if (clase == 'FondoApli') {
    return [
      PieceNode(
        type: 'Stack',
        propio: false,
        children: [
          PieceNode(
            type: 'Container',
            propio: false,
            texto: 'Gradiente de fondo',
          ),
        ],
      ),
    ];
  }
  return null;
}
