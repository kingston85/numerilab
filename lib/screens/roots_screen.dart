import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/expr.dart';
import '../core/roots.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/inputs.dart';
import '../widgets/module_scaffold.dart';
import '../widgets/plot.dart';

class RootsScreen extends StatefulWidget {
  const RootsScreen({super.key});

  @override
  State<RootsScreen> createState() => _RootsScreenState();
}

class _RootsScreenState extends State<RootsScreen> {
  final _f = TextEditingController(text: 'x^3 - x - 2');
  final _g = TextEditingController(text: '(x + 2)^(1/3)');
  final _df = TextEditingController();
  final _a = TextEditingController(text: '1');
  final _b = TextEditingController(text: '2');
  final _x0 = TextEditingController(text: '1.5');
  final _x1 = TextEditingController(text: '2');
  final _tol = TextEditingController(text: '1e-6');
  final _max = TextEditingController(text: '50');
  RootMethod _method = RootMethod.bisection;
  RootResult? _res;
  String? _error;

  static const _presets = [
    ['x^3 - x - 2', '1', '2', '1.5', '(x + 2)^(1/3)'],
    ['exp(-x) - x', '0', '1', '0', 'exp(-x)'],
    ['cos(x) - x', '0', '1', '0.5', 'cos(x)'],
    ['x^2 - 2', '1', '2', '1', '(x + 2/x)/2'],
    ['ln(x) + x - 3', '1', '3', '2', '3 - ln(x)'],
  ];
  static const _presetNames = ['x³ − x − 2', 'e⁻ˣ − x', 'cos x − x', '√2', 'ln x + x − 3'];

  @override
  void initState() {
    super.initState();
    _run();
  }

  void _run() {
    setState(() {
      _error = null;
      _res = null;
      try {
        final f = Expr.parse(_f.text).fn();
        final tol = numOf(_tol, 1e-6);
        final maxIt = numOf(_max, 50).round().clamp(1, 1000).toInt();
        switch (_method) {
          case RootMethod.bisection:
          case RootMethod.falsePosition:
            _res = Roots.bracketing(f, numOf(_a, 0), numOf(_b, 1),
                falsePosition: _method == RootMethod.falsePosition, tolPercent: tol, maxIter: maxIt);
            break;
          case RootMethod.newton:
            final df = _df.text.trim().isEmpty ? null : Expr.parse(_df.text).fn();
            _res = Roots.newton(f, numOf(_x0, 0), df: df, tolPercent: tol, maxIter: maxIt);
            break;
          case RootMethod.secant:
            _res = Roots.secant(f, numOf(_x0, 0), numOf(_x1, 1), tolPercent: tol, maxIter: maxIt);
            break;
          case RootMethod.fixedPoint:
            final g = Expr.parse(_g.text).fn();
            _res = Roots.fixedPoint(g, numOf(_x0, 0), f: f, tolPercent: tol, maxIter: maxIt);
            break;
        }
      } on ExprError catch (e) {
        _error = e.message;
      } catch (e) {
        _error = e.toString();
      }
    });
  }

  void _preset(int i) {
    final p = _presets[i];
    _f.text = p[0];
    _a.text = p[1];
    _b.text = p[2];
    _x0.text = p[3];
    _x1.text = (numOf(_x0, 0) + 0.5).toString();
    _g.text = p[4];
    _df.clear();
    _run();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final f = Expr.tryParse(_f.text)?.fn();
    final res = _res;
    final its = res?.iterates ?? const <double>[];

    // Plot window around the bracket / iterates.
    double lo, hi;
    if (_method.bracketing) {
      lo = numOf(_a, 0);
      hi = numOf(_b, 1);
    } else {
      final pts = [numOf(_x0, 0), if (res != null && res.root.isFinite) res.root, ...its.where((v) => v.isFinite).take(6)];
      lo = pts.reduce(math.min);
      hi = pts.reduce(math.max);
    }
    final span = (hi - lo).abs() < 1e-9 ? 2.0 : (hi - lo);
    final xMin = lo - span * 0.35, xMax = hi + span * 0.35;

    return ModuleScaffold(
      title: 'Roots of equations',
      theory: _theory,
      children: [
        Presets(labels: _presetNames, onPick: _preset),
        const SizedBox(height: 12),
        ExprField(controller: _f, onChanged: (_) => _run()),
        const SizedBox(height: 14),
        Segmented<RootMethod>(
          values: RootMethod.values,
          selected: _method,
          label: (m) => m.label,
          onChanged: (m) {
            _method = m;
            _run();
          },
        ),
        const SizedBox(height: 10),
        FormulaBox(_method.formula, note: _methodNote(_method)),
        const SizedBox(height: 14),
        if (_method == RootMethod.fixedPoint) ...[
          ExprField(controller: _g, label: 'g(x) for x = g(x)', prefix: 'g(x) =', onChanged: (_) => _run()),
          const SizedBox(height: 12),
        ],
        if (_method == RootMethod.newton) ...[
          TextField(
            controller: _df,
            onChanged: (_) => _run(),
            style: NLText.reading(15, c.ink),
            decoration: const InputDecoration(
              labelText: "f′(x) (optional — numeric if blank)",
              prefixText: "f′(x) = ",
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            if (_method.bracketing) ...[
              Expanded(child: NumField(controller: _a, label: 'xl (lower)', onChanged: (_) => _run())),
              const SizedBox(width: 10),
              Expanded(child: NumField(controller: _b, label: 'xu (upper)', onChanged: (_) => _run())),
            ] else ...[
              Expanded(child: NumField(controller: _x0, label: 'x₀', onChanged: (_) => _run())),
              if (_method == RootMethod.secant) ...[
                const SizedBox(width: 10),
                Expanded(child: NumField(controller: _x1, label: 'x₁', onChanged: (_) => _run())),
              ],
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: NumField(controller: _tol, label: 'Stop when εa <', suffix: '%', onChanged: (_) => _run())),
            const SizedBox(width: 10),
            Expanded(child: NumField(controller: _max, label: 'Max iterations', onChanged: (_) => _run())),
          ],
        ),
        const SizedBox(height: 18),
        if (_error != null)
          ResultCard(label: 'Error', value: 'Check input', sub: _error, ok: false)
        else if (res != null)
          ResultCard(
            label: res.converged ? 'Root' : 'Not converged',
            value: res.root.isFinite ? fmt(res.root, sig: 12) : '—',
            ok: res.converged,
            sub: '${res.message}\nf(root) = ${fmt(res.fRoot, sig: 4)}',
          ),
        if (f != null)
          Section(
            'Graph',
            child: PlotView(
              xMin: xMin,
              xMax: xMax,
              series: [
                FnSeries(f, c.accent, label: 'f(x)'),
                if (_method == RootMethod.fixedPoint) ...[
                  if (Expr.tryParse(_g.text) != null) FnSeries(Expr.parse(_g.text).fn(), seriesColors[2], label: 'g(x)'),
                  FnSeries((x) => x, c.inkDim, label: 'y = x', strokeWidth: 1.2),
                ],
                if (_method.bracketing) VLineSeries([numOf(_a, 0), numOf(_b, 1)], c.inkDim),
                if (its.isNotEmpty)
                  PointSeries([for (final x in its.take(12)) Offset(x, _method == RootMethod.fixedPoint ? x : f(x))], seriesColors[1],
                      line: false, dots: true, label: 'iterates'),
                if (res != null && res.root.isFinite)
                  MarkerSeries([Offset(res.root, _method == RootMethod.fixedPoint ? res.root : 0)], seriesColors[1]),
              ],
            ),
          ),
        if (res != null && res.rows.length >= 2)
          Section(
            'Convergence (εa % per iteration, log scale)',
            child: PlotView(
              height: 200,
              logY: true,
              xLabel: 'iteration',
              series: [
                PointSeries([
                  for (final r in res.rows)
                    if (r.ea != null && r.ea! > 0) Offset(r.i.toDouble(), r.ea!)
                ], seriesColors[2], dots: true),
              ],
            ),
          ),
        if (res != null && res.rows.isNotEmpty)
          Section(
            'Iterations',
            child: ResultTable(
              columns: res.columns,
              rows: [
                for (final r in res.rows)
                  [for (var k = 0; k < r.values.length; k++) k == 0 ? '${r.i}' : (r.values[k].isNaN ? '—' : fmt(r.values[k], sig: 9))]
              ],
              highlightRow: res.converged ? res.rows.length - 1 : null,
            ),
          ),
        if (f != null) _AllRoots(f: f),
      ],
    );
  }

  static String _methodNote(RootMethod m) {
    switch (m) {
      case RootMethod.bisection:
        return 'Bracketing: always converges if f(xl)·f(xu) < 0. Halves the interval each step (linear convergence).';
      case RootMethod.falsePosition:
        return 'Bracketing: uses the chord through the bounds. Modified version halves a stuck bound’s f to avoid slow one-sided convergence.';
      case RootMethod.newton:
        return 'Open method: quadratic convergence near a simple root, but can diverge with a poor x₀ or where f′ ≈ 0.';
      case RootMethod.secant:
        return 'Open method: like Newton with a finite-difference slope. Superlinear convergence (order ≈ 1.618).';
      case RootMethod.fixedPoint:
        return 'Rearrange f(x) = 0 as x = g(x). Converges when |g′(x)| < 1 near the root (the cobweb in the graph).';
    }
  }

  static const _theory = '''A root of f(x) is a value where f(x) = 0.

Bracketing methods (bisection, false position) start with an interval [xl, xu] where f changes sign. They always converge, but slowly.

Open methods (Newton-Raphson, secant, fixed-point) start from one or two guesses. They converge much faster when they work, but can diverge.

Approximate relative error:
εa = |(x_new − x_old) / x_new| × 100%

Iteration stops when εa falls below the tolerance you set.''';
}

class _AllRoots extends StatefulWidget {
  final double Function(double) f;
  const _AllRoots({required this.f});

  @override
  State<_AllRoots> createState() => _AllRootsState();
}

class _AllRootsState extends State<_AllRoots> {
  final _lo = TextEditingController(text: '-10');
  final _hi = TextEditingController(text: '10');

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final roots = Roots.scan(widget.f, numOf(_lo, -10), numOf(_hi, 10), samples: 2000);
    return Section(
      'Find all roots in an interval',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: NumField(controller: _lo, label: 'From', onChanged: (_) => setState(() {}))),
              const SizedBox(width: 10),
              Expanded(child: NumField(controller: _hi, label: 'To', onChanged: (_) => setState(() {}))),
            ],
          ),
          const SizedBox(height: 10),
          if (roots.isEmpty)
            Text('No sign changes found in this interval.', style: NLText.body(c.inkDim, size: 13))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in roots)
                  Tag('x = ${fmt(r, sig: 10)}', color: c.accent),
              ],
            ),
        ],
      ),
    );
  }
}
