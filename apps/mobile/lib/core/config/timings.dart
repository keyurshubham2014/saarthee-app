/// Non-motion durations (network timeouts, debounce, back-off). Features use
/// these named constants instead of `Duration(` literals (T-03-22); motion
/// durations live in `SaartheeMotion`.
class AppTimings {
  const AppTimings._();

  /// JSON calls (v1 02 §5.3).
  static const Duration jsonTimeout = Duration(seconds: 15);

  /// Photo uploads.
  static const Duration uploadTimeout = Duration(seconds: 60);

  /// Ward list and locate lookups (TASK-03 §5.3).
  static const Duration wardsTimeout = Duration(seconds: 8);

  /// Search-as-you-type debounce.
  static const Duration searchDebounce = Duration(milliseconds: 250);

  /// Delay before the single automatic retry of an idempotent GET.
  static const Duration retryBackoff = Duration(milliseconds: 600);

  /// Location fix timeout for the ward step.
  static const Duration locationTimeout = Duration(seconds: 15);

  /// Analytics flush interval.
  static const Duration eventFlushInterval = Duration(seconds: 60);

  /// Fallback admin session length when the server omits `expiresAt`.
  static const Duration adminSessionFallback = Duration(hours: 8);

  /// India Standard Time offset from UTC (admin timestamps).
  static const Duration istOffset = Duration(hours: 5, minutes: 30);

  // TASK-04 (append-only).
  /// "Resend code" unlocks after this wait on the OTP screen.
  static const Duration otpResendWait = Duration(seconds: 30);

  /// Countdown tick (OTP resend timer).
  static const Duration countdownTick = Duration(seconds: 1);

  // TASK-05 (append-only).
  /// Duplicate check after the report pin settles.
  static const Duration nearbyDebounce = Duration(milliseconds: 500);
  // TASK-08 (append-only).
  /// In-app alert banner hides itself after this for Info/Advisory/Warning;
  /// Critical stays until dismissed or opened (TASK-08 §5.6).
  static const Duration alertBannerAutoHide = Duration(seconds: 8);

  /// Longest alert validity window (API `ALERT_MAX_VALIDITY_DAYS`).
  static const Duration alertMaxValidity = Duration(days: 14);

  /// Staff composer date picker range (from yesterday to 30 days ahead).
  static const Duration composerPickerBack = Duration(days: 1);
  static const Duration composerPickerAhead = Duration(days: 30);

  /// Default validity of a new alert in the composer.
  static const Duration composerDefaultSpan = Duration(hours: 6);

  /// On-device face and plate detection per photo (REQ-S-007); on timeout
  /// the flow falls back to the manual blur tool. Covers detection only
  /// (orientation and rendering are timed separately); 10 s leaves room for
  /// ML Kit's first-use model load on slow phones and emulators.
  static const Duration blurDetectTimeout = Duration(seconds: 10);
}
