import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/expr.dart';
import '../core/linalg.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/inputs.dart';
import '../widgets/module_scaffold.dart';
import '../widgets/plot.dart';

enum LinMethod { gauss, lu, inverse, jacobi, seidel, eigen }

extension LinMethodX on LinMethod {
  String get label {
    switch (this) {
      case LinMethod.gauss:
        return 'Gauss (pivoting)';
      case LinMethod.lu:
        return 'LU decomposition';
      case LinMethod.inverse:
        return 'Inverse (Gauss-Jordan)';
      case LinMethod.jacobi:
        return 'Jacobi';
      case LinMethod.seidel:
        return 'Gauss-Seidel';
      case LinMethod.eigen:
        return 'Power method';
    }
  }
}

class LinearScreen extends StatefulWidget {
  const LinearScreen({super.key});

  @override
  State<LinearScreen> createState() => _LinearScreenState();
}

class _LinearScreenState extends State<LinearScreen> {
  int _n = 3;
  late List<List<TextEditingController>> _a;
  late List<TextEditingController> _b;
  LinMethod _method = LinMethod.gauss;
  final _tol = TextEditingController(text: '1e-6');
  final _lambda = TextEditingController(text: '1');

  static const _examples = <String, List<List<double>>>{
    'Chapra 9.5': [
      [3, -0.1, -0.2, 7.85],
      [0.1, 7, -0.3, -19.3],
      [0.3, -0.2, 10, 71.4],
    ],
    'Needs pivoting': [
      [0, 2, 3, 8],
      [4, 6, 7, -3],
      [2, 1, 6, 5],
    ],
    'Reactors (mass balance)': [
      [6, 0, -1, 0, 0, 50],
      [-3, 3, 0, 0, 0, 0],
      [0, -1, 9, 0, 0, 160],
      [0, -1, -8, 11, -2, 0],
      [-3, -1, 0, 0, 4, 0],
    ],
    'Ill-conditioned': [
      [1, 1, 2],
      [1, 1.0001, 2.0001],
    ],
  };

  @override
  void initState() {
    super.initState();
    _build(_n);
    _load(_examples.values.first);
  }

  void _build(int n) {
    _n = n;
    _a = List.generate(n, (i) => List.generate(n, (j) => TextEditingController(text: i == j ? '1' : '0')));
    _b = List.generate(n, (i) => TextEditingController(text: '0'));
  }

  void _resize(int n) {
    final oldA = _a, oldB = _b;
    _build(n);
    for (var i = 0; i < n && i < oldA.length; i++) {
      for (var j = 0; j < n && j < oldA.length; j++) {
        _a[i][j].text = oldA[i][j].text;
      }
      _b[i].text = oldB[i].text;
    }
    setState(() {});
  }

  void _load(List<List<double>> rows) {
    _build(rows.length);
    for (var i = 0; i < rows.length; i++) {
      for (var j = 0; j < rows.length; j++) {
        _a[i][j].text = fmt(rows[i][j]);
      }
      _b[i].text = fmt(rows[i][rows.length]);
    }
    setState(() {});
  }

  Mat? get _matA {
    final m = <List<double>>[];
    for (final r in _a) {
      final row = <double>[];
      for (final t in r) {
        final v = evalNumber(t.text);
        if (v == null) return null;
        row.add(v);
      }
      m.add(row);
    }
    return m;
  }

  Vec? get _vecB {
    final v = <double>[];
    for (final t in _b) {
      final x = evalNumber(t.text);
      if (x == null) return null;
      v.add(x);
    }
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final a = _matA, b = _vecB;
    return ModuleScaffold(
      title: 'Linear systems',
      theory: _theory,
      children: [
        Presets(labels: _examples.keys.toList(), onPick: (i) => _load(_examples.values.elementAt(i))),
        const SizedBox(height: 12),
        Row(
          children: [
            Stepper2(label: 'Size n', value: _n, min: 2, max: 8, onChanged: _resize),
            const Spacer(),
            Text('[A | b]', style: NLText.reading(13, c.inkDim)),
          ],
        ),
        const SizedBox(height: 10),
        MatrixEditor(a: _a, b: _method == LinMethod.eigen || _method == LinMethod.inverse ? null : _b, onChanged: () => setState(() {})),
        const SizedBox(height: 14),
        Segmented<LinMethod>(
          values: LinMethod.values,
          selected: _method,
          label: (m) => m.label,
          onChanged: (m) => setState(() => _method = m),
        ),
        if (_method == LinMethod.jacobi || _method == LinMethod.seidel) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: NumField(controller: _tol, label: 'Stop when εa <', suffix: '%', onChanged: (_) => setState(() {}))),
              if (_method == LinMethod.seidel) ...[
                const SizedBox(width: 10),
                Expanded(child: NumField(controller: _lambda, label: 'Relaxation λ', onChanged: (_) => setState(() {}))),
              ],
            ],
          ),
        ],
        const SizedBox(height: 18),
        if (a == null || b == null)
          const ResultCard(label: 'Input', value: 'Check the matrix', sub: 'Every cell must be a number.', ok: false)
        else
          _results(context, a, b),
      ],
    );
  }

  Widget _results(BuildContext context, Mat a, Vec b) {
    final c = context.nl;
    final cond = LinAlg.cond(a);
    final det = LinAlg.det(a);
    final info = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Tag('det(A) = ${fmt(det, sig: 6)}', color: det == 0 ? c.poor : c.inkDim),
        Tag('cond∞(A) = ${cond.isFinite ? fmt(cond, sig: 4) : '∞'}', color: cond > 1e4 ? c.fair : c.inkDim),
        Tag(LinAlg.diagonallyDominant(a) ? 'Diagonally dominant' : 'Not diagonally dominant',
            color: LinAlg.diagonallyDominant(a) ? c.good : c.inkDim),
      ],
    );
    try {
      switch (_method) {
        case LinMethod.gauss:
          final r = LinAlg.gauss(a, b);
          final res = LinAlg.residual(a, r.x, b);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _solution(context, r.x, extra: 'Residual ‖b − Ax‖∞ = ${fmt(normInf(res), sig: 3)}'),
              const SizedBox(height: 10),
              info,
              if (cond > 1e4) _condWarning(context, cond),
              Section(
                'Steps (${r.steps.length})',
                child: Column(children: [for (final s in r.steps) _StepCard(step: s)]),
              ),
            ],
          );
        case LinMethod.lu:
          final r = LinAlg.lu(a, b);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _solution(context, r.x!),
              const SizedBox(height: 10),
              info,
              Section('L (lower, unit diagonal)', child: _MatView(r.l)),
              Section('U (upper)', child: _MatView(r.u)),
              Section(
                'Row order P',
                child: Text('PA = LU with rows ${[for (final p in r.perm) 'R${p + 1}'].join(', ')}',
                    style: NLText.reading(13, c.ink)),
              ),
              Section('Forward substitution: L d = Pb', child: _vecView(context, 'd', r.d!)),
            ],
          );
        case LinMethod.inverse:
          final inv = LinAlg.inverse(a);
          final check = matMul(a, inv);
          var err = 0.0;
          for (var i = 0; i < a.length; i++) {
            for (var j = 0; j < a.length; j++) {
              err = err > (check[i][j] - (i == j ? 1 : 0)).abs() ? err : (check[i][j] - (i == j ? 1 : 0)).abs();
            }
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ResultCard(label: 'A⁻¹ computed', value: '${a.length} × ${a.length}', sub: 'Check: max |A·A⁻¹ − I| = ${fmt(err, sig: 3)}'),
              const SizedBox(height: 10),
              info,
              Section('A⁻¹', child: _MatView(inv)),
            ],
          );
        case LinMethod.jacobi:
        case LinMethod.seidel:
          final r = LinAlg.iterative(a, b,
              seidel: _method == LinMethod.seidel,
              tolPercent: numOf(_tol, 1e-6),
              lambda: _method == LinMethod.seidel ? numOf(_lambda, 1) : 1);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _solution(context, r.x, ok: r.converged, extra: r.message),
              const SizedBox(height: 10),
              info,
              Section(
                'Convergence (max εa %, log scale)',
                child: PlotView(
                  height: 190,
                  logY: true,
                  xLabel: 'iteration',
                  series: [
                    PointSeries([
                      for (var k = 0; k < r.history.length; k++)
                        if (r.history[k].last > 0) Offset(k + 1.0, r.history[k].last)
                    ], c.accent, dots: true),
                  ],
                ),
              ),
              Section(
                'Iterations',
                child: ResultTable(
                  columns: ['k', for (var i = 0; i < a.length; i++) 'x${i + 1}', 'max εa %'],
                  rows: [
                    for (var k = 0; k < r.history.length; k++)
                      ['${k + 1}', for (final v in r.history[k]) fmt(v, sig: 8)]
                  ],
                ),
              ),
            ],
          );
        case LinMethod.eigen:
          final r = LinAlg.powerMethod(a);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ResultCard(
                label: r.converged ? 'Dominant eigenvalue' : 'Not converged',
                value: fmt(r.value, sig: 10),
                ok: r.converged,
                sub: '${r.iterations} iterations of the power method.',
              ),
              const SizedBox(height: 10),
              info,
              Section('Eigenvector (scaled so the largest entry is 1)', child: _vecView(context, 'v', r.vector)),
            ],
          );
      }
    } on LinError catch (e) {
      return Column(children: [ResultCard(label: 'Cannot solve', value: 'Singular system', sub: e.message, ok: false), const SizedBox(height: 10), info]);
    }
  }

  Widget _condWarning(BuildContext context, double cond) {
    final c = context.nl;
    final digits = cond.isFinite ? (math.log(cond) / math.ln10).round() : 16;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        'Ill-conditioned: expect to lose about $digits significant digits. '
        'Small changes in A or b can change x a lot.',
        style: NLText.body(c.fair, size: 12.5),
      ),
    );
  }

  Widget _solution(BuildContext context, Vec x, {bool ok = true, String? extra}) {
    return ResultCard(
      label: ok ? 'Solution x' : 'Last iterate',
      value: [for (var i = 0; i < x.length; i++) 'x${i + 1} = ${fmt(x[i], sig: 10)}'].join('\n'),
      ok: ok,
      sub: extra,
    );
  }

  Widget _vecView(BuildContext context, String name, Vec v) {
    final c = context.nl;
    return NLCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < v.length; i++)
            Text('$name${i + 1} = ${fmt(v[i], sig: 10)}', style: NLText.reading(13.5, c.ink)),
        ],
      ),
    );
  }

  static const _theory = '''Solves A x = b for n equations in n unknowns.

Gauss elimination reduces [A | b] to upper-triangular form, then back-substitutes. Partial pivoting swaps in the row with the largest |pivot| to avoid division by zero and reduce round-off.

LU decomposition factors PA = LU once; each new b then needs only forward (Ld = Pb) and back (Ux = d) substitution.

Gauss-Jordan reduces [A | I] to [I | A⁻¹].

Jacobi and Gauss-Seidel are iterative. They converge for diagonally dominant matrices. Gauss-Seidel uses each new value immediately and usually converges faster; relaxation λ > 1 (over-relaxation) can speed it up.

The condition number cond(A) = ‖A‖·‖A⁻¹‖ measures sensitivity: roughly log₁₀(cond) digits of accuracy are lost.

The power method finds the eigenvalue of largest magnitude by repeated multiplication.''';
}

class _StepCard extends StatelessWidget {
  final LinStep step;
  const _StepCard({required this.step});

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NLCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(step.text, style: NLText.body(c.ink, size: 13, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            _MatView(step.matrix, augmented: true, pivotRow: step.pivotRow, pivotCol: step.pivotCol),
          ],
        ),
      ),
    );
  }
}

class _MatView extends StatelessWidget {
  final Mat m;
  final bool augmented;
  final int? pivotRow, pivotCol;
  const _MatView(this.m, {this.augmented = false, this.pivotRow, this.pivotCol});

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final cols = m.isEmpty ? 0 : m[0].length;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.symmetric(vertical: BorderSide(color: c.inkDim, width: 1.5)),
        ),
        child: Column(
          children: [
            for (var i = 0; i < m.length; i++)
              Row(
                children: [
                  for (var j = 0; j < cols; j++) ...[
                    if (augmented && j == cols - 1) Container(width: 1, height: 18, color: c.line, margin: const EdgeInsets.symmetric(horizontal: 4)),
                    Container(
                      width: 78,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: i == pivotRow && j == pivotCol ? c.accent.withOpacity(0.2) : null,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        fmt(m[i][j].abs() < 1e-13 ? 0 : m[i][j], sig: 5),
                        textAlign: TextAlign.right,
                        style: NLText.reading(12, augmented && j == cols - 1 ? c.accent : c.ink),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}
