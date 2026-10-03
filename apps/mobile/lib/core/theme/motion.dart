import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/motion_preference.dart';

/// A duration and its curve.
@immutable
class MotionSpec {
  const MotionSpec(this.duration, this.curve);

  final Duration duration;
  final Curve curve;

  bool get isInstant => duration == Duration.zero;

  @override
  bool operator ==(Object other) =>
      other is MotionSpec && other.duration == duration && other.curve == curve;

  @override
  int get hashCode => Object.hash(duration, curve);

  @override
  String toString() => 'MotionSpec(${duration.inMilliseconds} ms, $curve)';
}

/// DS §6 motion tokens. Every animation in the app reads these, normally
/// through `SaartheeMotion.of(context)` so reduced motion is honoured.
/// No `Duration(` literal may appear under `lib/features/**` (T-03-22).
class SaartheeMotion {
  const SaartheeMotion._();

  static const Curve standard = Cubic(0.2, 0, 0, 1);
  static const Curve spring = Cubic(0.34, 1.35, 0.64, 1);
  static const Curve emphasized = Cubic(0.05, 0.7, 0.1, 1);

  /// Press states, ripples, checkbox.
  static const MotionSpec instant = MotionSpec(
    Duration(milliseconds: 100),
    Curves.easeOut,
  );

  /// Chip colour, icon swaps, nav indicator.
  static const MotionSpec short = MotionSpec(
    Duration(milliseconds: 180),
    standard,
  );

  /// Page transitions, sheets, cross-fades.
  static const MotionSpec medium = MotionSpec(
    Duration(milliseconds: 280),
    standard,
  );

  /// Cards and tiles entering, toasts, the Report card (≤ 6% overshoot).
  static const MotionSpec springIn = MotionSpec(
    Duration(milliseconds: 380),
    spring,
  );

  /// Shared element card → detail, map camera.
  static const MotionSpec long = MotionSpec(
    Duration(milliseconds: 450),
    emphasized,
  );

  /// Lists and grids on first load: 60 ms between items, max 6 animated.
  static const Duration stagger = Duration(milliseconds: 60);

  /// Tile grids (report step 1 category tiles).
  static const Duration tileStagger = Duration(milliseconds: 35);
  static const int staggerMaxItems = 6;

  /// Map pins (TASK-07).
  static const Duration mapPinStagger = Duration(milliseconds: 30);
  static const int mapPinMaxAnimated = 20;

  /// Rise: 14 dp translate-Y + fade.
  static const double riseOffset = 14;

  /// Success check stroke draw, starting after its container.
  static const MotionSpec drawCheck = MotionSpec(
    Duration(milliseconds: 450),
    Curves.easeOut,
  );
  static const Duration drawCheckDelay = Duration(milliseconds: 150);

  /// Stat numbers, integers only.
  static const MotionSpec countUp = MotionSpec(
    Duration(milliseconds: 600),
    Curves.easeOutCubic,
  );

  static const double pressScale = 0.97;
  static const double popScaleFrom = 0.88;
  static const Duration shimmerPeriod = Duration(milliseconds: 1200);
  static const double launchMarkScaleFrom = 0.92;
  static const double selectSpringScale = 1.02;

  /// How long a toast stays (DS §5: 4 s). Not an animation, kept here so
  /// features never write a literal.
  static const Duration toastHold = Duration(seconds: 4);

  /// The full scheme.
  static const SaartheeMotionScheme full = SaartheeMotionScheme._(
    isReduced: false,
  );

  /// The reduced scheme (system "Remove animations" or Settings off).
  static const SaartheeMotionScheme reduced = SaartheeMotionScheme._(
    isReduced: true,
  );

  /// The scheme for [context]: reduced when `reducedMotionProvider` is true,
  /// or forced by a [MotionSchemeOverride] (staff console, tests).
  static SaartheeMotionScheme of(BuildContext context) {
    final override = context
        .dependOnInheritedWidgetOfExactType<MotionSchemeOverride>();
    if (override != null) return override.scheme;
    final flag = context.dependOnInheritedWidgetOfExactType<_MotionFlag>();
    final isReduced =
        flag?.reduced ??
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return isReduced ? reduced : full;
  }
}

/// Resolved motion for a context. In the reduced scheme transforms,
/// staggers, springs, draws and counts are `Duration.zero` (end state on
/// first frame) and page, tab, sheet transitions and content swaps become a
/// 100 ms cross-fade.
@immutable
class SaartheeMotionScheme {
  const SaartheeMotionScheme._({required this.isReduced, this.staff = false});

  final bool isReduced;

  /// Staff console: `short` fades only (DS §6 staff row).
  final bool staff;

  static const SaartheeMotionScheme staffScheme = SaartheeMotionScheme._(
    isReduced: false,
    staff: true,
  );

  static const MotionSpec _zero = MotionSpec(Duration.zero, Curves.linear);
  static const MotionSpec _fade = MotionSpec(
    Duration(milliseconds: 100),
    Curves.linear,
  );

  /// Transforms (press, rise, pop, spring, select) are off in staff and
  /// reduced schemes.
  bool get transforms => !isReduced && !staff;

  MotionSpec get instant => isReduced ? _zero : SaartheeMotion.instant;
  MotionSpec get short => isReduced ? _zero : SaartheeMotion.short;

  /// Page, tab and sheet transitions and content swaps.
  MotionSpec get medium => isReduced
      ? _fade
      : staff
      ? SaartheeMotion.short
      : SaartheeMotion.medium;
  MotionSpec get springIn => isReduced
      ? _zero
      : staff
      ? SaartheeMotion.short
      : SaartheeMotion.springIn;
  MotionSpec get long => isReduced
      ? _fade
      : staff
      ? SaartheeMotion.short
      : SaartheeMotion.long;
  Duration get stagger => transforms ? SaartheeMotion.stagger : Duration.zero;
  Duration get tileStagger =>
      transforms ? SaartheeMotion.tileStagger : Duration.zero;
  Duration get mapPinStagger =>
      transforms ? SaartheeMotion.mapPinStagger : Duration.zero;
  MotionSpec get drawCheck => isReduced ? _zero : SaartheeMotion.drawCheck;
  Duration get drawCheckDelay =>
      isReduced ? Duration.zero : SaartheeMotion.drawCheckDelay;
  MotionSpec get countUp => isReduced ? _zero : SaartheeMotion.countUp;

  /// Content cross-fade (skeleton → content): `medium`, or 100 ms reduced.
  MotionSpec get crossFade => medium;

  double get pressScale => transforms ? SaartheeMotion.pressScale : 1;
  double get riseOffset => transforms ? SaartheeMotion.riseOffset : 0;

  /// Shimmer sweeps only with full motion; static when reduced.
  bool get shimmer => !isReduced;
}

/// Forces a scheme for a subtree (used by `StaffMotionScope` and tests).
class MotionSchemeOverride extends InheritedWidget {
  const MotionSchemeOverride({
    super.key,
    required this.scheme,
    required super.child,
  });

  final SaartheeMotionScheme scheme;

  @override
  bool updateShouldNotify(MotionSchemeOverride oldWidget) =>
      oldWidget.scheme != scheme;
}

/// Publishes the system "Remove animations" flag into
/// `systemDisableAnimationsProvider` and the resolved reduced flag to
/// descendants. Placed above `MaterialApp.router` (inside it, via `builder`,
/// so it sees the platform `MediaQuery`).
class MotionScope extends ConsumerStatefulWidget {
  const MotionScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MotionScope> createState() => _MotionScopeState();
}

class _MotionScopeState extends ConsumerState<MotionScope> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    final system = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (ref.read(systemDisableAnimationsProvider) != system) {
      // Riverpod forbids provider writes during build; defer one microtask.
      Future.microtask(() {
        if (mounted) {
          ref.read(systemDisableAnimationsProvider.notifier).set(system);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final system = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final reduced = system || ref.watch(reducedMotionProvider);
    return _MotionFlag(reduced: reduced, child: widget.child);
  }
}

class _MotionFlag extends InheritedWidget {
  const _MotionFlag({required this.reduced, required super.child});

  final bool reduced;

  @override
  bool updateShouldNotify(_MotionFlag oldWidget) =>
      oldWidget.reduced != reduced;
}
