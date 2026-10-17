import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/expr.dart';
import '../core/fitting.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/inputs.dart';
import '../widgets/module_scaffold.dart';
import '../widgets/plot.dart';

enum FitKind { regression, lagrange, newton, spline }

class FittingScreen extends StatefulWidget {
  const FittingScreen({super.key});

  @override
  State<FittingScreen> createState() => _FittingScreenState();
}

class _FittingScreenState extends State<FittingScreen> {
  final _data = TextEditingController();
  final _at = TextEditingController(text: '');
  FitKind _kind = FitKind.regression;
  FitModel _model = FitModel.linear;
  int _degree = 2;

  static const _examples = <String, String>{
    'Calibration (AAS)': '0 0.002\n0.5 0.051\n1 0.098\n2 0.205\n4 0.398\n6 0.601',
    'Chapra 14.1': '1 0.5\n2 2.5\n3 2\n4 4\n5 3.5\n6 6\n7 5.5',
    'Exponential decay': '0 100\n1 61\n2 37.5\n3 22.1\n4 13.8\n5 8.1',
    'Power law': '1 0.5\n2 1.7\n3 3.4\n4 5.7\n5 8.4',
    'Spline knots': '3 2.5\n4.5 1\n7 2.5\n9 0.5',
  };

  @override
  void initState() {
    super.initState();
    _data.text = _examples.values.first;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final p = parseXY(_data.text);
    final x = p.x, y = p.y;
    final at = evalNumber(_at.text);

    String? error;
    FitResult? fit;
    double Function(double)? curve;
    String? equation;
    List<List<double>>? ddTable;
    List<double>? sx, sy;

    try {
      if (x.length < 2) throw FitError('Enter at least 2 data points (x y per line).');
      switch (_kind) {
        case FitKind.regression:
          fit = Fitting.fit(_model, x, y, degree: _degree);
          curve = fit.predict;
          equation = fit.equation;
          break;
        case FitKind.lagrange:
          if (x.toSet().length != x.length) throw FitError('x values must be distinct for interpolation.');
          curve = (v) => Fitting.lagrange(x, y, v);
          equation = 'Lagrange polynomial of degree ${x.length - 1} through ${x.length} points';
          break;
        case FitKind.newton:
          if (x.toSet().length != x.length) throw FitError('x values must be distinct for interpolation.');
          ddTable = Fitting.dividedDifferences(x, y);
          final t = ddTable;
          curve = (v) => Fitting.newtonEval(x, t, v);
          final b = StringBuffer('f(x) = ${fmt(t[0][0], sig: 6)}');
          for (var j = 1; j < x.length && j < 5; j++) {
            final coef = t[j][0];
            b.write(' ${coef < 0 ? '−' : '+'} ${fmt(coef.abs(), sig: 6)}');
            for (var k = 0; k < j; k++) {
              b.write('(x ${x[k] < 0 ? '+' : '−'} ${fmt(x[k].abs(), sig: 5)})');
            }
          }
          if (x.length > 5) b.write(' + …');
          equation = b.toString();
          break;
        case FitKind.spline:
          final idx = List.generate(x.length, (i) => i)..sort((a, b) => x[a].compareTo(x[b]));
          final xs = [for (final i in idx) x[i]], ys = [for (final i in idx) y[i]];
          sx = xs;
          sy = ys;
          final m2 = Fitting.splineSecondDerivs(xs, ys);
          curve = (v) => Fitting.splineEval(xs, ys, m2, v);
          equation = 'Natural cubic spline: ${xs.length - 1} cubic pieces, f″ = 0 at both ends';
          break;
      }
    } on FitError catch (e) {
      error = e.message;
    } on Object catch (e) {
      error = e.toString();
    }

    final lo = x.isEmpty ? 0.0 : x.reduce(math.min), hi = x.isEmpty ? 1.0 : x.reduce(math.max);
    final pad = (hi - lo) == 0 ? 1.0 : (hi - lo) * 0.12;

    return ModuleScaffold(
      title: 'Curve fitting',
      theory: _theory,
      children: [
        Presets(
          labels: _examples.keys.toList(),
          onPick: (i) => setState(() {
            _data.text = _examples.values.elementAt(i);
            final key = _examples.keys.elementAt(i);
            if (key.startsWith('Exponential')) {
              _kind = FitKind.regression;
              _model = FitModel.exponential;
            } else if (key.startsWith('Power')) {
              _kind = FitKind.regression;
              _model = FitModel.power;
            } else if (key.startsWith('Spline')) {
              _kind = FitKind.spline;
            } else {
              _kind = FitKind.regression;
              _model = FitModel.linear;
            }
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _data,
          onChanged: (_) => setState(() {}),
          minLines: 5,
          maxLines: 10,
          style: NLText.reading(14, c.ink),
          decoration: InputDecoration(
            labelText: 'Data: one "x  y" pair per line',
            helperText: '${x.length} points${p.bad > 0 ? ' · ${p.bad} lines skipped' : ''} · paste from Excel works',
          ),
        ),
        const SizedBox(height: 14),
        Segmented<FitKind>(
          values: FitKind.values,
          selected: _kind,
          label: (k) => const {
            FitKind.regression: 'Regression',
            FitKind.lagrange: 'Lagrange',
            FitKind.newton: 'Newton divided diff.',
            FitKind.spline: 'Cubic spline',
          }[k]!,
          onChanged: (k) => setState(() => _kind = k),
        ),
        if (_kind == FitKind.regression) ...[
          const SizedBox(height: 10),
          Segmented<FitModel>(
            values: FitModel.values,
            selected: _model,
            label: (m) => m.label,
            onChanged: (m) => setState(() => _model = m),
          ),
          const SizedBox(height: 10),
          FormulaBox(_model.form, note: fit?.note),
          if (_model == FitModel.polynomial) ...[
            const SizedBox(height: 10),
            Stepper2(label: 'Degree m', value: _degree, min: 2, max: 6, onChanged: (v) => setState(() => _degree = v)),
          ],
        ],
        const SizedBox(height: 16),
        if (error != null)
          ResultCard(label: 'Cannot fit', value: 'Check data', sub: error, ok: false)
        else if (equation != null)
          ResultCard(
            label: _kind == FitKind.regression ? 'Best fit' : 'Interpolant',
            value: equation,
            sub: fit == null
                ? null
                : 'r² = ${fmt(fit.r2, sig: 6)}   r = ${fmt(fit.r, sig: 6)}\n'
                    'Standard error sy/x = ${fmt(fit.syx, sig: 5)}   n = ${fit.n}',
          ),
        if (curve != null)
          Section(
            'Graph',
            child: Column(
              children: [
                PlotView(
                  xMin: lo - pad,
                  xMax: hi + pad,
                  series: [
                    FnSeries(curve, c.accent, label: _kind == FitKind.regression ? 'fit' : 'interpolant'),
                    PointSeries([for (var i = 0; i < x.length; i++) Offset(x[i], y[i])], seriesColors[1],
                        line: false, dots: true, label: 'data'),
                    if (at != null && curve(at).isFinite) MarkerSeries([Offset(at, curve(at))], seriesColors[3]),
                  ],
                ),
                PlotLegend([
                  FnSeries(curve, c.accent, label: _kind == FitKind.regression ? 'fit' : 'interpolant'),
                  PointSeries(const [], seriesColors[1], label: 'data'),
                ]),
              ],
            ),
          ),
        if (curve != null)
          Section(
            'Evaluate',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NumField(controller: _at, label: 'x value', onChanged: (_) => setState(() {})),
                const SizedBox(height: 10),
                if (at != null)
                  Text('f(${fmt(at)}) = ${fmt(curve(at), sig: 10)}', style: NLText.reading(17, c.ink, weight: FontWeight.w700)),
                if (at != null && fit != null && _model == FitModel.linear && fit.coeffs[1] != 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Inverse (calibration): if y = ${fmt(at)}, then x = ${fmt((at - fit.coeffs[0]) / fit.coeffs[1], sig: 8)}',
                    style: NLText.reading(13, c.inkDim),
                  ),
                ],
              ],
            ),
          ),
        if (fit != null)
          Section(
            'Residuals',
            child: ResultTable(
              columns: const ['x', 'y', 'ŷ', 'y − ŷ'],
              rows: [
                for (var i = 0; i < x.length; i++)
                  [fmt(x[i], sig: 6), fmt(y[i], sig: 6), fmt(fit.predict(x[i]), sig: 6), fmt(y[i] - fit.predict(x[i]), sig: 4)]
              ],
            ),
          ),
        if (fit != null && _model == FitModel.linear && x.length >= 3) _calibrationExtras(context, fit, x),
        if (ddTable != null)
          Section(
            'Divided-difference table',
            child: ResultTable(
              columns: ['i', 'xᵢ', 'f[xᵢ]', for (var j = 1; j < x.length; j++) '${_ord(j)} diff'],
              rows: [
                for (var i = 0; i < x.length; i++)
                  [
                    '$i',
                    fmt(x[i], sig: 6),
                    for (var j = 0; j < x.length; j++) i < ddTable[j].length ? fmt(ddTable[j][i], sig: 6) : '',
                  ]
              ],
            ),
          ),
        if (sx != null && sy != null && curve != null)
          Section(
            'Spline values at knots and midpoints',
            child: ResultTable(
              columns: const ['x', 'S(x)'],
              rows: [
                for (var i = 0; i < sx.length; i++) ...[
                  [fmt(sx[i], sig: 6), fmt(curve(sx[i]), sig: 8)],
                  if (i < sx.length - 1) [fmt((sx[i] + sx[i + 1]) / 2, sig: 6), fmt(curve((sx[i] + sx[i + 1]) / 2), sig: 8)],
                ]
              ],
            ),
          ),
      ],
    );
  }

  Widget _calibrationExtras(BuildContext context, FitResult fit, List<double> x) {
    final c = context.nl;
    final slope = fit.coeffs[1];
    final lod = 3.3 * fit.syx / slope.abs();
    final loq = 10 * fit.syx / slope.abs();
    return Section(
      'Calibration figures',
      child: NLCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Slope (sensitivity) = ${fmt(slope, sig: 6)}', style: NLText.reading(13.5, c.ink)),
            Text('Intercept = ${fmt(fit.coeffs[0], sig: 6)}', style: NLText.reading(13.5, c.ink)),
            Text('LOD ≈ 3.3·sy/x / slope = ${fmt(lod, sig: 4)}', style: NLText.reading(13.5, c.ink)),
            Text('LOQ ≈ 10·sy/x / slope = ${fmt(loq, sig: 4)}', style: NLText.reading(13.5, c.ink)),
            const SizedBox(height: 6),
            Text('Using the standard error of the regression (ICH approach).', style: NLText.body(c.inkDim, size: 12)),
          ],
        ),
      ),
    );
  }

  static String _ord(int j) => j == 1 ? '1st' : j == 2 ? '2nd' : j == 3 ? '3rd' : '${j}th';

  static const _theory = '''Regression finds the curve that best fits noisy data by minimising the sum of squared residuals. It does not pass through every point.

• Linear and polynomial: solved with the normal equations.
• Exponential, power and saturation-growth: linearised (ln y, log–log, 1/y vs 1/x) and fitted as straight lines, as in the textbook.

r² = 1 − SSr/SSt tells you the fraction of variation explained. sy/x = √(SSr/(n − p)) is the standard error of the estimate.

Interpolation passes exactly through every point:
• Lagrange and Newton divided differences give the same polynomial of degree n − 1. High degrees can oscillate between points.
• A natural cubic spline joins cubics with continuous first and second derivatives, and avoids that oscillation.''';
}
