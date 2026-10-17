import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/expr.dart';
import 'screens/diff_opt_screens.dart';
import 'screens/fitting_screen.dart';
import 'screens/integration_screen.dart';
import 'screens/linear_screen.dart';
import 'screens/ode_screen.dart';
import 'screens/plotter_screen.dart';
import 'screens/roots_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/components.dart';

final ValueNotifier<bool> daylight = ValueNotifier(false);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NumeriLabApp());
}

class NumeriLabApp extends StatelessWidget {
  const NumeriLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: daylight,
      builder: (context, light, _) {
        SystemChrome.setSystemUIOverlayStyle(light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light);
        return MaterialApp(
          title: 'NumeriLab',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(light ? NLColors.daylight : NLColors.lab),
          home: const HomeScreen(),
        );
      },
    );
  }
}

class _Module {
  final String title;
  final String body;
  final String chapter;
  final IconData icon;
  final Widget Function() page;
  const _Module(this.title, this.body, this.chapter, this.icon, this.page);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _calc = TextEditingController(text: 'sqrt(2) * pi / 3');

  static final _modules = <_Module>[
    _Module('Function plotter', 'Graph, zoom, trace; roots and turning points', 'Graphs', Icons.show_chart_rounded,
        () => const PlotterScreen()),
    _Module('Roots of equations', 'Bisection, false position, Newton, secant, fixed-point', 'Part 2',
        Icons.adjust_rounded, () => const RootsScreen()),
    _Module('Linear systems', 'Gauss with steps, LU, inverse, Jacobi, Gauss-Seidel', 'Part 3', Icons.grid_on_rounded,
        () => const LinearScreen()),
    _Module('Optimisation', 'Golden-section search for maxima and minima', 'Part 4', Icons.landscape_rounded,
        () => const OptimizationScreen()),
    _Module('Curve fitting', 'Regression, r², Lagrange, Newton, cubic splines, LOD', 'Part 5', Icons.scatter_plot_rounded,
        () => const FittingScreen()),
    _Module('Integration', 'Trapezoid, Simpson, Romberg, Gauss-Legendre, adaptive', 'Part 6', Icons.area_chart_rounded,
        () => const IntegrationScreen()),
    _Module('Differentiation', 'Finite differences, Richardson, error vs h', 'Part 6', Icons.trending_up_rounded,
        () => const DifferentiationScreen()),
    _Module('ODE solver', 'Euler, Heun, midpoint, RK4, adaptive RK45, systems', 'Part 7', Icons.waves_rounded,
        () => const OdeScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final v = evalNumber(_calc.text);
    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 132,
              backgroundColor: c.bg,
              surfaceTintColor: Colors.transparent,
              actions: [
                ValueListenableBuilder<bool>(
                  valueListenable: daylight,
                  builder: (context, light, _) => IconButton(
                    tooltip: light ? 'Lab (dark) theme' : 'Daylight theme',
                    icon: Icon(light ? Icons.dark_mode_outlined : Icons.wb_sunny_outlined),
                    onPressed: () => daylight.value = !light,
                  ),
                ),
                IconButton(
                  tooltip: 'About',
                  icon: const Icon(Icons.info_outline_rounded),
                  onPressed: () => showAboutDialog(
                    context: context,
                    applicationName: 'NumeriLab',
                    applicationVersion: '0.1',
                    applicationLegalese: 'Numerical methods for engineers, offline.\nBuilt for Sahr Emmanuel.',
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 14),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('NUMERI', style: NLText.label(c.ink, size: 16)),
                    Text('LAB', style: NLText.label(c.accent, size: 16)),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: c.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PanelLabel('Scratchpad'),
                      TextField(
                        controller: _calc,
                        onChanged: (_) => setState(() {}),
                        style: NLText.reading(17, c.ink),
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.visiblePassword,
                        decoration: const InputDecoration(
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                          hintText: 'Type any expression, e.g. exp(1.5)/3',
                        ),
                      ),
                      Row(
                        children: [
                          Text('= ', style: NLText.reading(22, c.accent, weight: FontWeight.w700)),
                          Expanded(
                            child: SelectableText(
                              v == null ? '—' : fmt(v, sig: 14),
                              style: NLText.reading(22, c.ink, weight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SectionHeader('Modules')),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 40),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.92,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _ModuleCard(m: _modules[i]),
                  childCount: _modules.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final _Module m;
  const _ModuleCard({required this.m});

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return NLCard(
      padding: const EdgeInsets.all(14),
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => m.page()));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(m.icon, color: c.accent, size: 24),
              ),
              const Spacer(),
              Text(m.chapter.toUpperCase(), style: NLText.label(c.inkDim, size: 9.5)),
            ],
          ),
          const Spacer(),
          Text(m.title, style: NLText.body(c.ink, size: 15.5, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(m.body, style: NLText.body(c.inkDim, size: 12.5), maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
