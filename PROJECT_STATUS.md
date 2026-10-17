# NumeriLab — project status

Numerical methods lab for Android (Flutter 3.24.5, no plugins).

## Build
Same pipeline as TerraPlot: CI runs `flutter create` for the Android folder,
`tool/patch_android.sh` sets the name, icon and permission, then analyze,
test, build and publish a GitHub Release `build-N` with the APK.

## Version 0.1
- Core: expression engine (`core/expr.dart`), roots, linear algebra, fitting
  and interpolation, integration, differentiation, ODEs (`core/`).
- Screens: plotter, roots, linear systems, optimisation, curve fitting,
  integration, differentiation, ODE solver, home with scratchpad.
- Tests in `test/widget_test.dart` check methods against Chapra textbook
  examples and exact answers.

## Ideas next
- Save sessions and favourites; export results as PDF/CSV files
- Nonlinear systems (Newton for 2–3 equations), boundary-value problems
- Eigenvalues by QR, SVD; FFT; finite-difference PDE (heat equation) demo
