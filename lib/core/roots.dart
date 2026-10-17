// Roots of equations, with full iteration history for teaching.
// Relative approximate error follows Chapra: ea = |(x_new - x_old)/x_new| × 100%.

import 'dart:math' as math;

typedef F1 = double Function(double x);

enum RootMethod { bisection, falsePosition, newton, secant, fixedPoint }

extension RootMethodX on RootMethod {
  String get label {
    switch (this) {
      case RootMethod.bisection:
        return 'Bisection';
      case RootMethod.falsePosition:
        return 'False position';
      case RootMethod.newton:
        return 'Newton-Raphson';
      case RootMethod.secant:
        return 'Secant';
      case RootMethod.fixedPoint:
        return 'Fixed-point';
    }
  }

  bool get bracketing => this == RootMethod.bisection || this == RootMethod.falsePosition;

  String get formula {
    switch (this) {
      case RootMethod.bisection:
        return 'xr = (xl + xu) / 2';
      case RootMethod.falsePosition:
        return 'xr = xu − f(xu)(xl − xu) / (f(xl) − f(xu))';
      case RootMethod.newton:
        return 'x(i+1) = x(i) − f(x(i)) / f′(x(i))';
      case RootMethod.secant:
        return 'x(i+1) = x(i) − f(x(i))(x(i−1) − x(i)) / (f(x(i−1)) − f(x(i)))';
      case RootMethod.fixedPoint:
        return 'x(i+1) = g(x(i))';
    }
  }
}

class IterRow {
  final int i;
  final List<double> values;
  final double? ea; // percent
  const IterRow(this.i, this.values, this.ea);
}

class RootResult {
  final RootMethod method;
  final double root;
  final double fRoot;
  final bool converged;
  final String message;
  final List<String> columns;
  final List<IterRow> rows;
  const RootResult({
    required this.method,
    required this.root,
    required this.fRoot,
    required this.converged,
    required this.message,
    required this.columns,
    required this.rows,
  });

  int get iterations => rows.length;
  List<double> get iterates => [for (final r in rows) r.values[_xIndex]];
  int get _xIndex {
    switch (method) {
      case RootMethod.bisection:
      case RootMethod.falsePosition:
        return 3;
      default:
        return 1;
    }
  }
}

double _ea(double xNew, double xOld) =>
    xNew == 0 ? (xNew - xOld).abs() * 100 : ((xNew - xOld) / xNew).abs() * 100;

/// Central-difference derivative with a scale-aware step.
double numericDerivative(F1 f, double x) {
  final h = 1e-6 * math.max(1.0, x.abs());
  return (f(x + h) - f(x - h)) / (2 * h);
}

class Roots {
  Roots._();

  static RootResult bracketing(
    F1 f,
    double xl,
    double xu, {
    required bool falsePosition,
    double tolPercent = 1e-6,
    int maxIter = 100,
  }) {
    final method = falsePosition ? RootMethod.falsePosition : RootMethod.bisection;
    const cols = ['i', 'xl', 'xu', 'xr', 'f(xr)', 'εa %'];
    var fl = f(xl), fu = f(xu);
    if (fl.isNaN || fu.isNaN) {
      return RootResult(method: method, root: double.nan, fRoot: double.nan, converged: false,
          message: 'f is not defined at a bound.', columns: cols, rows: const []);
    }
    if (fl == 0) {
      return RootResult(method: method, root: xl, fRoot: 0, converged: true,
          message: 'Lower bound is a root.', columns: cols, rows: const []);
    }
    if (fu == 0) {
      return RootResult(method: method, root: xu, fRoot: 0, converged: true,
          message: 'Upper bound is a root.', columns: cols, rows: const []);
    }
    if (fl * fu > 0) {
      return RootResult(method: method, root: double.nan, fRoot: double.nan, converged: false,
          message: 'f(xl) and f(xu) have the same sign, so no root is bracketed. Try another interval.',
          columns: cols, rows: const []);
    }
    final rows = <IterRow>[];
    double xr = xl, xrOld;
    int stuckL = 0, stuckU = 0;
    for (var i = 1; i <= maxIter; i++) {
      xrOld = xr;
      if (falsePosition) {
        xr = xu - fu * (xl - xu) / (fl - fu);
      } else {
        xr = (xl + xu) / 2;
      }
      final fr = f(xr);
      final ea = i == 1 ? null : _ea(xr, xrOld);
      rows.add(IterRow(i, [i.toDouble(), xl, xu, xr, fr, ea ?? double.nan], ea));
      if (fr == 0 || (ea != null && ea < tolPercent)) {
        return RootResult(method: method, root: xr, fRoot: fr, converged: true,
            message: 'Converged in $i iterations.', columns: cols, rows: rows);
      }
      if (fl * fr < 0) {
        xu = xr;
        fu = fr;
        stuckU = 0;
        stuckL++;
        // Modified false position: halve the stuck end's function value.
        if (falsePosition && stuckL >= 2) fl /= 2;
      } else {
        xl = xr;
        fl = fr;
        stuckL = 0;
        stuckU++;
        if (falsePosition && stuckU >= 2) fu /= 2;
      }
    }
    return RootResult(method: method, root: xr, fRoot: f(xr), converged: false,
        message: 'Stopped after $maxIter iterations without meeting the tolerance.', columns: cols, rows: rows);
  }

  static RootResult newton(
    F1 f,
    double x0, {
    F1? df,
    double tolPercent = 1e-6,
    int maxIter = 50,
  }) {
    const cols = ['i', 'x(i)', 'f(x)', 'f′(x)', 'εa %'];
    final rows = <IterRow>[];
    var x = x0;
    for (var i = 1; i <= maxIter; i++) {
      final fx = f(x);
      final d = df != null ? df(x) : numericDerivative(f, x);
      if (fx.isNaN || d.isNaN) {
        return RootResult(method: RootMethod.newton, root: x, fRoot: fx, converged: false,
            message: 'f or f′ is not defined at x = $x.', columns: cols, rows: rows);
      }
      if (d == 0) {
        rows.add(IterRow(i, [i.toDouble(), x, fx, d, double.nan], null));
        return RootResult(method: RootMethod.newton, root: x, fRoot: fx, converged: fx == 0,
            message: 'Derivative is zero; Newton cannot continue. Choose another starting point.',
            columns: cols, rows: rows);
      }
      final xNew = x - fx / d;
      final ea = _ea(xNew, x);
      rows.add(IterRow(i, [i.toDouble(), xNew, f(xNew), d, ea], ea));
      x = xNew;
      if (!x.isFinite) break;
      if (ea < tolPercent || f(x) == 0) {
        return RootResult(method: RootMethod.newton, root: x, fRoot: f(x), converged: true,
            message: 'Converged in $i iterations.', columns: cols, rows: rows);
      }
    }
    return RootResult(method: RootMethod.newton, root: x, fRoot: f(x), converged: false,
        message: x.isFinite ? 'Did not converge in $maxIter iterations.' : 'Iterates diverged.',
        columns: cols, rows: rows);
  }

  static RootResult secant(
    F1 f,
    double x0,
    double x1, {
    double tolPercent = 1e-6,
    int maxIter = 50,
  }) {
    const cols = ['i', 'x(i)', 'f(x)', 'εa %'];
    final rows = <IterRow>[];
    var a = x0, b = x1;
    var fa = f(a), fb = f(b);
    for (var i = 1; i <= maxIter; i++) {
      if (fb == fa) {
        return RootResult(method: RootMethod.secant, root: b, fRoot: fb, converged: fb == 0,
            message: 'f(x(i−1)) = f(x(i)); secant line is flat.', columns: cols, rows: rows);
      }
      final c = b - fb * (a - b) / (fa - fb);
      final fc = f(c);
      final ea = _ea(c, b);
      rows.add(IterRow(i, [i.toDouble(), c, fc, ea], ea));
      a = b;
      fa = fb;
      b = c;
      fb = fc;
      if (!b.isFinite) break;
      if (ea < tolPercent || fb == 0) {
        return RootResult(method: RootMethod.secant, root: b, fRoot: fb, converged: true,
            message: 'Converged in $i iterations.', columns: cols, rows: rows);
      }
    }
    return RootResult(method: RootMethod.secant, root: b, fRoot: fb, converged: false,
        message: b.isFinite ? 'Did not converge in $maxIter iterations.' : 'Iterates diverged.',
        columns: cols, rows: rows);
  }

  /// Fixed-point iteration x = g(x). [f] is used only to report f(root).
  static RootResult fixedPoint(
    F1 g,
    double x0, {
    F1? f,
    double tolPercent = 1e-6,
    int maxIter = 100,
  }) {
    const cols = ['i', 'x(i)', 'g(x)', 'εa %'];
    final rows = <IterRow>[];
    var x = x0;
    for (var i = 1; i <= maxIter; i++) {
      final xNew = g(x);
      final ea = _ea(xNew, x);
      rows.add(IterRow(i, [i.toDouble(), xNew, g(xNew), ea], ea));
      x = xNew;
      if (!x.isFinite) break;
      if (ea < tolPercent) {
        return RootResult(method: RootMethod.fixedPoint, root: x, fRoot: f?.call(x) ?? x - g(x),
            converged: true, message: 'Converged in $i iterations.', columns: cols, rows: rows);
      }
    }
    return RootResult(method: RootMethod.fixedPoint, root: x, fRoot: f?.call(x) ?? double.nan,
        converged: false,
        message: x.isFinite
            ? 'Did not converge in $maxIter iterations. Fixed-point needs |g′(x)| < 1 near the root.'
            : 'Iterates diverged. Fixed-point needs |g′(x)| < 1 near the root.',
        columns: cols, rows: rows);
  }

  /// Finds all sign-change roots of f on [a, b] by scanning then bisecting.
  static List<double> scan(F1 f, double a, double b, {int samples = 400}) {
    final out = <double>[];
    final h = (b - a) / samples;
    var x0 = a;
    var f0 = f(x0);
    for (var k = 1; k <= samples; k++) {
      final x1 = a + k * h;
      final f1 = f(x1);
      if (f0.isFinite && f1.isFinite) {
        if (f0 == 0) {
          out.add(x0);
        } else if (f0 * f1 < 0) {
          // Skip poles: a true root has a small |f| after refining.
          var lo = x0, hi = x1, flo = f0;
          for (var j = 0; j < 60; j++) {
            final m = (lo + hi) / 2;
            final fm = f(m);
            if (flo * fm <= 0) {
              hi = m;
            } else {
              lo = m;
              flo = fm;
            }
          }
          final r = (lo + hi) / 2;
          final fr = f(r);
          if (fr.isFinite && fr.abs() < 1e-6 * (1 + f0.abs() + f1.abs())) out.add(r);
        }
      }
      x0 = x1;
      f0 = f1;
    }
    return out;
  }

  /// Golden-section search for a minimum (or maximum) on [a, b].
  static GoldenResult golden(F1 f, double a, double b,
      {bool maximize = false, double tolPercent = 1e-5, int maxIter = 200}) {
    final g = maximize ? (double x) => -f(x) : f;
    const r = 0.6180339887498949;
    var xl = a, xu = b;
    var d = r * (xu - xl);
    var x1 = xl + d, x2 = xu - d;
    var f1 = g(x1), f2 = g(x2);
    final rows = <IterRow>[];
    double xopt = f1 < f2 ? x1 : x2;
    for (var i = 1; i <= maxIter; i++) {
      d = r * d;
      if (f1 < f2) {
        xl = x2;
        x2 = x1;
        f2 = f1;
        x1 = xl + d;
        f1 = g(x1);
      } else {
        xu = x1;
        x1 = x2;
        f1 = f2;
        x2 = xu - d;
        f2 = g(x2);
      }
      xopt = f1 < f2 ? x1 : x2;
      final ea = xopt != 0 ? (1 - r) * ((xu - xl) / xopt).abs() * 100 : double.nan;
      rows.add(IterRow(i, [i.toDouble(), xl, xu, xopt, f(xopt), ea], ea));
      if (ea.isFinite && ea < tolPercent) break;
    }
    return GoldenResult(xopt, f(xopt), rows);
  }
}

class GoldenResult {
  final double x;
  final double fx;
  final List<IterRow> rows;
  const GoldenResult(this.x, this.fx, this.rows);
  static const columns = ['i', 'xl', 'xu', 'xopt', 'f(xopt)', 'εa %'];
}
