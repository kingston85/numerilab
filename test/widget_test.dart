// NumeriLab maths tests: each method is checked against known textbook
// values (Chapra & Canale, Numerical Methods for Engineers) or exact answers.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:numerilab/core/calculus.dart';
import 'package:numerilab/core/expr.dart';
import 'package:numerilab/core/fitting.dart';
import 'package:numerilab/core/linalg.dart';
import 'package:numerilab/core/roots.dart';

void main() {
  group('Expression parser', () {
    double ev(String s, [double x = 0]) => Expr.parse(s).at(x);
    test('precedence and powers', () {
      expect(ev('2 + 3 * 4'), 14);
      expect(ev('2^3^2'), 512); // right-associative
      expect(ev('-2^2'), -4);
      expect(ev('2^-1'), 0.5);
      expect(ev('(1 + 2) * 3'), 9);
    });
    test('implicit multiplication and functions', () {
      expect(ev('2x', 3), 6);
      expect(ev('3(x + 1)', 1), 6);
      expect(ev('(x + 1)(x - 1)', 3), 8);
      expect(ev('2 sin(x)', math.pi / 2), closeTo(2, 1e-12));
      expect(ev('x exp(-x)', 1), closeTo(math.exp(-1), 1e-12));
      expect(ev('sqrt(16) + ln(e) + log(100)'), closeTo(7, 1e-12));
      expect(ev('1.5e-3 * 2'), closeTo(0.003, 1e-15));
      expect(ev('(-8)^(1/3)'), closeTo(-2, 1e-12));
      expect(ev('max(2, 5) + atan2(1, 1)'), closeTo(5 + math.pi / 4, 1e-12));
    });
    test('multi-variable', () {
      final e = Expr.parse('1.2y - 0.6y z', vars: {'t', 'y', 'z'});
      expect(e.eval({'y': 2, 'z': 1, 't': 0}), closeTo(1.2, 1e-12));
    });
    test('errors', () {
      expect(() => Expr.parse('2 +'), throwsA(isA<ExprError>()));
      expect(() => Expr.parse('foo(2)'), throwsA(isA<ExprError>()));
      expect(() => Expr.parse('(1 + 2'), throwsA(isA<ExprError>()));
      expect(evalNumber('pi/2'), closeTo(math.pi / 2, 1e-15));
      expect(evalNumber('x'), isNull);
    });
    test('formatting', () {
      expect(fmt(1.5), '1.5');
      expect(fmt(0.000001234), '1.234×10⁻⁶');
      expect(fmt(2.0), '2');
    });
  });

  group('Roots', () {
    double f(double x) => x * x * x - x - 2;
    const root = 1.5213797068045676;
    test('bisection and false position', () {
      final b = Roots.bracketing(f, 1, 2, falsePosition: false, tolPercent: 1e-8, maxIter: 200);
      expect(b.converged, isTrue);
      expect(b.root, closeTo(root, 1e-8));
      final fp = Roots.bracketing(f, 1, 2, falsePosition: true, tolPercent: 1e-8, maxIter: 200);
      expect(fp.converged, isTrue);
      expect(fp.root, closeTo(root, 1e-8));
      expect(fp.iterations, lessThan(b.iterations));
    });
    test('bracket without sign change is rejected', () {
      expect(Roots.bracketing(f, 2, 3, falsePosition: false).converged, isFalse);
    });
    test('Newton, secant, fixed point', () {
      final n = Roots.newton(f, 1.5, tolPercent: 1e-10);
      expect(n.root, closeTo(root, 1e-10));
      expect(n.iterations, lessThan(8));
      final s = Roots.secant(f, 1, 2, tolPercent: 1e-10);
      expect(s.root, closeTo(root, 1e-10));
      final g = Roots.fixedPoint((x) => math.pow(x + 2, 1 / 3).toDouble(), 1.5, f: f, tolPercent: 1e-10);
      expect(g.root, closeTo(root, 1e-9));
    });
    test('Chapra 6.1: e^-x - x', () {
      final r = Roots.newton((x) => math.exp(-x) - x, 0, tolPercent: 1e-8);
      expect(r.root, closeTo(0.56714329, 1e-8));
    });
    test('scan finds all roots of sin on [-7, 7]', () {
      final r = Roots.scan(math.sin, -7, 7);
      expect(r.length, 5);
      expect(r[2], closeTo(0, 1e-9));
    });
    test('golden section (Chapra 13.1)', () {
      final g = Roots.golden((x) => 2 * math.sin(x) - x * x / 10, 0, 4, maximize: true);
      expect(g.x, closeTo(1.4276, 1e-3));
      expect(g.fx, closeTo(1.7757, 1e-4));
    });
  });

  group('Linear algebra', () {
    // Chapra example 9.5: solution 3, -2.5, 7
    final a = <List<double>>[
      [3, -0.1, -0.2],
      [0.1, 7, -0.3],
      [0.3, -0.2, 10],
    ];
    final b = <double>[7.85, -19.3, 71.4];
    test('Gauss elimination', () {
      final r = LinAlg.gauss(a, b);
      expect(r.x[0], closeTo(3, 1e-10));
      expect(r.x[1], closeTo(-2.5, 1e-10));
      expect(r.x[2], closeTo(7, 1e-10));
      expect(r.steps, isNotEmpty);
    });
    test('pivoting handles a zero first pivot', () {
      final r = LinAlg.gauss([
        [0, 2, 3],
        [4, 6, 7],
        [2, 1, 6],
      ], [8, -3, 5]);
      final res = LinAlg.residual([
        [0, 2, 3],
        [4, 6, 7],
        [2, 1, 6],
      ], r.x, [8, -3, 5]);
      expect(normInf(res), lessThan(1e-10));
    });
    test('LU, determinant, inverse', () {
      final lu = LinAlg.lu(a, b);
      expect(lu.x![2], closeTo(7, 1e-10));
      final pa = [for (final i in lu.perm) a[i]];
      final prod = matMul(lu.l, lu.u);
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          expect(prod[i][j], closeTo(pa[i][j], 1e-12));
        }
      }
      expect(LinAlg.det([
        [2, 1],
        [1, 3],
      ]), closeTo(5, 1e-12));
      final inv = LinAlg.inverse(a);
      final id = matMul(a, inv);
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          expect(id[i][j], closeTo(i == j ? 1 : 0, 1e-12));
        }
      }
    });
    test('Jacobi and Gauss-Seidel converge on a diagonally dominant system', () {
      final gs = LinAlg.iterative(a, b, seidel: true, tolPercent: 1e-10);
      final jc = LinAlg.iterative(a, b, seidel: false, tolPercent: 1e-10);
      expect(gs.converged, isTrue);
      expect(jc.converged, isTrue);
      expect(gs.x[1], closeTo(-2.5, 1e-8));
      expect(gs.iterations, lessThanOrEqualTo(jc.iterations));
    });
    test('singular matrix throws', () {
      expect(() => LinAlg.gauss([
            [1, 2],
            [2, 4],
          ], [1, 2]), throwsA(isA<LinError>()));
    });
    test('power method', () {
      final r = LinAlg.powerMethod([
        [2, 0],
        [0, 1],
      ]);
      expect(r.value, closeTo(2, 1e-8));
    });
  });

  group('Fitting', () {
    test('Chapra 17.1 linear regression', () {
      final x = <double>[1.0, 2, 3, 4, 5, 6, 7];
      final y = <double>[0.5, 2.5, 2.0, 4.0, 3.5, 6.0, 5.5];
      final f = Fitting.fit(FitModel.linear, x, y);
      expect(f.coeffs[0], closeTo(0.0714286, 1e-6));
      expect(f.coeffs[1], closeTo(0.8392857, 1e-6));
      expect(f.r2, closeTo(0.868, 1e-3));
      expect(f.syx, closeTo(0.7735, 1e-4));
    });
    test('polynomial recovers an exact quadratic', () {
      final x = <double>[0.0, 1, 2, 3, 4, 5];
      final y = [for (final v in x) 2 - 3 * v + 0.5 * v * v];
      final f = Fitting.fit(FitModel.polynomial, x, y, degree: 2);
      expect(f.coeffs[0], closeTo(2, 1e-9));
      expect(f.coeffs[1], closeTo(-3, 1e-9));
      expect(f.coeffs[2], closeTo(0.5, 1e-9));
      expect(f.r2, closeTo(1, 1e-12));
    });
    test('exponential and power fits', () {
      final x = <double>[0.0, 1, 2, 3];
      final y = [for (final v in x) 5 * math.exp(-0.4 * v)];
      final e = Fitting.fit(FitModel.exponential, x, y);
      expect(e.coeffs[0], closeTo(5, 1e-9));
      expect(e.coeffs[1], closeTo(-0.4, 1e-9));
      final px = <double>[1.0, 2, 3, 4];
      final p = Fitting.fit(FitModel.power, px, [for (final v in px) 2 * math.pow(v, 1.5).toDouble()]);
      expect(p.coeffs[0], closeTo(2, 1e-9));
      expect(p.coeffs[1], closeTo(1.5, 1e-9));
    });
    test('Lagrange, Newton and spline interpolation', () {
      final x = <double>[1.0, 4, 6];
      final y = <double>[0.0, 1.386294, 1.791759]; // ln x
      expect(Fitting.lagrange(x, y, 2), closeTo(0.5658444, 1e-6)); // Chapra 18.2
      final t = Fitting.dividedDifferences(x, y);
      expect(Fitting.newtonEval(x, t, 2), closeTo(0.5658444, 1e-6));
      final sx = <double>[0.0, 1, 2, 3];
      final sy = <double>[0.0, 1, 8, 27];
      final m2 = Fitting.splineSecondDerivs(sx, sy);
      expect(Fitting.splineEval(sx, sy, m2, 1), closeTo(1, 1e-12));
      expect(m2.first, 0);
      expect(m2.last, 0);
    });
    test('stats', () {
      final s = Stats.of([2, 4, 4, 4, 5, 5, 7, 9]);
      expect(s.mean, 5);
      expect(s.median, 4.5);
      expect(s.sd, closeTo(2.13809, 1e-5));
    });
  });

  group('Integration and differentiation', () {
    double p(double x) => 0.2 + 25 * x - 200 * x * x + 675 * math.pow(x, 3) - 900 * math.pow(x, 4) + 400 * math.pow(x, 5);
    test('Chapra polynomial on [0, 0.8]', () {
      expect(Integration.trapezoid(p, 0, 0.8, 1), closeTo(0.1728, 1e-4));
      expect(Integration.simpson13(p, 0, 0.8, 2), closeTo(1.367467, 1e-5));
      expect(Integration.simpson38(p, 0, 0.8, 3), closeTo(1.519170, 1e-5));
      expect(Integration.romberg(p, 0, 0.8, levels: 4).last.last, closeTo(1.640533, 1e-5));
      expect(Integration.gaussLegendre(p, 0, 0.8, 3), closeTo(1.640533, 1e-5));
      expect(Integration.adaptive(p, 0, 0.8).value, closeTo(1.6405333, 1e-6));
    });
    test('sin on [0, pi]', () {
      expect(Integration.simpson13(math.sin, 0, math.pi, 20), closeTo(2, 1e-5));
      expect(Integration.gaussLegendre(math.sin, 0, math.pi, 6), closeTo(2, 1e-7));
    });
    test('finite differences (Chapra 4.4)', () {
      double f(double x) => -0.1 * math.pow(x, 4) - 0.15 * math.pow(x, 3) - 0.5 * x * x - 0.25 * x + 1.2;
      final t = Differentiation.table(f, 0.5, 0.25);
      expect(t[0].value, closeTo(-1.155, 1e-3)); // forward O(h)
      expect(t[4].value, closeTo(-0.934375, 1e-6)); // centred O(h²)
      expect(t[5].value, closeTo(-0.9125, 1e-9)); // centred O(h⁴) exact for quartic
      expect(Differentiation.reference(f, 0.5), closeTo(-0.9125, 1e-8));
    });
  });

  group('ODEs', () {
    // dy/dt = -2t³ + 12t² - 20t + 8.5, y(0) = 1 (Chapra 25.1)
    List<double> rhs(double t, List<double> y) => [-2 * t * t * t + 12 * t * t - 20 * t + 8.5];
    double exact(double t) => -0.5 * math.pow(t, 4) + 4 * math.pow(t, 3) - 10 * t * t + 8.5 * t + 1;
    test('Euler matches the textbook value at t = 0.5', () {
      final s = Ode.solve(OdeMethod.euler, rhs, 0, [1], 4, 0.5);
      expect(s.y[1][0], closeTo(5.25, 1e-12));
    });
    test('RK4 is exact-ish for this polynomial', () {
      final s = Ode.solve(OdeMethod.rk4, rhs, 0, [1], 4, 0.5);
      expect(s.y.last[0], closeTo(exact(4), 1e-9));
    });
    test('order of accuracy: halving h', () {
      List<double> g(double t, List<double> y) => [y[0]];
      final e1 = (Ode.solve(OdeMethod.rk4, g, 0, [1], 1, 0.1).y.last[0] - math.e).abs();
      final e2 = (Ode.solve(OdeMethod.rk4, g, 0, [1], 1, 0.05).y.last[0] - math.e).abs();
      expect(e1 / e2, closeTo(16, 2));
      final h1 = (Ode.solve(OdeMethod.heun, g, 0, [1], 1, 0.1).y.last[0] - math.e).abs();
      final h2 = (Ode.solve(OdeMethod.heun, g, 0, [1], 1, 0.05).y.last[0] - math.e).abs();
      expect(h1 / h2, closeTo(4, 0.5));
    });
    test('RK45 adaptive meets tolerance', () {
      List<double> g(double t, List<double> y) => [-0.25 * y[0]];
      final s = Ode.solve(OdeMethod.rk45, g, 0, [100], 20, 1, tol: 1e-8);
      expect(s.y.last[0], closeTo(100 * math.exp(-5), 1e-5));
      expect(s.t.last, closeTo(20, 1e-12));
    });
    test('systems: harmonic oscillator conserves energy with RK4', () {
      List<double> g(double t, List<double> y) => [y[1], -y[0]];
      final s = Ode.solve(OdeMethod.rk4, g, 0, [1, 0], 2 * math.pi, 0.01);
      expect(s.y.last[0], closeTo(1, 1e-6));
      expect(s.y.last[1], closeTo(0, 1e-6));
    });
  });
}
