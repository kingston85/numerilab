# NumeriLab

A numerical methods lab for Android, fully offline. It follows the standard
engineering syllabus (Chapra & Canale) and shows its working: iteration
tables, convergence plots and step-by-step matrices.

- Function plotter with zoom, pan, trace, roots and turning points
- Roots: bisection, false position, Newton-Raphson, secant, fixed-point
- Linear systems: Gauss with pivoting (steps), LU, Gauss-Jordan inverse,
  Jacobi, Gauss-Seidel with relaxation, determinant, condition number,
  power method
- Optimisation: golden-section search
- Curve fitting: linear, polynomial, exponential, power, logarithmic,
  saturation growth, r², standard error, calibration LOD/LOQ; Lagrange,
  Newton divided differences, natural cubic splines
- Integration: trapezoidal, Simpson 1/3 and 3/8, Romberg tableau,
  Gauss-Legendre, adaptive Simpson
- Differentiation: forward, backward, centred, Richardson, error vs h
- ODEs: Euler, Heun, midpoint, Ralston, RK4, adaptive RK45; systems of two
  equations with phase plane

## Download

Get the latest APK from **Releases**.

## Development

Flutter 3.24.5, no plugins. GitHub Actions generates the Android project,
runs `test/` (methods checked against textbook values) and builds the APK.
