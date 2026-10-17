import 'package:flutter/material.dart';

import '../core/calculus.dart';
import '../core/expr.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/inputs.dart';
import '../widgets/module_scaffold.dart';
import '../widgets/plot.dart';

class IntegrationScreen extends StatefulWidget {
  const IntegrationScreen({super.key});

  @override
  State<IntegrationScreen> createState() => _IntegrationScreenState();
}

class _IntegrationScreenState extends State<IntegrationScreen> {
  final _f = TextEditingController(text: '0.2 + 25x - 200x^2 + 675x^3 - 900x^4 + 400x^5');
  final _a = TextEditingController(text: '0');
  final _b = TextEditingController(text: '0.8');
  int _n = 4;
  final _exact = TextEditingController(text: '1.640533');

  static const _presets = [
    ['0.2 + 25x - 200x^2 + 675x^3 - 900x^4 + 400x^5', '0', '0.8', '1.640533'],
    ['sin(x)', '0', 'pi', '2'],
    ['exp(-x^2)', '0', '1', '0.7468241328'],
    ['1/x', '1', 'e', '1'],
    ['sqrt(1 - x^2)', '-1', '1', 'pi/2'],
  ];
  static const _names = ['Chapra polynomial', 'sin x on [0, π]', 'e^(−x²)', '1/x on [1, e]', 'Semicircle'];

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final e = Expr.tryParse(_f.text);
    final a = numOf(_a, 0), b = numOf(_b, 1);
    final exact = evalNumber(_exact.text);

    final rows = <List<String>>[];
    double? best;
    List<List<double>>? romberg;
    ({double value, int evals})? adapt;
    if (e != null && b != a) {
      final f = e.fn();
      adapt = Integration.adaptive(f, a, b, tol: 1e-12);
      best = exact ?? adapt.value;
      romberg = Integration.romberg(f, a, b, levels: 6);
      final n3 = _n % 3 == 0 ? _n : _n + (3 - _n % 3);
      final n2 = _n.isEven ? _n : _n + 1;
      final entries = <(String, String, double, int)>[
        ('Trapezoidal', 'n = $_n', Integration.trapezoid(f, a, b, _n), _n + 1),
        ('Simpson 1/3', 'n = $n2', Integration.simpson13(f, a, b, _n), n2 + 1),
        ('Simpson 3/8', 'n = $n3', Integration.simpson38(f, a, b, _n), n3 + 1),
        ('Gauss-Legendre', '2-point', Integration.gaussLegendre(f, a, b, 2), 2),
        ('Gauss-Legendre', '3-point', Integration.gaussLegendre(f, a, b, 3), 3),
        ('Gauss-Legendre', '6-point', Integration.gaussLegendre(f, a, b, 6), 6),
        ('Romberg', 'O(h¹²)', romberg.last.last, 33),
        ('Adaptive Simpson', 'tol 1e−12', adapt.value, adapt.evals),
      ];
      for (final (name, detail, v, evals) in entries) {
        final et = best != 0 ? ((best - v) / best).abs() * 100 : (best - v).abs();
        rows.add([name, detail, fmt(v, sig: 10), fmt(et, sig: 3), '$evals']);
      }
    }

    return ModuleScaffold(
      title: 'Numerical integration',
      theory: _theory,
      children: [
        Presets(
          labels: _names,
          onPick: (i) => setState(() {
            _f.text = _presets[i][0];
            _a.text = _presets[i][1];
            _b.text = _presets[i][2];
            _exact.text = _presets[i][3];
          }),
        ),
        const SizedBox(height: 12),
        ExprField(controller: _f, onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: NumField(controller: _a, label: 'a (lower)', onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Expanded(child: NumField(controller: _b, label: 'b (upper)', onChanged: (_) => setState(() {}))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Stepper2(label: 'Segments n', value: _n, min: 1, max: 64, onChanged: (v) => setState(() => _n = v)),
            const SizedBox(width: 12),
            Expanded(child: NumField(controller: _exact, label: 'Exact (optional)', onChanged: (_) => setState(() {}))),
          ],
        ),
        const SizedBox(height: 16),
        if (e == null)
          const ResultCard(label: 'Input', value: 'Check f(x)', ok: false)
        else if (adapt != null)
          ResultCard(
            label: '∫ f(x) dx from ${fmt(a)} to ${fmt(b)}',
            value: fmt(adapt.value, sig: 12),
            sub: 'Adaptive Simpson, ${adapt.evals} function evaluations.${exact != null ? ' Exact value: ${fmt(exact, sig: 10)}' : ''}',
          ),
        if (e != null)
          Section(
            'Graph${_n <= 16 ? ' with trapezoids (n = $_n)' : ''}',
            child: PlotView(
              xMin: a - (b - a).abs() * 0.1,
              xMax: b + (b - a).abs() * 0.1,
              series: [
                AreaSeries(e.fn(), a, b, c.accent),
                FnSeries(e.fn(), c.accent, label: 'f(x)'),
                if (_n <= 16)
                  PointSeries([
                    for (var i = 0; i <= _n; i++) ...[
                      Offset(a + (b - a) * i / _n, 0),
                      Offset(a + (b - a) * i / _n, e.at(a + (b - a) * i / _n)),
                      if (i < _n) Offset(a + (b - a) * (i + 1) / _n, e.at(a + (b - a) * (i + 1) / _n)),
                      if (i < _n) Offset(a + (b - a) * (i + 1) / _n, 0),
                      if (i < _n) Offset(a + (b - a) * i / _n, 0),
                    ]
                  ], seriesColors[1], strokeWidth: 1.4),
              ],
            ),
          ),
        if (rows.isNotEmpty)
          Section(
            'Methods compared',
            child: ResultTable(
              columns: [
                'Method',
                'Detail',
                'Integral',
                exact != null ? '|εt| %' : '|ε| % vs adaptive',
                'f evals',
              ],
              rows: rows,
            ),
          ),
        if (romberg != null)
          Section(
            'Romberg tableau',
            child: ResultTable(
              columns: ['h', for (var j = 0; j < romberg.length; j++) 'O(h${_sup(2 * (j + 1))})'],
              rows: [
                for (var k = 0; k < romberg.length; k++)
                  [
                    fmt((b - a) / (1 << k), sig: 5),
                    for (var j = 0; j < romberg.length; j++) j <= k ? fmt(romberg[k][j], sig: 10) : '',
                  ]
              ],
              highlightRow: romberg.length - 1,
            ),
          ),
        if (e != null && b != a)
          Section(
            'Trapezoidal error vs n (log scale)',
            child: PlotView(
              height: 200,
              logY: true,
              xLabel: 'segments n',
              series: [
                PointSeries([
                  for (final n in [1, 2, 4, 8, 16, 32, 64, 128])
                    Offset(n.toDouble(), (Integration.trapezoid(e.fn(), a, b, n) - (best ?? 0)).abs()),
                ], c.accent, dots: true, label: 'trapezoid'),
                PointSeries([
                  for (final n in [2, 4, 8, 16, 32, 64, 128])
                    Offset(n.toDouble(), (Integration.simpson13(e.fn(), a, b, n) - (best ?? 0)).abs()),
                ], seriesColors[1], dots: true, label: 'Simpson 1/3'),
              ],
            ),
          ),
      ],
    );
  }

  static String _sup(int n) {
    const d = '⁰¹²³⁴⁵⁶⁷⁸⁹';
    return n.toString().split('').map((ch) => d[int.parse(ch)]).join();
  }

  static const _theory = '''Newton-Cotes formulas replace f(x) with a polynomial on equal segments:
• Trapezoidal: I ≈ h/2 [f₀ + 2Σfᵢ + fₙ], error O(h²)
• Simpson 1/3 (n even): I ≈ h/3 [f₀ + 4Σf_odd + 2Σf_even + fₙ], error O(h⁴)
• Simpson 3/8 (n multiple of 3): exact for cubics, error O(h⁴)

Romberg integration applies Richardson extrapolation to trapezoidal results with h, h/2, h/4…, removing error terms one order at a time.

Gauss-Legendre quadrature chooses both points and weights optimally: n points integrate polynomials of degree 2n − 1 exactly.

Adaptive Simpson subdivides only where f changes quickly, to meet a tolerance with few evaluations.

True percent relative error: εt = |(true − approx)/true| × 100%.''';
}
