import 'package:flutter/material.dart';

import '../core/expr.dart';
import '../core/roots.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/inputs.dart';
import '../widgets/module_scaffold.dart';
import '../widgets/plot.dart';

class PlotterScreen extends StatefulWidget {
  const PlotterScreen({super.key});

  @override
  State<PlotterScreen> createState() => _PlotterScreenState();
}

class _PlotterScreenState extends State<PlotterScreen> {
  final List<TextEditingController> _fs = [
    TextEditingController(text: 'sin(x)'),
    TextEditingController(text: 'x^3/20 - x'),
  ];
  final _x0 = TextEditingController(text: '-6');
  final _x1 = TextEditingController(text: '6');
  bool _showRoots = true;
  bool _showExtrema = true;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final xMin = numOf(_x0, -6), xMax = numOf(_x1, 6);
    final fns = <(int, double Function(double))>[];
    for (var i = 0; i < _fs.length; i++) {
      final e = Expr.tryParse(_fs[i].text);
      if (e != null) fns.add((i, e.fn()));
    }
    final markers = <Offset>[];
    final features = <String>[];
    for (final (i, f) in fns) {
      if (_showRoots && xMax > xMin) {
        for (final r in Roots.scan(f, xMin, xMax, samples: 1500)) {
          markers.add(Offset(r, 0));
          features.add('f${i + 1}: root at x = ${fmt(r, sig: 8)}');
        }
      }
      if (_showExtrema && xMax > xMin) {
        double d(double x) => numericDerivative(f, x);
        for (final r in Roots.scan(d, xMin, xMax, samples: 1500)) {
          final y = f(r);
          if (!y.isFinite) continue;
          final curv = (f(r + 1e-4) - 2 * y + f(r - 1e-4));
          final kind = curv > 0 ? 'minimum' : (curv < 0 ? 'maximum' : 'stationary point');
          markers.add(Offset(r, y));
          features.add('f${i + 1}: $kind at (${fmt(r, sig: 6)}, ${fmt(y, sig: 6)})');
        }
      }
    }

    return ModuleScaffold(
      title: 'Function plotter',
      theory: '''Plot up to six functions of x.

Pinch to zoom, drag to pan, double-tap to reset the view. Tap the graph to trace the value of every function at that x.

Roots are found by scanning for sign changes and refining with bisection. Turning points are roots of the numerical derivative f′(x) (central differences), classified by the sign of the second difference.''',
      children: [
        for (var i = 0; i < _fs.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 18, right: 8),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: seriesColors[i % seriesColors.length], shape: BoxShape.circle),
                  ),
                ),
                Expanded(
                  child: ExprField(
                    controller: _fs[i],
                    label: 'f${i + 1}(x)',
                    prefix: 'f${i + 1}(x) =',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_fs.length > 1)
                  IconButton(
                    padding: const EdgeInsets.only(top: 10),
                    onPressed: () => setState(() => _fs.removeAt(i)),
                    icon: Icon(Icons.close_rounded, color: c.inkDim),
                  ),
              ],
            ),
          ),
        if (_fs.length < 6)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _fs.add(TextEditingController(text: 'x^2/10'))),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add function'),
            ),
          ),
        Row(
          children: [
            Expanded(child: NumField(controller: _x0, label: 'x from', onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Expanded(child: NumField(controller: _x1, label: 'x to', onChanged: (_) => setState(() {}))),
          ],
        ),
        const SizedBox(height: 14),
        PlotView(
          height: 340,
          xMin: xMin,
          xMax: xMax > xMin ? xMax : xMin + 1,
          series: [
            for (final (i, f) in fns) FnSeries(f, seriesColors[i % seriesColors.length], label: 'f${i + 1}'),
            if (markers.isNotEmpty) MarkerSeries(markers, c.ink),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('Roots'),
              selected: _showRoots,
              onSelected: (v) => setState(() => _showRoots = v),
            ),
            FilterChip(
              label: const Text('Turning points'),
              selected: _showExtrema,
              onSelected: (v) => setState(() => _showExtrema = v),
            ),
          ],
        ),
        if (features.isNotEmpty)
          Section(
            'Features in view',
            child: NLCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final s in features.take(30))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(s, style: NLText.reading(12.5, c.ink)),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
