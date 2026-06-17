import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../core/l10n.dart';
import '../state/clips_state.dart';
import '../widgets/glass_card.dart';

class SettingsScreen extends StatefulWidget {
  final ClipsState state;

  const SettingsScreen({super.key, required this.state});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Rect _sharePositionOrigin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final origin = box.localToGlobal(Offset.zero);
      return origin & box.size;
    }
    return const Rect.fromLTWH(0, 0, 1, 1);
  }

  Future<void> _exportClips() async {
    final clips = widget.state.allClips;
    final jsonStr = jsonEncode(clips.map((c) => c.toMap()).toList());
    if (!mounted) return;
    await Share.share(
      jsonStr,
      subject: 'Mes clips Reelr',
      sharePositionOrigin: _sharePositionOrigin(context),
    );
  }

  Future<void> _deleteAllData(BuildContext context) async {
    final l = AppL10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('settings_delete_all_confirm')),
        content: Text(l.t('settings_delete_all_confirm_sub')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l.t('delete')),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final clips = widget.state.allClips.toList();
      for (final clip in clips) {
        await widget.state.removeClip(clip.id);
      }
      final categories = widget.state.categories.toList();
      for (final category in categories) {
        await widget.state.removeCategory(category.id);
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final appState = ClipsApp.of(context)!;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            l.t('settings'),
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 26,
                letterSpacing: -0.5),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.t('theme'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 14),
                    SegmentedButton<ThemeMode>(
                      segments: [
                        ButtonSegment(
                            value: ThemeMode.system,
                            label: Text(l.t('system')),
                            icon: const Icon(Icons.brightness_auto_rounded)),
                        ButtonSegment(
                            value: ThemeMode.light,
                            label: Text(l.t('light')),
                            icon: const Icon(Icons.light_mode_rounded)),
                        ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text(l.t('dark')),
                            icon: const Icon(Icons.dark_mode_rounded)),
                      ],
                      selected: {appState.themeMode},
                      onSelectionChanged: (s) =>
                          appState.setThemeMode(s.first),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.t('language'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 14),
                    SegmentedButton<Locale>(
                      segments: const [
                        ButtonSegment(
                            value: Locale('fr'),
                            label: Text('Français'),
                            icon: Icon(Icons.language_rounded)),
                        ButtonSegment(
                            value: Locale('en'),
                            label: Text('English'),
                            icon: Icon(Icons.language_rounded)),
                      ],
                      selected: {appState.locale},
                      onSelectionChanged: (s) => appState.setLocale(s.first),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Section 3 — Mes données
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.t('settings_my_data_section'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    _SettingsRow(
                      icon: Icons.download_outlined,
                      label: l.t('settings_export_clips'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _exportClips,
                    ),
                    _SettingsRow(
                      icon: Icons.delete_outline,
                      label: l.t('settings_delete_all_data'),
                      labelStyle: const TextStyle(color: Colors.red),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: Colors.red),
                      onTap: () => _deleteAllData(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Section 5 — Légal
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.t('settings_legal_section'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    _SettingsRow(
                      icon: Icons.privacy_tip_outlined,
                      label: l.t('settings_privacy_policy'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () =>
                          _launchUrl('https://www.privacypolicies.com/live/c2a22de0-c99c-487c-8f55-75e7958bd439'),
                    ),
                    _SettingsRow(
                      icon: Icons.gavel_outlined,
                      label: l.t('settings_terms'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () =>
                          _launchUrl('https://www.privacypolicies.com/live/b85682de-7528-4a66-a716-f94c0eab9d3d'),
                    ),
                    _SettingsRow(
                      icon: Icons.mail_outline,
                      label: l.t('settings_contact'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () =>
                          _launchUrl('mailto:hello@myreelr.app'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Section 6 — À propos
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.t('settings_about_section'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snap) {
                        final version =
                            snap.hasData ? snap.data!.version : '—';
                        return _SettingsRow(
                          icon: Icons.info_outline,
                          label: l.t('settings_version'),
                          trailing: Text(
                            'Version $version',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 13),
                          ),
                        );
                      },
                    ),
                    _SettingsRow(
                      icon: Icons.star_outline,
                      label: l.t('rate_app'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _launchUrl(
                          'https://apps.apple.com/app/idVOTRE_APP_ID'),
                    ),
                    _SettingsRow(
                      icon: Icons.share_outlined,
                      label: l.t('share_app'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Share.share(
                        l.locale.languageCode == 'fr' ? 'Découvre Reelr — sauvegarde tes vidéos préférées !' : 'Discover Reelr — save your favorite videos!',
                        sharePositionOrigin: _sharePositionOrigin(context),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextStyle? labelStyle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.labelStyle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: labelStyle ?? const TextStyle(fontSize: 15)),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
