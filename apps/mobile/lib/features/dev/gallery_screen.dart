import 'package:flutter/material.dart' hide ErrorSummary;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/motion_widgets.dart';
import '../../core/settings/locale_controller.dart';
import '../../core/settings/motion_preference.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/icons.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../launch/launch_gate.dart';

/// Debug-only component gallery (`/dev/gallery`, TASK-03 §5.4). Every
/// component in its states, with toggles for theme, locale, text scale and
/// reduced motion, and a Motion section with a Replay button per motion.
/// Not registered in profile or release builds. Copy here is developer-only
/// and exempt from the ARB rule (allow-listed in the string guard).
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  /// Every replay entry in the Motion section (T-03-11 checks this list).
  static const motionEntries = <String>[
    'Launch mark',
    'Shared axis',
    'Fade through',
    'Sheet',
    'Press',
    'Shimmer',
    'RiseIn',
    'PopIn',
    'StaggeredColumn',
    'SeenOnce',
    'MotionCheck',
    'CountUp',
    'RollingCount',
    'Toast',
    'Staff sample',
  ];

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  bool _dark = false;
  double _scale = 1;
  bool _reduced = false;

  @override
  Widget build(BuildContext context) {
    final gu = ref.watch(localeProvider).languageCode == 'gu';
    final theme = _dark ? AppTheme.dark() : AppTheme.light();
    final media = MediaQuery.of(context);
    return Theme(
      data: theme,
      child: MediaQuery(
        data: media.copyWith(
          textScaler: TextScaler.linear(_scale),
          disableAnimations: _reduced || media.disableAnimations,
        ),
        child: MotionSchemeOverride(
          scheme: _reduced ? SaartheeMotion.reduced : SaartheeMotion.full,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Gallery'),
              actions: [
                IconButton(
                  key: const Key('gallery.theme'),
                  tooltip: 'Theme',
                  icon: const Icon(SaartheeIcons.darkMode),
                  onPressed: () => setState(() => _dark = !_dark),
                ),
                TextButton(
                  key: const Key('gallery.locale'),
                  onPressed: () => ref.read(localeProvider.notifier).toggle(),
                  child: Text(gu ? 'gu' : 'en'),
                ),
                TextButton(
                  key: const Key('gallery.scale'),
                  onPressed: () => setState(
                    () => _scale = _scale == 1
                        ? 1.3
                        : _scale == 1.3
                        ? 2.0
                        : 1,
                  ),
                  child: Text('${_scale}x'),
                ),
                IconButton(
                  key: const Key('gallery.reduced'),
                  tooltip: 'Reduced motion',
                  icon: Icon(
                    SaartheeIcons.animation,
                    fill: _reduced
                        ? SaartheeIcons.fillOff
                        : SaartheeIcons.fillOn,
                  ),
                  onPressed: () => setState(() => _reduced = !_reduced),
                ),
              ],
            ),
            body: const _GalleryBody(),
          ),
        ),
      ),
    );
  }
}

class _GalleryBody extends StatelessWidget {
  const _GalleryBody();

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.s12),
          for (final w in children) ...[
            w,
            const SizedBox(height: AppSpacing.s12),
          ],
        ],
      ),
    );
    return ListView(
      key: const Key('gallery.list'),
      children: [
        HomeHeader(
          wardLabel: 'Ward 12 · Paldi',
          onWardTap: () {},
          onReport: () {},
          onBell: () {},
        ),
        section('Buttons', [
          PrimaryButton(label: 'Continue', onPressed: () {}),
          PrimaryButton(label: 'Pinned', pinned: true, onPressed: () {}),
          const PrimaryButton(label: 'Disabled', onPressed: null),
          PrimaryButton(label: 'Loading', isLoading: true, onPressed: () {}),
          SubmitReportButton(label: 'Submit report', onPressed: () {}),
          SecondaryButton(label: 'Secondary', onPressed: () {}),
          TertiaryButton(label: 'Tertiary', onPressed: () {}),
        ]),
        section('Inputs', [
          const LabeledTextField(label: 'Name', helper: 'Helper text'),
          const LabeledTextField(label: 'Note', optional: true),
          const LabeledTextField(label: 'Phone', error: 'Enter a number'),
          ErrorSummary(
            items: [ErrorSummaryItem('Enter a number', onTap: () {})],
          ),
        ]),
        section('Chips', [
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              for (final s in IssueStatus.values) StatusChip(status: s),
              for (final s in AlertSeverity.values) SeverityChip(severity: s),
              AppFilterChip(label: 'Open', selected: true, onSelected: (_) {}),
              AppFilterChip(
                label: 'Closed',
                selected: false,
                onSelected: (_) {},
              ),
              const OverdueTag(),
            ],
          ),
        ]),
        section('Category badges', [
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              for (final cat in CategoryStyle.all)
                CategoryBadge(slug: cat.slug),
            ],
          ),
        ]),
        section('Cards and rows', [
          const Row(
            children: [
              Expanded(child: StatTile(value: 37, label: 'Fixed this month')),
              SizedBox(width: AppSpacing.s12),
              Expanded(child: StatTile(value: 12, label: 'Open')),
            ],
          ),
          ListRow(
            title: 'Pothole near Paldi cross roads',
            subtitle: 'Ward 12 · 2 days ago',
            leading: const CategoryBadge(slug: 'roads'),
            trailing: const StatusChip(status: IssueStatus.inProgress),
            onTap: () {},
          ),
          IssueCard(
            title: 'Garbage not collected for three days',
            categorySlug: 'garbage',
            wardAndAge: 'Ward 12 · 3 days',
            status: IssueStatus.reported,
            meTooCount: 4,
            overdue: true,
            photoLabel: 'Photo of the problem',
            onTap: () {},
          ),
          for (final s in AlertSeverity.values)
            AlertCard(
              severity: s,
              title: 'Water supply cut on Sunday',
              area: 'Paldi, Vasna',
              validity: 'Until 6 pm',
              source: 'AMC water department',
            ),
          const StatusTimeline(
            steps: [
              TimelineStep(
                status: IssueStatus.reported,
                actor: 'You',
                date: '3 Oct',
              ),
              TimelineStep(
                status: IssueStatus.acknowledged,
                actor: 'Ward office',
                date: '4 Oct',
              ),
              TimelineStep(status: IssueStatus.markedFixed, isFuture: true),
            ],
          ),
          RepresentativeRow(
            name: 'Asha Patel',
            role: 'Corporator',
            ward: 'Ward 12',
            party: 'Independent',
            onMessage: () {},
          ),
          const PhotoThumb(
            image: null,
            semanticLabel: 'Photo of the problem',
            blurred: true,
          ),
        ]),
        section('Banners', [
          for (final k in NoticeKind.values)
            NoticeBanner(
              kind: k,
              message: k == NoticeKind.info ? 'Info' : null,
            ),
        ]),
        section('States', [
          EmptyState(
            message: 'Nothing here yet.',
            actionLabel: 'Refresh',
            onAction: () {},
          ),
          const SizedBox(height: 200, child: SkeletonList(count: 3)),
          ErrorState(message: "We couldn't load this.", onRetry: () {}),
          OfflineState(onRetry: () {}),
          StepHeader(step: 2, total: 3, nextHint: 'Details', onBack: () {}),
          const SaartheeToast(message: 'Saved'),
          const SaartheeToast(message: 'Heads up', kind: ToastKind.info),
          const SaartheeToast(message: 'Failed', kind: ToastKind.error),
        ]),
        section('Brand', [
          const Center(child: BrandMark(size: 72)),
          const Wordmark(),
        ]),
        section('Motion', [
          for (final name in GalleryScreen.motionEntries)
            _MotionReplay(name: name, color: c.primary),
        ]),
      ],
    );
  }
}

/// A motion sample with a Replay button that rebuilds it with a new key.
class _MotionReplay extends ConsumerStatefulWidget {
  const _MotionReplay({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  ConsumerState<_MotionReplay> createState() => _MotionReplayState();
}

class _MotionReplayState extends ConsumerState<_MotionReplay> {
  int _run = 0;
  int _count = 7;

  Widget _box(String label) => Container(
    padding: const EdgeInsets.all(AppSpacing.s12),
    decoration: AppElevation.cardDecoration(SaartheeColors.of(context)),
    child: Text(label),
  );

  Widget _sample(BuildContext context) {
    final key = ValueKey('${widget.name}.$_run');
    switch (widget.name) {
      case 'Launch mark':
        return SizedBox(
          key: key,
          height: 160,
          child: const LaunchGate(child: SizedBox.expand()),
        );
      case 'Shared axis':
        return TextButton(
          key: key,
          onPressed: () => Navigator.of(context).push(
            PageRouteBuilder<void>(
              transitionDuration: SaartheeMotion.of(context).medium.duration,
              pageBuilder: (_, _, _) => Scaffold(
                appBar: AppBar(),
                body: const Center(child: Text('Pushed page')),
              ),
              transitionsBuilder: (context, a, s, child) =>
                  SaartheeTransitions.page(
                    scheme: SaartheeMotion.of(context),
                    animation: a,
                    secondaryAnimation: s,
                    fillColor: SaartheeColors.of(context).background,
                    child: child,
                  ),
            ),
          ),
          child: const Text('Push a page'),
        );
      case 'Fade through':
        return SizedBox(
          key: key,
          height: 60,
          child: FadeThroughShellContainer(
            currentIndex: _run % 2,
            children: [_box('Tab A'), _box('Tab B')],
          ),
        );
      case 'Sheet':
        return TextButton(
          key: key,
          onPressed: () => showSaartheeSheet<void>(
            context: context,
            builder: (_) => const Padding(
              padding: EdgeInsets.all(AppSpacing.s24),
              child: Text('Sheet content'),
            ),
          ),
          child: const Text('Open a sheet'),
        );
      case 'Press':
        return Pressable(key: key, haptic: true, child: _box('Press me'));
      case 'Shimmer':
        return SizedBox(
          key: key,
          height: 140,
          child: SkeletonSwitcher(
            loading: _run.isEven,
            skeleton: const SkeletonList(count: 2),
            child: _box('Content arrived'),
          ),
        );
      case 'RiseIn':
        return RiseIn(key: key, child: _box('Risen'));
      case 'PopIn':
        return Wrap(
          key: key,
          spacing: AppSpacing.s8,
          children: [
            for (var i = 0; i < 6; i++)
              PopIn(
                index: i,
                child: CategoryBadge(slug: CategoryStyle.all[i].slug),
              ),
          ],
        );
      case 'StaggeredColumn':
        return StaggeredColumn(
          key: key,
          children: [for (var i = 1; i <= 8; i++) _box('Item $i')],
        );
      case 'SeenOnce':
        return SeenOnce(
          key: key,
          seenKey: 'gallery.seenOnce',
          builder: (context, animate) =>
              RiseIn(animate: animate, child: _box('Animates once a session')),
        );
      case 'MotionCheck':
        return MotionCheck(
          key: key,
          color: widget.color,
          semanticLabel: 'Done',
          size: 48,
        );
      case 'CountUp':
        return CountUp(key: key, value: 37);
      case 'RollingCount':
        return RollingCount(value: _count);
      case 'Toast':
        return TextButton(
          key: key,
          onPressed: () => showSaartheeToast(context, 'Message sent'),
          child: const Text('Show toast'),
        );
      case 'Staff sample':
        return StaffMotionScope(
          key: key,
          child: StaggeredColumn(
            children: [
              Pressable(child: _box('Staff row 1')),
              _box('Staff row 2'),
            ],
          ),
        );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(widget.name)),
            TextButton(
              key: Key('gallery.replay.${widget.name}'),
              onPressed: () {
                if (widget.name == 'SeenOnce') {
                  ref.read(seenOnceProvider).reset();
                }
                setState(() {
                  _run++;
                  _count++;
                });
              },
              child: const Text('Replay'),
            ),
          ],
        ),
        _sample(context),
      ],
    );
  }
}
