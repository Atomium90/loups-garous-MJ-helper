import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../../state/providers/game_repository_provider.dart';
import '../../../state/settings/settings.dart';
import '../../../state/settings/settings_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../utils/l10n.dart';
import '../../widgets/app_segmented_control.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/bientot_pill.dart';
import '../../widgets/confirm_sheet.dart';
import '../../widgets/section_label.dart';

/// Réglages. Reached from the gear on Accueil and from the in-game header;
/// pushed, so `pop` returns to whichever it was opened from.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final crashReports = ref.watch(crashReportingAvailableProvider);

    return Scaffold(
      body: SafeArea(
        child: settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _SettingsBody(
            settings: AppSettings.defaults,
            notifier: null,
            crashReportsAvailable: crashReports,
          ),
          data: (settings) => _SettingsBody(
            settings: settings,
            notifier: notifier,
            crashReportsAvailable: crashReports,
          ),
        ),
      ),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({
    required this.settings,
    required this.notifier,
    required this.crashReportsAvailable,
  });

  final AppSettings settings;
  final Settings? notifier;

  /// This build can send crash reports (it has a Sentry DSN), so the setting is offered.
  final bool crashReportsAvailable;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final pool = CardPool(registry: RoleRegistry.all, ownedBoxIds: settings.ownedBoxes);

    return Column(
      children: [
        _Header(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 20, AppSpacing.screen, 4),
            children: [
              SectionLabel(context.l10n.settingsContent),
              _NavRow(
                icon: AppIcons.boxes,
                label: context.l10n.settingsMyBoxes,
                sublabel: context.l10n.settingsOwnedBoxes(pool.ownedBoxIds.length, pool.availableRoleCount),
                onTap: () => context.pushNamed('boxes'),
              ),
              _ComingSoonRow(icon: AppIcons.regulars, label: context.l10n.regularsBook),
              const SizedBox(height: 22),
              SectionLabel(context.l10n.settingsRules),
              _SegmentedSetting<VoteTieRule>(
                title: context.l10n.settingsVoteTieTitle,
                hint: context.l10n.settingsVoteTieHint,
                selected: settings.voteTieRule,
                onChanged: (r) => notifier?.setVoteTieRule(r),
                options: [
                  (value: VoteTieRule.nobody, icon: null, label: context.l10n.voteTieNobody),
                  (value: VoteTieRule.captainDecides, icon: null, label: context.l10n.voteTieCaptain),
                  (value: VoteTieRule.revote, icon: null, label: context.l10n.voteTieRevote),
                ],
              ),
              _ToggleSetting(
                icon: AppIcons.thief,
                label: context.l10n.settingsThiefReserve,
                hint: context.l10n.settingsThiefReserveHint,
                value: settings.thiefReserveChosen,
                onChanged: (v) => notifier?.setThiefReserveChosen(v),
              ),
              _ToggleSetting(
                icon: AppIcons.fox,
                label: context.l10n.settingsFoxAfterWitch,
                hint: context.l10n.settingsFoxAfterWitchHint,
                value: settings.foxAfterWitch,
                onChanged: (v) => notifier?.setFoxAfterWitch(v),
              ),
              _ToggleSetting(
                icon: AppIcons.whiteWolf,
                label: context.l10n.settingsWhiteWolfOdd,
                hint: context.l10n.settingsWhiteWolfOddHint,
                value: settings.whiteWolfOddNights,
                onChanged: (v) => notifier?.setWhiteWolfOddNights(v),
              ),
              _ToggleSetting(
                icon: AppIcons.knight,
                label: context.l10n.settingsKnightNightEnd,
                hint: context.l10n.settingsKnightNightEndHint,
                value: settings.knightDiseaseAtNightEnd,
                onChanged: (v) => notifier?.setKnightDiseaseAtNightEnd(v),
              ),
              const SizedBox(height: 22),
              SectionLabel(context.l10n.settingsDuringGame),
              _SegmentedSetting<NarrationLevel>(
                title: context.l10n.settingsNarrationTitle,
                hint: context.l10n.settingsNarrationHint,
                selected: settings.narrationLevel,
                onChanged: (l) => notifier?.setNarrationLevel(l),
                options: [
                  (value: NarrationLevel.off, icon: null, label: context.l10n.narrationOff),
                  (value: NarrationLevel.short, icon: null, label: context.l10n.narrationShort),
                  (value: NarrationLevel.full, icon: null, label: context.l10n.narrationFull),
                ],
              ),
              _ToggleSetting(
                icon: AppIcons.help,
                label: context.l10n.settingsAideMemoire,
                value: settings.aideMemoireInScript,
                onChanged: (v) => notifier?.setAideMemoireInScript(v),
              ),
              _ToggleSetting(
                icon: AppIcons.help,
                label: context.l10n.settingsRevealDead,
                hint: context.l10n.settingsRevealDeadHint,
                value: settings.revealDeadCards,
                onChanged: (v) => notifier?.setRevealDeadCards(v),
              ),
              _ToggleSetting(
                icon: AppIcons.deal,
                label: context.l10n.settingsDealNotes,
                hint: context.l10n.settingsDealNotesHint,
                value: settings.dealNotesOnlyIfNeeded,
                onChanged: (v) => notifier?.setDealNotesOnlyIfNeeded(v),
              ),
              _ToggleSetting(
                icon: AppIcons.screenOn,
                label: context.l10n.settingsKeepScreenOn,
                value: settings.keepScreenOn,
                onChanged: (v) => notifier?.setKeepScreenOn(v),
              ),
              const SizedBox(height: 22),
              SectionLabel(context.l10n.settingsDisplay),
              _SegmentedSetting<ThemeMode>(
                title: context.l10n.settingsThemeTitle,
                hint: context.l10n.settingsThemeHint,
                selected: settings.themeMode,
                onChanged: (m) => notifier?.setThemeMode(m),
                options: [
                  (
                    value: ThemeMode.system,
                    icon: AppIcons.themeSystem,
                    label: context.l10n.themeSystem,
                  ),
                  (value: ThemeMode.light, icon: AppIcons.themeLight, label: context.l10n.themeLight),
                  (value: ThemeMode.dark, icon: AppIcons.themeDark, label: context.l10n.themeDark),
                ],
              ),
              _SegmentedSetting<AppLanguage>(
                title: context.l10n.settingsLanguageTitle,
                selected: settings.language,
                onChanged: (l) => notifier?.setLanguage(l),
                options: [
                  (
                    value: AppLanguage.system,
                    icon: AppIcons.themeSystem,
                    label: context.l10n.languageSystem,
                  ),
                  // Each language is named in itself, whatever the current one.
                  (value: AppLanguage.french, icon: AppIcons.language, label: 'Français'),
                  (value: AppLanguage.english, icon: AppIcons.language, label: 'English'),
                ],
              ),
              const SizedBox(height: 22),
              SectionLabel(context.l10n.settingsData),
              if (crashReportsAvailable)
                _ToggleSetting(
                  icon: AppIcons.crashReports,
                  label: context.l10n.settingsCrashReports,
                  hint: context.l10n.settingsCrashReportsHint,
                  value: settings.crashReports,
                  onChanged: (v) => notifier?.setCrashReports(v),
                ),
              const _DeleteAllGamesRow(),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          padding: const EdgeInsets.fromLTRB(0, 12, 0, AppSpacing.screen),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.borderHairline)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text(
                context.l10n.settingsFooter,
                style: typography.counter.copyWith(color: colors.textTertiary),
              ),
              Text(
                context.l10n.settingsOnDevice,
                style: typography.counter.copyWith(color: colors.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 24, AppSpacing.screen, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(AppIcons.back, size: 18, color: colors.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 10),
          Text(
            context.l10n.settingsTitle,
            style: context.typography.screenTitle.copyWith(color: colors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// "Supprimer toutes les parties": a clean slate for the games list, after a confirmation.
class _DeleteAllGamesRow extends ConsumerWidget {
  const _DeleteAllGamesRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsRow(
      icon: AppIcons.delete,
      label: context.l10n.deleteAllRow,
      sublabel: context.l10n.deleteAllRowHint,
      onTap: () => _confirm(context, ref),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final doneMessage = context.l10n.deleteAllDone;
    final deleted = await showConfirmSheet(
      context,
      title: context.l10n.deleteAllTitle,
      message: context.l10n.deleteAllMessage,
      confirmLabel: context.l10n.deleteAllConfirm,
      onConfirm: () => ref.read(gameRepositoryProvider).deleteAllGames(),
    );
    if (deleted == true) {
      messenger.showSnackBar(SnackBar(content: Text(doneMessage)));
    }
  }
}

/// A settings row with a hairline top border and a trailing widget.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.sublabel,
    this.trailing,
    this.dimmed = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? sublabel;
  final Widget? trailing;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final fg = dimmed ? colors.textTertiary : colors.textPrimary;

    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: dimmed ? 0.55 : 1,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.borderHairline)),
          ),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.rowSettings),
          child: Row(
            spacing: 12,
            children: [
              Icon(icon, size: 19, color: dimmed ? colors.textTertiary : colors.textSecondary),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: typography.rowLabel.copyWith(color: fg)),
                    if (sublabel != null)
                      Text(
                        sublabel!,
                        style: typography.meta.copyWith(color: colors.textTertiary),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    this.sublabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? sublabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _SettingsRow(
    icon: icon,
    label: label,
    sublabel: sublabel,
    onTap: onTap,
    trailing: Icon(AppIcons.chevronRight, size: 16, color: context.colors.textTertiary),
  );
}

class _ComingSoonRow extends StatelessWidget {
  const _ComingSoonRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) =>
      _SettingsRow(icon: icon, label: label, dimmed: true, trailing: const BientotPill());
}

/// An on/off setting: its row, and the short explanation under it when it has one.
class _ToggleSetting extends StatelessWidget {
  const _ToggleSetting({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final IconData icon;
  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SettingsRow(
        icon: icon,
        label: label,
        onTap: () => onChanged(!value),
        trailing: AppToggle(value: value, onChanged: onChanged),
      ),
      if (hint != null) _Hint(hint!, bottom: 4),
    ],
  );
}

/// A setting with a few exclusive choices: a title, the segmented control and, when there is one,
/// its explanation.
class _SegmentedSetting<T> extends StatelessWidget {
  const _SegmentedSetting({
    required this.title,
    required this.selected,
    required this.onChanged,
    required this.options,
    this.hint,
  });

  final String title;
  final String? hint;
  final T selected;
  final ValueChanged<T> onChanged;
  final List<({T value, IconData? icon, String label})> options;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.typography.rowLabel.copyWith(color: context.colors.textPrimary),
        ),
        const SizedBox(height: 10),
        AppSegmentedControl<T>(selected: selected, onChanged: onChanged, options: options),
        if (hint != null) _Hint(hint!, top: 8),
      ],
    ),
  );
}

/// The small grey explanation under a setting.
class _Hint extends StatelessWidget {
  const _Hint(this.text, {this.top = 0, this.bottom = 0});

  final String text;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top, bottom: bottom),
    child: Text(
      text,
      style: context.typography.counter.copyWith(color: context.colors.textTertiary, height: 1.55),
    ),
  );
}
