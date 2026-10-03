# lib/core — shared foundation

For feature screens (citizen and admin). Screens read providers only; they
never import dio or `ApiClient` directly (data → application → presentation).

| Need | Import | What |
|---|---|---|
| API calls | `core/api/api_client.dart` | `apiClientProvider` → `ApiClient` (`getJson`, `postJson`, `patchJson`, `deleteJson`, `getBytes`, `uploadFile`). Base URL from `API_BASE_URL`, standard headers (`X-Install-Id`, `X-App-Version`, `X-Platform`, `X-Request-Id`), 15 s / 60 s timeouts. Every failure throws `AppError`. Pass `Authorization` per call via `headers:` or add an interceptor to `.dio`. |
| Errors | `core/api/app_error.dart`, `core/api/error_messages.dart` | `AppError(code, message, details, requestId, retryAfter, statusCode)`; `isOffline`, `isRateLimited`. `appErrorMessage(l10n, error)` maps every 03 §9.1 code to ARB text (Retry-After aware). |
| Theme | `core/theme/tokens.dart` | `AppColors` (the only colour source), `AppSpacing` (4-pt, `screen` 20, `touchTarget` 48, `primaryButtonHeight` 56, `maxContentWidth` 560), `AppRadii`, `AppMotion`. Theme: `core/theme/app_theme.dart`. |
| Strings | `core/l10n/app_localizations.dart` | `AppLocalizations.of(context)` (non-null). Generated on `flutter pub get`; not committed. Admin keys go below `@adminSectionStart`. |
| Settings | `core/settings/app_settings.dart` | `sharedPreferencesProvider`, `appSettingsProvider` (installId, inviteCode, groupLabel, onboardingDone). |
| Connectivity | `core/connectivity/connectivity_provider.dart` | `isOnlineProvider`, `isOfflineProvider`. |
| Analytics | `core/analytics/event_queue.dart` | `eventQueueProvider.track(name, props)`; `AppEvents` names. |
| Formatting | `core/utils/formatters.dart`, `validators.dart` | IST date/time, `+91 98765 43210`; phone / CCRS / invite validators. |
| Capture | `core/capture/evidence_capture.dart` | camera-only photo + GPS fix (citizen flows). |

## Widgets (`core/widgets/widgets.dart` barrel)
`PrimaryButton` (full width, ≥56, `loading` shows in-button progress and disables),
`SecondaryButton`, `StepScaffold`, `ChoiceCard` (+`ChoiceTone`), `StatusChip`
(`ComplaintStatus.fixed/notFixed/waiting/filed/reminded`, icon + word), `StatusStyle`,
`EmptyState`, `SkeletonBox`, `ErrorSummary` (+`ErrorSummaryItem`, takes focus),
`InlineFieldError`, `OfflineBanner` (optional `onRetry`, `message`),
`IndependenceNotice`, `EvidencePhoto`, `BeforeAfterCard`
(`BeforeAfterVariant.full/compact/citizenCheck`, `beforeOnly`, images as `ImageProvider`
— e.g. `MemoryImage(bytes)`), `ContentWidth`, `PinnedBottomLayout`.

## Router
`lib/router/app_router.dart` spreads `adminRoutes` (from `router/admin_routes.dart`)
into the single route table. Paths under `/admin` may rotate; all others are portrait.
`stepPage(state, child)` gives the reduce-motion-aware transition.
