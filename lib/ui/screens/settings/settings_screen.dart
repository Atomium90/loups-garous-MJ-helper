import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../state/settings/settings.dart';
import '../../../state/settings/settings_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_segmented_control.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/bientot_pill.dart';
import '../../widgets/section_label.dart';

/// Réglages. Reached from the gear on Accueil and from the in-game header;
/// pushed, so `pop` returns to whichever it was opened from.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const _SettingsBody(settings: AppSettings.defaults, notifier: null),
          data: (settings) => _SettingsBody(settings: settings, notifier: notifier),
        ),
      ),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({required this.settings, required this.notifier});

  final AppSettings settings;
  final Settings? notifier;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Column(
      children: [
        _Header(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 20, AppSpacing.screen, 4),
            children: [
              const SectionLabel('Contenu'),
              _NavRow(
                icon: AppIcons.boxes,
                label: 'Mes boîtes',
                sublabel: 'Boîte de base · 8 rôles',
                onTap: () => context.pushNamed('boxes'),
              ),
              const _ComingSoonRow(icon: AppIcons.regulars, label: "Carnet d'habitués"),
              const SizedBox(height: 22),
              const SectionLabel('Apparence'),
              const SizedBox(height: 10),
              AppSegmentedControl<ThemeMode>(
                selected: settings.themeMode,
                onChanged: (m) => notifier?.setThemeMode(m),
                options: const [
                  (value: ThemeMode.system, icon: AppIcons.themeSystem, label: 'Système'),
                  (value: ThemeMode.light, icon: AppIcons.themeLight, label: 'Clair'),
                  (value: ThemeMode.dark, icon: AppIcons.themeDark, label: 'Sombre'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "En soirée, le thème sombre fatigue moins l'œil et n'éclaire pas la table.",
                style: typography.counter.copyWith(color: colors.textTertiary, height: 1.55),
              ),
              const SizedBox(height: 22),
              const SectionLabel('Pendant la partie'),
              _ToggleRow(
                icon: AppIcons.screenOn,
                label: "Garder l'écran allumé",
                value: settings.keepScreenOn,
                onChanged: (v) => notifier?.setKeepScreenOn(v),
              ),
              _ToggleRow(
                icon: AppIcons.help,
                label: 'Aide-mémoire dans le script',
                value: settings.aideMemoireInScript,
                onChanged: (v) => notifier?.setAideMemoireInScript(v),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          padding: const EdgeInsets.fromLTRB(0, 12, 0, AppSpacing.screen),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.borderHairline)),
          ),
          child: Text(
            'Loup Garou MJ · V1 · hors ligne',
            style: typography.counter.copyWith(color: colors.textTertiary),
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
            'Réglages',
            style: context.typography.screenTitle.copyWith(color: colors.textPrimary),
          ),
        ],
      ),
    );
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

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => _SettingsRow(
    icon: icon,
    label: label,
    onTap: () => onChanged(!value),
    trailing: AppToggle(value: value, onChanged: onChanged),
  );
}
