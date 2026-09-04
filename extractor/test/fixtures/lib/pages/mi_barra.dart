import 'package:flutter/material.dart';
import 'package:fixture_app/widgets/mi_widget_propio.dart';
import 'package:fixture_app/widgets/mi_drawer.dart';
import 'package:fixture_app/widgets/mi_item.dart';

/// Fixture que imita la forma real de BarraPrincipal (CalcaApp):
/// StatefulWidget + State, un widget propio en las acciones del AppBar,
/// otro widget propio como drawer (2 "propios" hermanos -> punto de
/// decision), y una lista generada dinamicamente via .map().toList()
/// dentro de un constructor con nombre (ListView.builder).
class MiBarra extends StatefulWidget {
  const MiBarra({super.key});

  @override
  MiBarraState createState() => MiBarraState();
}

class MiBarraState extends State<MiBarra> {
  final List<String> _labels = const ['uno', 'dos', 'tres'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fixture'),
        actions: const [MiWidgetPropio()],
      ),
      drawer: const MiDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: _labels.isEmpty
            ? const Text('vacio')
            : ListView.builder(
                itemCount: _labels.length,
                itemBuilder: (context, index) => MiItem(label: _labels[index]),
              ),
      ),
    );
  }
}

/// Fixture del patron MODERNO de StatefulWidget: el tipo de retorno de
/// createState() es el generico `State<MiBarraModerna>` (no el nombre
/// concreto de la clase State), y la clase State real es privada. Bug
/// real encontrado contra codigo de CalcaApp: buscar una clase llamada
/// literalmente "State<MiBarraModerna>" siempre fallaba.
class MiBarraModerna extends StatefulWidget {
  const MiBarraModerna({super.key});

  @override
  State<MiBarraModerna> createState() => _MiBarraModernaState();
}

class _MiBarraModernaState extends State<MiBarraModerna> {
  @override
  Widget build(BuildContext context) {
    return const Text('moderna');
  }
}
