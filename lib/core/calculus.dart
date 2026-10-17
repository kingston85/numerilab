// Numerical integration, differentiation and ODE solvers.

import 'dart:math' as math;

import 'roots.dart' show F1;

class Integration {
  Integration._();

  /// Composite trapezoidal rule with n segments.
  static double trapezoid(F1 f, double a, double b, int n) {
    final h = (b - a) / n;
    var s = (f(a) + f(b)) / 2;
    for (var i = 1; i < n; i++) {
      s += f(a + i * h);
    }
    return s * h;
  }

  /// Composite Simpson's 1/3 rule; n must be even.
  static double simpson13(F1 f, double a, double b, int n) {
    if (n.isOdd) n += 1;
    final h = (b - a) / n;
    var s = f(a) + f(b);
    for (var i = 1; i < n; i++) {
      s += f(a + i * h) * (i.isOdd ? 4 : 2);
    }
    return s * h / 3;
  }

  /// Composite Simpson's 3/8 rule; n must be a multiple of 3.
  static double simpson38(F1 f, double a, double b, int n) {
    final r = n % 3;
    if (r != 0) n += 3 - r;
    final h = (b - a) / n;
    var s = f(a) + f(b);
    for (var i = 1; i < n; i++) {
      s += f(a + i * h) * (i % 3 == 0 ? 2 : 3);
    }
    return s * 3 * h / 8;
  }

  /// Romberg integration. Returns the tableau R[k][j] (k rows, j ≤ k).
  static List<List<double>> romberg(F1 f, double a, double b, {int levels = 6}) {
    final r = <List<double>>[];
    for (var k = 0; k < levels; k++) {
      final row = <double>[trapezoid(f, a, b, 1 << k)];
      for (var j = 1; j <= k; j++) {
        final p = math.pow(4, j).toDouble();
        row.add((p * row[j - 1] - r[k - 1][j - 1]) / (p - 1));
      }
      r.add(row);
    }
    return r;
  }

  static const Map<int, List<List<double>>> _gl = {
    2: [
      [-0.5773502691896257, 1.0],
      [0.5773502691896257, 1.0],
    ],
    3: [
      [-0.7745966692414834, 0.5555555555555556],
      [0.0, 0.8888888888888888],
      [0.7745966692414834, 0.5555555555555556],
    ],
    4: [
      [-0.8611363115940526, 0.3478548451374538],
      [-0.3399810435848563, 0.6521451548625461],
      [0.3399810435848563, 0.6521451548625461],
      [0.8611363115940526, 0.3478548451374538],
    ],
    5: [
      [-0.9061798459386640, 0.2369268850561891],
      [-0.5384693101056831, 0.4786286704993665],
      [0.0, 0.5688888888888889],
      [0.5384693101056831, 0.4786286704993665],
      [0.9061798459386640, 0.2369268850561891],
    ],
    6: [
      [-0.9324695142031521, 0.1713244923791704],
      [-0.6612093864662645, 0.3607615730481386],
      [-0.2386191860831969, 0.4679139345726910],
      [0.2386191860831969, 0.4679139345726910],
      [0.6612093864662645, 0.3607615730481386],
      [0.9324695142031521, 0.1713244923791704],
    ],
  };

  /// Gauss-Legendre quadrature with 2–6 points.
  static double gaussLegendre(F1 f, double a, double b, int points) {
    final rule = _gl[points.clamp(2, 6)]!;
    final c = (b + a) / 2, m = (b - a) / 2;
    var s = 0.0;
    for (final p in rule) {
      s += p[1] * f(c + m * p[0]);
    }
    return s * m;
  }

  /// Adaptive Simpson quadrature to absolute tolerance [tol].
  static ({double value, int evals}) adaptive(F1 f, double a, double b, {double tol = 1e-10, int maxDepth = 50}) {
    var evals = 0;
    double g(double x) {
      evals++;
      return f(x);
    }

    double rec(double a, double b, double fa, double fm, double fb, double whole, double tol, int depth) {
      final m = (a + b) / 2;
      final lm = (a + m) / 2, rm = (m + b) / 2;
      final flm = g(lm), frm = g(rm);
      final left = (m - a) / 6 * (fa + 4 * flm + fm);
      final right = (b - m) / 6 * (fm + 4 * frm + fb);
      final delta = left + right - whole;
      if (depth <= 0 || delta.abs() <= 15 * tol) return left + right + delta / 15;
      return rec(a, m, fa, flm, fm, left, tol / 2, depth - 1) + rec(m, b, fm, frm, fb, right, tol / 2, depth - 1);
    }

    final fa = g(a), fb = g(b), fm = g((a + b) / 2);
    final whole = (b - a) / 6 * (fa + 4 * fm + fb);
    final v = rec(a, b, fa, fm, fb, whole, tol, maxDepth);
    return (value: v, evals: evals);
  }
}

class DiffRow {
  final String name;
  final String order;
  final double value;
  const DiffRow(this.name, this.order, this.value);
}

class Differentiation {
  Differentiation._();

  static List<DiffRow> table(F1 f, double x, double h) {
    final f0 = f(x), f1 = f(x + h), f2 = f(x + 2 * h), fm1 = f(x - h), fm2 = f(x - 2 * h);
    return [
      DiffRow('Forward', 'O(h)', (f1 - f0) / h),
      DiffRow('Forward', 'O(h²)', (-f2 + 4 * f1 - 3 * f0) / (2 * h)),
      DiffRow('Backward', 'O(h)', (f0 - fm1) / h),
      DiffRow('Backward', 'O(h²)', (3 * f0 - 4 * fm1 + fm2) / (2 * h)),
      DiffRow('Centred', 'O(h²)', (f1 - fm1) / (2 * h)),
      DiffRow('Centred', 'O(h⁴)', (-f2 + 8 * f1 - 8 * fm1 + fm2) / (12 * h)),
      DiffRow('Richardson', 'O(h⁴)', richardson(f, x, h)),
    ];
  }

  /// Richardson extrapolation of centred differences with h and h/2.
  static double richardson(F1 f, double x, double h) {
    double c(double hh) => (f(x + hh) - f(x - hh)) / (2 * hh);
    return (4 * c(h / 2) - c(h)) / 3;
  }

  static double second(F1 f, double x, double h) => (f(x + h) - 2 * f(x) + f(x - h)) / (h * h);

  /// High-accuracy reference value (Richardson on a small step).
  static double reference(F1 f, double x) {
    final h = 1e-3 * math.max(1.0, x.abs());
    final d1 = richardson(f, x, h);
    final d2 = richardson(f, x, h / 2);
    return (16 * d2 - d1) / 15;
  }
}

// ---------------------------------------------------------------------------
// ODEs: y' = F(t, y) for a vector y.
// ---------------------------------------------------------------------------

typedef OdeF = List<double> Function(double t, List<double> y);

enum OdeMethod { euler, heun, midpoint, ralston, rk4, rk45 }

extension OdeMethodX on OdeMethod {
  String get label {
    switch (this) {
      case OdeMethod.euler:
        return 'Euler';
      case OdeMethod.heun:
        return 'Heun';
      case OdeMethod.midpoint:
        return 'Midpoint';
      case OdeMethod.ralston:
        return 'Ralston';
      case OdeMethod.rk4:
        return 'RK4';
      case OdeMethod.rk45:
        return 'RK45 adaptive';
    }
  }

  String get order {
    switch (this) {
      case OdeMethod.euler:
        return '1st order';
      case OdeMethod.heun:
      case OdeMethod.midpoint:
      case OdeMethod.ralston:
        return '2nd order';
      case OdeMethod.rk4:
        return '4th order';
      case OdeMethod.rk45:
        return '4th/5th order, adaptive step';
    }
  }
}

class OdeSolution {
  final OdeMethod method;
  final List<double> t;
  final List<List<double>> y;
  final String? warning;
  const OdeSolution(this.method, this.t, this.y, [this.warning]);

  int get steps => t.length - 1;
}

class Ode {
  Ode._();

  static List<double> _add(List<double> a, List<double> b, double s) => [for (var i = 0; i < a.length; i++) a[i] + s * b[i]];

  static List<double> _step(OdeMethod m, OdeF f, double t, List<double> y, double h) {
    switch (m) {
      case OdeMethod.euler:
        return _add(y, f(t, y), h);
      case OdeMethod.heun:
        final k1 = f(t, y);
        final k2 = f(t + h, _add(y, k1, h));
        return [for (var i = 0; i < y.length; i++) y[i] + h * (k1[i] + k2[i]) / 2];
      case OdeMethod.midpoint:
        final k1 = f(t, y);
        final k2 = f(t + h / 2, _add(y, k1, h / 2));
        return _add(y, k2, h);
      case OdeMethod.ralston:
        final k1 = f(t, y);
        final k2 = f(t + 0.75 * h, _add(y, k1, 0.75 * h));
        return [for (var i = 0; i < y.length; i++) y[i] + h * (k1[i] / 3 + 2 * k2[i] / 3)];
      case OdeMethod.rk4:
      case OdeMethod.rk45:
        final k1 = f(t, y);
        final k2 = f(t + h / 2, _add(y, k1, h / 2));
        final k3 = f(t + h / 2, _add(y, k2, h / 2));
        final k4 = f(t + h, _add(y, k3, h));
        return [for (var i = 0; i < y.length; i++) y[i] + h * (k1[i] + 2 * k2[i] + 2 * k3[i] + k4[i]) / 6];
    }
  }

  static OdeSolution solve(OdeMethod m, OdeF f, double t0, List<double> y0, double tEnd, double h,
      {double tol = 1e-6, int maxSteps = 200000}) {
    if (m == OdeMethod.rk45) return _rk45(f, t0, y0, tEnd, h, tol: tol, maxSteps: maxSteps);
    final n = ((tEnd - t0) / h).abs().ceil();
    if (n > maxSteps) {
      return OdeSolution(m, [t0], [y0], 'Too many steps (${n.toString()}). Use a larger step size.');
    }
    final hh = (tEnd - t0) / n;
    final ts = <double>[t0];
    final ys = <List<double>>[List<double>.from(y0)];
    var y = List<double>.from(y0);
    String? warning;
    for (var i = 1; i <= n; i++) {
      y = _step(m, f, t0 + (i - 1) * hh, y, hh);
      if (!y.every((v) => v.isFinite)) {
        warning = 'The solution became unbounded near t = ${(t0 + i * hh).toStringAsPrecision(4)}. '
            'Try a smaller step (the method may be unstable for this step size).';
        break;
      }
      ts.add(t0 + i * hh);
      ys.add(y);
    }
    return OdeSolution(m, ts, ys, warning);
  }

  /// Adaptive Runge-Kutta-Fehlberg 4(5) with step-size control.
  static OdeSolution _rk45(OdeF f, double t0, List<double> y0, double tEnd, double h0,
      {double tol = 1e-6, int maxSteps = 200000}) {
    final dir = tEnd >= t0 ? 1.0 : -1.0;
    var h = h0.abs() * dir;
    var t = t0;
    var y = List<double>.from(y0);
    final ts = <double>[t];
    final ys = <List<double>>[List<double>.from(y)];
    String? warning;
    var steps = 0;
    while ((tEnd - t) * dir > 1e-14 && steps < maxSteps) {
      if ((t + h - tEnd) * dir > 0) h = tEnd - t;
      final k1 = f(t, y);
      final k2 = f(t + h / 4, [for (var i = 0; i < y.length; i++) y[i] + h * k1[i] / 4]);
      final k3 = f(t + 3 * h / 8, [for (var i = 0; i < y.length; i++) y[i] + h * (3 * k1[i] + 9 * k2[i]) / 32]);
      final k4 = f(t + 12 * h / 13, [
        for (var i = 0; i < y.length; i++) y[i] + h * (1932 * k1[i] - 7200 * k2[i] + 7296 * k3[i]) / 2197
      ]);
      final k5 = f(t + h, [
        for (var i = 0; i < y.length; i++)
          y[i] + h * (439 / 216 * k1[i] - 8 * k2[i] + 3680 / 513 * k3[i] - 845 / 4104 * k4[i])
      ]);
      final k6 = f(t + h / 2, [
        for (var i = 0; i < y.length; i++)
          y[i] + h * (-8 / 27 * k1[i] + 2 * k2[i] - 3544 / 2565 * k3[i] + 1859 / 4104 * k4[i] - 11 / 40 * k5[i])
      ]);
      final y4 = [
        for (var i = 0; i < y.length; i++)
          y[i] + h * (25 / 216 * k1[i] + 1408 / 2565 * k3[i] + 2197 / 4104 * k4[i] - k5[i] / 5)
      ];
      final y5 = [
        for (var i = 0; i < y.length; i++)
          y[i] + h * (16 / 135 * k1[i] + 6656 / 12825 * k3[i] + 28561 / 56430 * k4[i] - 9 / 50 * k5[i] + 2 / 55 * k6[i])
      ];
      var err = 0.0;
      for (var i = 0; i < y.length; i++) {
        final scale = tol * (1 + y[i].abs());
        err = math.max(err, (y5[i] - y4[i]).abs() / scale);
      }
      if (!err.isFinite) {
        warning = 'The solution became unbounded near t = ${t.toStringAsPrecision(4)}.';
        break;
      }
      if (err <= 1) {
        t += h;
        y = y5;
        ts.add(t);
        ys.add(y);
      }
      final factor = err == 0 ? 4.0 : (0.9 * math.pow(1 / err, 0.2)).clamp(0.2, 4.0).toDouble();
      h *= factor;
      if (h.abs() < 1e-14) {
        warning = 'Step size became too small near t = ${t.toStringAsPrecision(4)} (possible singularity).';
        break;
      }
      steps++;
    }
    return OdeSolution(OdeMethod.rk45, ts, ys, warning);
  }
}
