import 'package:flutter/material.dart';

import '../core/calculus.dart';
import '../core/expr.dart';
import '../core/roots.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/inputs.dart';
import '../widgets/module_scaffold.dart';
import '../widgets/plot.dart';

class DifferentiationScreen extends StatefulWidget {
  const DifferentiationScreen({super.key});

  @override
  State<DifferentiationScreen> createState() => _DifferentiationScreenState();
}

class _DifferentiationScreenState extends State<DifferentiationScreen> {
  final _f = TextEditingController(text: '-0.1x^4 - 0.15x^3 - 0.5x^2 - 0.25x + 1.2');
  final _x = TextEditingController(text: '0.5');
  final _h = TextEditingController(text: '0.25');
  final _exact = TextEditingController(text: '-0.9125');

  static const _presets = [
    ['-0.1x^4 - 0.15x^3 - 0.5x^2 - 0.25x + 1.2', '0.5', '0.25', '-0.9125'],
    ['sin(x)', 'pi/4', '0.1', 'cos(pi/4)'],
    ['exp(x)', '1', '0.1', 'e'],
    ['ln(x)', '2', '0.1', '0.5'],
  ];
  static const _names = ['Chapra 4.4', 'sin x at π/4', 'eˣ at 1', 'ln x at 2'];

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final e = Expr.tryParse(_f.text);
    final x0 = numOf(_x, 0), h = numOf(_h, 0.1);
    final exact = evalNumber(_exact.text);
    final f = e?.fn();
    final double rv = f == null ? double.nan : (exact ?? Differentiation.reference(f, x0));
    final rows = f == null || h == 0 ? <DiffRow>[] : Differentiation.table(f, x0, h);

    return ModuleScaffold(
      title: 'Numerical differentiation',
      theory: '''Finite-difference formulas approximate f′(x) from nearby values:
• Forward: [f(x+h) − f(x)] / h, error O(h)
• Backward: [f(x) − f(x−h)] / h, error O(h)
• Centred: [f(x+h) − f(x−h)] / 2h, error O(h²)
Higher-accuracy versions use more points (O(h²) one-sided, O(h⁴) centred).

Richardson extrapolation combines centred estimates with h and h/2:
D ≈ (4 D(h/2) − D(h)) / 3, error O(h⁴).

Halving h reduces truncation error, but very small h increases round-off error, so there is an optimum step size (see the error plot).''',
      children: [
        Presets(
          labels: _names,
          onPick: (i) => setState(() {
            _f.text = _presets[i][0];
            _x.text = _presets[i][1];
            _h.text = _presets[i][2];
            _exact.text = _presets[i][3];
          }),
        ),
        const SizedBox(height: 12),
        ExprField(controller: _f, onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: NumField(controller: _x, label: 'At x', onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Expanded(child: NumField(controller: _h, label: 'Step h', onChanged: (_) => setState(() {}))),
          ],
        ),
        const SizedBox(height: 10),
        NumField(controller: _exact, label: 'Exact f′(x) (optional)', onChanged: (_) => setState(() {})),
        const SizedBox(height: 16),
        if (f == null)
          const ResultCard(label: 'Input', value: 'Check f(x)', ok: false)
        else ...[
          ResultCard(
            label: "f′(${fmt(x0, sig: 6)})",
            value: fmt(rv, sig: 12),
            sub: exact != null
                ? 'Exact value you entered.'
                : 'High-accuracy reference (Richardson, small h). f″ ≈ ${fmt(Differentiation.second(f, x0, 1e-3 * (1 + x0.abs())), sig: 6)}',
          ),
          Section(
            'Formulas compared (h = ${fmt(h)})',
            child: ResultTable(
              columns: const ['Formula', 'Error order', 'f′ estimate', '|εt| %'],
              rows: [
                for (final r in rows)
                  [r.name, r.order, fmt(r.value, sig: 10), rv == 0 ? fmt((r.value - rv).abs(), sig: 3) : fmt(((r.value - rv) / rv).abs() * 100, sig: 3)]
              ],
            ),
          ),
          Section(
            'f(x) and f′(x)',
            child: Column(
              children: [
                PlotView(
                  xMin: x0 - 3,
                  xMax: x0 + 3,
                  series: [
                    FnSeries(f, c.accent, label: 'f(x)'),
                    FnSeries((v) => numericDerivative(f, v), seriesColors[1], label: "f′(x)"),
                    FnSeries((v) => f(x0) + rv * (v - x0), seriesColors[2], label: 'tangent', strokeWidth: 1.4),
                    MarkerSeries([Offset(x0, f(x0))], seriesColors[2]),
                  ],
                ),
                PlotLegend([
                  FnSeries(f, c.accent, label: 'f(x)'),
                  FnSeries(f, seriesColors[1], label: "f′(x)"),
                  FnSeries(f, seriesColors[2], label: 'tangent at x'),
                ]),
              ],
            ),
          ),
          Section(
            'Error vs step size (truncation vs round-off)',
            child: PlotView(
              height: 210,
              logY: true,
              xLabel: '−log₁₀ h',
              series: [
                PointSeries([
                  for (var k = 1; k <= 14; k++)
                    () {
                      final hh = 1 / _pow10(k);
                      final v = (f(x0 + hh) - f(x0 - hh)) / (2 * hh);
                      return Offset(k.toDouble(), (v - rv).abs());
                    }()
                ], c.accent, dots: true, label: 'centred'),
                PointSeries([
                  for (var k = 1; k <= 14; k++)
                    () {
                      final hh = 1 / _pow10(k);
                      final v = (f(x0 + hh) - f(x0)) / hh;
                      return Offset(k.toDouble(), (v - rv).abs());
                    }()
                ], seriesColors[1], dots: true, label: 'forward'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static double _pow10(int k) {
    var r = 1.0;
    for (var i = 0; i < k; i++) {
      r *= 10;
    }
    return r;
  }
}

// ---------------------------------------------------------------------------

class OptimizationScreen extends StatefulWidget {
  const OptimizationScreen({super.key});

  @override
  State<OptimizationScreen> createState() => _OptimizationScreenState();
}

class _OptimizationScreenState extends State<OptimizationScreen> {
  final _f = TextEditingController(text: '2sin(x) - x^2/10');
  final _a = TextEditingController(text: '0');
  final _b = TextEditingController(text: '4');
  bool _max = true;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final e = Expr.tryParse(_f.text);
    final a = numOf(_a, 0), b = numOf(_b, 1);
    final r = e == null || b <= a ? null : Roots.golden(e.fn(), a, b, maximize: _max);
    return ModuleScaffold(
      title: 'Optimisation',
      theory: '''Golden-section search finds the maximum or minimum of a unimodal function on [xl, xu].

Two interior points are placed using the golden ratio φ = (√5 − 1)/2 ≈ 0.618:
x₁ = xl + d, x₂ = xu − d, with d = φ(xu − xl).

The sub-interval that cannot contain the optimum is discarded. Because of the golden ratio, one interior point is reused each step, so only one new function evaluation is needed per iteration. The interval shrinks by 0.618 each time.''',
      children: [
        Presets(
          labels: const ['2 sin x − x²/10 (max)', 'x² − 4x + 5 (min)', 'x e^(−x) (max)'],
          onPick: (i) => setState(() {
            const p = [
              ['2sin(x) - x^2/10', '0', '4', 'max'],
              ['x^2 - 4x + 5', '0', '5', 'min'],
              ['x exp(-x)', '0', '4', 'max'],
            ];
            _f.text = p[i][0];
            _a.text = p[i][1];
            _b.text = p[i][2];
            _max = p[i][3] == 'max';
          }),
        ),
        const SizedBox(height: 12),
        ExprField(controller: _f, onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: NumField(controller: _a, label: 'xl', onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Expanded(child: NumField(controller: _b, label: 'xu', onChanged: (_) => setState(() {}))),
          ],
        ),
        const SizedBox(height: 12),
        Segmented<bool>(
          values: const [true, false],
          selected: _max,
          label: (v) => v ? 'Maximum' : 'Minimum',
          onChanged: (v) => setState(() => _max = v),
        ),
        const SizedBox(height: 16),
        if (r == null)
          const ResultCard(label: 'Input', value: 'Check f(x) and the interval', ok: false)
        else ...[
          ResultCard(
            label: _max ? 'Maximum' : 'Minimum',
            value: 'x = ${fmt(r.x, sig: 10)}',
            sub: 'f(x) = ${fmt(r.fx, sig: 10)} · ${r.rows.length} iterations',
          ),
          Section(
            'Graph',
            child: PlotView(
              xMin: a - (b - a) * 0.1,
              xMax: b + (b - a) * 0.1,
              series: [
                FnSeries(e!.fn(), c.accent, label: 'f(x)'),
                VLineSeries([a, b], c.inkDim),
                MarkerSeries([Offset(r.x, r.fx)], seriesColors[1]),
              ],
            ),
          ),
          Section(
            'Iterations',
            child: ResultTable(
              columns: GoldenResult.columns,
              rows: [
                for (final row in r.rows)
                  ['${row.i}', for (final v in row.values.skip(1)) v.isNaN ? '—' : fmt(v, sig: 9)]
              ],
            ),
          ),
        ],
      ],
    );
  }
}
