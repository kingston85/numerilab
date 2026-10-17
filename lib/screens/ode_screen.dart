import 'package:flutter/material.dart';

import '../core/calculus.dart';
import '../core/expr.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/inputs.dart';
import '../widgets/module_scaffold.dart';
import '../widgets/plot.dart';

class OdeScreen extends StatefulWidget {
  const OdeScreen({super.key});

  @override
  State<OdeScreen> createState() => _OdeScreenState();
}

class _OdePreset {
  final String name;
  final bool system;
  final String f, g, exact;
  final String t0, t1, h, y0, z0;
  const _OdePreset(this.name, this.system, this.f, this.g, this.t0, this.t1, this.h, this.y0, this.z0, [this.exact = '']);
}

class _OdeScreenState extends State<OdeScreen> {
  static const _presets = [
    _OdePreset('Chapra 25.1', false, '-2t^3 + 12t^2 - 20t + 8.5', '', '0', '4', '0.5', '1', '0',
        '-0.5t^4 + 4t^3 - 10t^2 + 8.5t + 1'),
    _OdePreset('1st-order reaction', false, '-0.25y', '', '0', '20', '1', '100', '0', '100exp(-0.25t)'),
    _OdePreset('Logistic growth', false, '0.5y(1 - y/100)', '', '0', '20', '0.5', '5', '0'),
    _OdePreset('Newton cooling', false, '-0.1(y - 25)', '', '0', '60', '2', '90', '0', '25 + 65exp(-0.1t)'),
    _OdePreset('Predator–prey', true, '1.2y - 0.6y z', '-0.8z + 0.3y z', '0', '30', '0.05', '2', '1'),
    _OdePreset('Damped spring', true, 'z', '-0.5z - 4y', '0', '20', '0.05', '1', '0'),
    _OdePreset('Series reactions A→B→C', true, '-0.5y', '0.5y - 0.2z', '0', '25', '0.25', '1', '0'),
  ];

  final _f = TextEditingController();
  final _g = TextEditingController();
  final _exact = TextEditingController();
  final _t0 = TextEditingController();
  final _t1 = TextEditingController();
  final _h = TextEditingController();
  final _y0 = TextEditingController();
  final _z0 = TextEditingController();
  bool _system = false;
  final Set<OdeMethod> _methods = {OdeMethod.euler, OdeMethod.heun, OdeMethod.rk4};
  bool _phase = false;

  @override
  void initState() {
    super.initState();
    _load(_presets[0]);
  }

  void _load(_OdePreset p) {
    _system = p.system;
    _f.text = p.f;
    _g.text = p.g;
    _exact.text = p.exact;
    _t0.text = p.t0;
    _t1.text = p.t1;
    _h.text = p.h;
    _y0.text = p.y0;
    _z0.text = p.z0;
    _phase = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    const vars = {'t', 'y', 'z'};
    final fe = Expr.tryParse(_f.text, vars: vars);
    final ge = _system ? Expr.tryParse(_g.text, vars: vars) : null;
    final ex = _system ? null : Expr.tryParse(_exact.text, vars: const {'t'});
    final t0 = numOf(_t0, 0), t1 = numOf(_t1, 1), h = numOf(_h, 0.1);
    final y0 = numOf(_y0, 0), z0 = numOf(_z0, 0);

    final ready = fe != null && (!_system || ge != null) && h > 0 && t1 != t0;
    final sols = <OdeSolution>[];
    if (ready) {
      final env = <String, double>{};
      List<double> rhs(double t, List<double> y) {
        env['t'] = t;
        env['y'] = y[0];
        env['z'] = y.length > 1 ? y[1] : 0;
        return _system ? [fe!.eval(env), ge!.eval(env)] : [fe!.eval(env)];
      }

      for (final m in OdeMethod.values) {
        if (_methods.contains(m)) {
          sols.add(Ode.solve(m, rhs, t0, _system ? [y0, z0] : [y0], t1, h, tol: 1e-7));
        }
      }
    }

    Color colorOf(OdeMethod m) => seriesColors[OdeMethod.values.indexOf(m) % seriesColors.length];

    final series = <Series>[
      if (!_phase)
        for (final s in sols) ...[
          PointSeries([for (var i = 0; i < s.t.length; i++) Offset(s.t[i], s.y[i][0])], colorOf(s.method),
              label: _system ? '${s.method.label} y' : s.method.label, dots: s.t.length <= 60),
          if (_system)
            PointSeries([for (var i = 0; i < s.t.length; i++) Offset(s.t[i], s.y[i][1])], colorOf(s.method),
                dashed: true, label: '${s.method.label} z'),
        ],
      if (_phase)
        for (final s in sols)
          PointSeries([for (final y in s.y) Offset(y[0], y[1])], colorOf(s.method), label: s.method.label),
      if (ex != null && !_phase) FnSeries((t) => ex.at(t, 't'), c.ink, label: 'exact', strokeWidth: 1.4),
    ];

    // Table: the most accurate selected method, sampled to ~25 rows.
    final best = sols.isEmpty ? null : sols.last;
    final tableRows = <List<String>>[];
    if (best != null) {
      final step = (best.t.length / 25).ceil().clamp(1, 1 << 30).toInt();
      for (var i = 0; i < best.t.length; i += step) {
        tableRows.add([
          fmt(best.t[i], sig: 6),
          fmt(best.y[i][0], sig: 8),
          if (_system) fmt(best.y[i][1], sig: 8),
          if (ex != null) fmt(ex.at(best.t[i], 't'), sig: 8),
          if (ex != null) fmt((ex.at(best.t[i], 't') - best.y[i][0]).abs(), sig: 3),
        ]);
      }
    }

    return ModuleScaffold(
      title: 'ODE solver',
      theory: _theory,
      children: [
        Presets(labels: [for (final p in _presets) p.name], onPick: (i) => _load(_presets[i])),
        const SizedBox(height: 12),
        Segmented<bool>(
          values: const [false, true],
          selected: _system,
          label: (v) => v ? 'System of 2' : 'Single equation',
          onChanged: (v) => setState(() {
            _system = v;
            if (v && _g.text.isEmpty) _g.text = '-y';
            if (!v) _phase = false;
          }),
        ),
        const SizedBox(height: 12),
        ExprField(
          controller: _f,
          label: _system ? 'dy/dt = f(t, y, z)' : 'dy/dt = f(t, y)',
          prefix: 'dy/dt =',
          vars: vars,
          keys: const ['y', 'z', 't', '^', '(', ')', '*', 'exp(', 'sin(', 'cos(', 'ln(', 'sqrt('],
          onChanged: (_) => setState(() {}),
        ),
        if (_system) ...[
          const SizedBox(height: 10),
          ExprField(
            controller: _g,
            label: 'dz/dt = g(t, y, z)',
            prefix: 'dz/dt =',
            vars: vars,
            keys: const ['y', 'z', 't', '^', '(', ')', '*', 'exp(', 'sin(', 'cos(', 'ln(', 'sqrt('],
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: NumField(controller: _t0, label: 't₀', onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: NumField(controller: _t1, label: 't end', onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: NumField(controller: _h, label: 'Step h', onChanged: (_) => setState(() {}))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: NumField(controller: _y0, label: 'y(t₀)', onChanged: (_) => setState(() {}))),
            if (_system) ...[
              const SizedBox(width: 8),
              Expanded(child: NumField(controller: _z0, label: 'z(t₀)', onChanged: (_) => setState(() {}))),
            ],
          ],
        ),
        if (!_system) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _exact,
            onChanged: (_) => setState(() {}),
            style: NLText.reading(14, c.ink),
            decoration: const InputDecoration(labelText: 'Exact solution y(t) (optional)', prefixText: 'y(t) = ', isDense: true),
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final m in OdeMethod.values)
              FilterChip(
                avatar: CircleAvatar(backgroundColor: colorOf(m), radius: 5),
                label: Text(m.label),
                selected: _methods.contains(m),
                onSelected: (v) => setState(() {
                  if (v) {
                    _methods.add(m);
                  } else if (_methods.length > 1) {
                    _methods.remove(m);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (!ready)
          const ResultCard(label: 'Input', value: 'Check the equations', sub: 'Use t, y (and z for systems). Step h must be > 0.', ok: false)
        else ...[
          ResultCard(
            label: 'Value at t = ${fmt(t1)}',
            value: [
              for (final s in sols)
                '${s.method.label}: y = ${fmt(s.y.last[0], sig: 8)}${_system ? ', z = ${fmt(s.y.last[1], sig: 8)}' : ''}'
            ].join('\n'),
            sub: [
              if (ex != null) 'Exact: y = ${fmt(ex.at(t1, 't'), sig: 8)}',
              for (final s in sols)
                if (s.warning != null) '${s.method.label}: ${s.warning}',
              for (final s in sols)
                if (s.method == OdeMethod.rk45) 'RK45 used ${s.steps} adaptive steps.',
            ].join('\n'),
          ),
          if (_system) ...[
            const SizedBox(height: 12),
            Segmented<bool>(
              values: const [false, true],
              selected: _phase,
              label: (v) => v ? 'Phase plane (z vs y)' : 'Time series',
              onChanged: (v) => setState(() => _phase = v),
            ),
          ],
          Section(
            _phase ? 'Phase plane' : 'Solution',
            child: Column(
              children: [
                PlotView(
                  height: 300,
                  series: series,
                  xLabel: _phase ? 'y' : 't',
                  yLabel: _phase ? 'z' : (_system ? 'y (solid), z (dashed)' : 'y'),
                ),
                PlotLegend(series),
              ],
            ),
          ),
          if (best != null)
            Section(
              'Table (${best.method.label})',
              child: ResultTable(
                columns: ['t', 'y', if (_system) 'z', if (ex != null) 'exact', if (ex != null) '|error|'],
                rows: tableRows,
              ),
            ),
        ],
      ],
    );
  }

  static const _theory = '''Solves initial-value problems dy/dt = f(t, y), y(t₀) = y₀, or a pair of coupled equations.

One-step methods advance the solution using slope estimates:
• Euler: y(i+1) = y(i) + f(t(i), y(i)) h, global error O(h)
• Heun: average of the slopes at the start and at an Euler predictor, O(h²)
• Midpoint: slope at the half step, O(h²)
• Ralston: optimal 2nd-order weights (1/3, 2/3), O(h²)
• Classical RK4: four slopes k₁…k₄, y(i+1) = y(i) + (k₁ + 2k₂ + 2k₃ + k₄) h/6, O(h⁴)
• RK45 (Fehlberg) compares 4th- and 5th-order results each step and adjusts h to keep the error below tolerance.

Halving h roughly halves Euler's error but divides RK4's by 16. Large steps can make explicit methods unstable (e.g. stiff or fast-decaying equations).''';
}
