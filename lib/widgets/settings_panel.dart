import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/acorn_links.dart';
import '../l10n/app_strings.dart';
import '../state/library_controller.dart';
import '../state/settings_controller.dart';
import '../theme/acorn_palette.dart';
import '../theme/neu_style.dart';
import 'neu_container.dart';
import 'neu_icon_button.dart';

/// Shown in the hero, the About card and hub subtitles; mirrors pubspec.
const _appVersion = '1.0.0';
const _company = 'Acorn Associated';
const _place = 'Qamishli';

/// Opens the settings half-panel sliding in from the right.
abstract final class SettingsPanel {
  static Future<void> open(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierLabel: context.t('settings'),
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondary) {
        return _SettingsSheet(animation: animation);
      },
      transitionBuilder: (context, animation, secondary, child) {
        return child;
      },
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final width = wide
        ? (MediaQuery.sizeOf(context).width * 0.48).clamp(320.0, 440.0)
        : MediaQuery.sizeOf(context).width * 0.86;
    final palette = context.palette;
    final slide = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.centerRight,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(slide),
          child: SizedBox(
            width: width,
            height: double.infinity,
            child: DecoratedBox(
              decoration: NeuStyle.dockPanel(
                shadowOffset: const Offset(-8, 0),
                palette: palette,
              ),
              child: const SafeArea(left: false, child: _SettingsBody()),
            ),
          ),
        ),
      ),
    );
  }
}

/// The settings categories, in panel order. Theme lives on the panel itself.
enum _HubId {
  language(Icons.translate_rounded),
  library(Icons.library_music_rounded),
  contact(Icons.alternate_email_rounded),
  social(Icons.share_outlined),
  donate(Icons.volunteer_activism_rounded),
  about(Icons.info_outline_rounded);

  const _HubId(this.icon);

  final IconData icon;
}

/// Header plus either the category hub or one open category.
class _SettingsBody extends StatefulWidget {
  const _SettingsBody();

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  _HubId? _section;

  void handleOpen(_HubId id) => setState(() => _section = id);

  void handleBack() => setState(() => _section = null);

  @override
  Widget build(BuildContext context) {
    final section = _section;
    return Column(
      children: [
        _PanelHeader(
          title: section == null
              ? context.t('settings')
              : _titleFor(context, section),
          subtitle: section == null
              ? '$_company · $_place'
              : _subtitleFor(context, section),
          onBack: section == null ? null : handleBack,
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.07, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: section == null
                ? _HubList(key: const ValueKey('hub'), onOpen: handleOpen)
                : _SectionView(key: ValueKey(section), id: section),
          ),
        ),
      ],
    );
  }
}

/// Category name used both on the hub row and in the panel header.
String _titleFor(BuildContext context, _HubId id) => switch (id) {
  _HubId.language => context.t('language'),
  _HubId.library => context.t('librarySection'),
  _HubId.contact => context.t('contact'),
  _HubId.social => context.t('social'),
  _HubId.donate => context.t('donate'),
  _HubId.about => context.t('about'),
};

/// One-line hint under the category name, showing the current choice when there
/// is one so the hub answers most questions without being opened.
String _subtitleFor(BuildContext context, _HubId id) {
  final settings = context.watch<SettingsController>();
  return switch (id) {
    _HubId.language => settings.locale.nativeName,
    _HubId.library =>
      '${context.t('musicFolder')} · ${context.t('rescanLibrary')}',
    _HubId.contact =>
      '${context.t('contactInfo')} · ${context.t('contactSupport')}',
    _HubId.social => 'Facebook · Instagram · GitHub',
    _HubId.donate => '${context.t('donateCard')} · PayPal',
    _HubId.about => '$_company · $_place',
  };
}

Widget _contentFor(_HubId id) => switch (id) {
  _HubId.language => const _LanguageSection(),
  _HubId.library => const _LibrarySection(),
  _HubId.contact => const _ContactSection(),
  _HubId.social => const _SocialSection(),
  _HubId.donate => const _DonateSection(),
  _HubId.about => const _AboutSection(),
};

/// App mark or back arrow, the current title, and the close button.
class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.subtitle,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      child: Row(
        children: [
          if (onBack case final back?)
            NeuIconButton(
              icon: Icons.arrow_back_rounded,
              size: 40,
              iconSize: 18,
              onPressed: back,
            )
          else
            const _AppMark(size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.styleAppBarTitle,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.styleMiniLabel,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          NeuIconButton(
            icon: Icons.close_rounded,
            size: 40,
            iconSize: 18,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Brand card followed by one row per category.
class _HubList extends StatelessWidget {
  const _HubList({super.key, required this.onOpen});

  final ValueChanged<_HubId> onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        const _RiseIn(index: 0, child: _HeroCard()),
        const SizedBox(height: 18),
        const _RiseIn(index: 1, child: _AppearanceSection()),
        const SizedBox(height: 20),
        for (final id in _HubId.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RiseIn(
              index: id.index + 2,
              child: _HubTile(id: id, onTap: () => onOpen(id)),
            ),
          ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final palette = context.palette;
    return NeuContainer(
      radius: 22,
      depth: 5,
      blur: 16,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const _AppMark(size: 56, halo: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Acorn Player',
                      style: context.styleTrackTitle.copyWith(fontSize: 16.5),
                    ),
                    const SizedBox(width: 8),
                    const _VersionPill(),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  context.t('tagline'),
                  maxLines: 2,
                  style: context.styleMiniLabel,
                ),
                const SizedBox(height: 8),
                Text(
                  '${context.strings.format('songsCount', {'count': '${library.allSongs.length}'})} · '
                  '${library.albums.length} ${context.t('albums')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.styleMiniLabel.copyWith(
                    color: palette.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({required this.id, required this.onTap});

  final _HubId id;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return _Pressable(
      onTap: onTap,
      child: NeuContainer(
        radius: 20,
        depth: 5,
        blur: 14,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _IconWell(icon: id.icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_titleFor(context, id), style: context.styleListTitle),
                  const SizedBox(height: 3),
                  Text(
                    _subtitleFor(context, id),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.styleMiniLabel,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: palette.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// One category, scrolled on its own so no content is ever cramped.
class _SectionView extends StatelessWidget {
  const _SectionView({super.key, required this.id});

  final _HubId id;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [_contentFor(id)],
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(context.t('theme')),
        Row(
          children: [
            for (final option in ThemePreference.values) ...[
              if (option != ThemePreference.values.first)
                const SizedBox(width: 8),
              Expanded(
                child: _ThemeOption(
                  option: option,
                  selected: settings.theme == option,
                  onTap: () => settings.setTheme(option),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _LanguageSection extends StatelessWidget {
  const _LanguageSection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 3,
      children: [
        for (final locale in AppLocale.values)
          _LocaleRow(
            locale: locale,
            selected: settings.locale == locale,
            onTap: () => settings.setLocale(locale),
          ),
      ],
    );
  }
}

/// Theme card: a miniature of the app in that mode above its name.
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final ThemePreference option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = context.t(switch (option) {
      ThemePreference.system => 'themeSystem',
      ThemePreference.light => 'themeLight',
      ThemePreference.dark => 'themeDark',
    });

    return _Pressable(
      onTap: onTap,
      child: NeuContainer(
        sunken: selected,
        radius: 16,
        depth: selected ? 3 : 5,
        blur: selected ? 8 : 12,
        padding: const EdgeInsets.all(8),
        glow: selected
            ? NeuStyle.glow(palette.accent, blur: 14, spread: -6, opacity: 0.5)
            : null,
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox(
                    height: 40,
                    width: double.infinity,
                    child: switch (option) {
                      ThemePreference.light => const _ThemeMock(light: true),
                      ThemePreference.dark => const _ThemeMock(light: false),
                      ThemePreference.system => const Row(
                        children: [
                          Expanded(child: _ThemeMock(light: true)),
                          Expanded(child: _ThemeMock(light: false)),
                        ],
                      ),
                    },
                  ),
                ),
                if (selected)
                  const Positioned(right: 3, top: 3, child: _CheckDot()),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.styleMiniLabel.copyWith(
                color: selected ? palette.accent : palette.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tiny stand-in for the player: accent pill on top, two content bars below.
class _ThemeMock extends StatelessWidget {
  const _ThemeMock({required this.light});

  final bool light;

  @override
  Widget build(BuildContext context) {
    final surface = light
        ? AcornPalette.light.surface
        : AcornPalette.dark.surface;
    final bar = light
        ? AcornPalette.light.shadowDark
        : AcornPalette.dark.shadowLight;

    return Container(
      color: surface,
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _MockBar(width: 14, color: context.palette.accent),
          _MockBar(width: double.infinity, color: bar),
          _MockBar(width: 18, color: bar),
        ],
      ),
    );
  }
}

class _MockBar extends StatelessWidget {
  const _MockBar({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Flag, native name and a check mark, so the list scans like a menu.
class _LocaleRow extends StatelessWidget {
  const _LocaleRow({
    required this.locale,
    required this.selected,
    required this.onTap,
  });

  final AppLocale locale;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return _Pressable(
      onTap: onTap,
      child: NeuContainer(
        sunken: selected,
        radius: 14,
        depth: selected ? 3 : 4,
        blur: selected ? 7 : 10,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        glow: selected
            ? NeuStyle.glow(palette.accent, blur: 14, spread: -7, opacity: 0.45)
            : null,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                locale.flagAsset,
                width: 27,
                height: 18,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                locale.nativeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.styleListSubtitle.copyWith(
                  fontSize: 11.5,
                  color: selected ? palette.accent : palette.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 14, color: palette.accent),
          ],
        ),
      ),
    );
  }
}

class _LibrarySection extends StatelessWidget {
  const _LibrarySection();

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final songs = library.allSongs;
    final folder = library.folder;
    final total = songs.fold(
      Duration.zero,
      (sum, song) => sum + song.duration,
    );
    final artists = songs
        .map((song) => song.artist.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .length;
    final liked = songs.where(library.isLiked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(context.t('librarySection')),
        _DashboardCard(
          songs: songs.length,
          duration: total,
          folder: folder,
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.4,
          children: [
            _StatTile(
              icon: Icons.album_rounded,
              value: '${library.albums.length}',
              label: context.t('albums'),
            ),
            _StatTile(
              icon: Icons.mic_external_on_rounded,
              value: '$artists',
              label: context.t('artists'),
            ),
            _StatTile(
              icon: Icons.queue_music_rounded,
              value: '${library.playlists.length}',
              label: context.t('playlists'),
            ),
            _StatTile(
              icon: Icons.favorite_rounded,
              value: '$liked',
              label: context.t('favorites'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SectionLabel(context.t('musicFolder')),
        NeuContainer(
          sunken: true,
          radius: 18,
          depth: 3,
          blur: 8,
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          child: Row(
            children: [
              _IconWell(icon: Icons.folder_rounded, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder == null
                          ? context.t('noFolder')
                          : p.basename(folder),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.styleListTitle,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      folder ?? context.t('needsFolder'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.styleMiniLabel,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              NeuIconButton(
                icon: Icons.edit_rounded,
                size: 40,
                iconSize: 16,
                onPressed: library.pickFolder,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _PrimaryButton(
          icon: Icons.refresh_rounded,
          label: context.t('rescanLibrary'),
          onTap: library.refresh,
        ),
      ],
    );
  }
}

/// Headline of the library dashboard: how much music there is, and where.
class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.songs,
    required this.duration,
    required this.folder,
  });

  final int songs;
  final Duration duration;
  final String? folder;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return NeuContainer(
      radius: 20,
      depth: 5,
      blur: 14,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const _IconWell(icon: Icons.equalizer_rounded, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$songs',
                  style: context.styleTrackTitle.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 2),
                Text(context.t('songs'), style: context.styleMiniLabel),
                const SizedBox(height: 8),
                Text(
                  '${_hours(duration)} · ${folder == null ? context.t('noFolder') : p.basename(folder!)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.styleMiniLabel.copyWith(
                    color: palette.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return NeuContainer(
      radius: 16,
      depth: 4,
      blur: 10,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: palette.icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.styleTrackTitle.copyWith(fontSize: 17),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.styleMiniLabel.copyWith(fontSize: 9.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact total playtime, e.g. `2h 14m` or `14m`.
String _hours(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
}

class _ContactSection extends StatelessWidget {
  const _ContactSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MailCard(
          icon: Icons.info_outline_rounded,
          label: context.t('contactInfo'),
          email: AcornLinks.infoEmail,
        ),
        const SizedBox(height: 8),
        _MailCard(
          icon: Icons.storefront_rounded,
          label: context.t('contactSales'),
          email: AcornLinks.salesEmail,
        ),
        const SizedBox(height: 8),
        _MailCard(
          icon: Icons.support_agent_rounded,
          label: context.t('contactSupport'),
          email: AcornLinks.supportEmail,
        ),
        const SizedBox(height: 8),
        _MailCard(
          icon: Icons.account_balance_wallet_rounded,
          label: context.t('contactPaypal'),
          email: AcornLinks.paypalEmail,
        ),
      ],
    );
  }
}

class _MailCard extends StatelessWidget {
  const _MailCard({
    required this.icon,
    required this.label,
    required this.email,
  });

  final IconData icon;
  final String label;
  final String email;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return _Pressable(
      onTap: () => _open('mailto:$email'),
      child: NeuContainer(
        radius: 18,
        depth: 4,
        blur: 12,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _IconWell(icon: icon, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.styleListTitle),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.styleMiniLabel,
                  ),
                ],
              ),
            ),
            Icon(Icons.north_east_rounded, size: 16, color: palette.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SocialSection extends StatelessWidget {
  const _SocialSection();

  static const _icons = <String, IconData>{
    'facebook': Icons.facebook,
    'x': Icons.close_rounded,
    'instagram': Icons.camera_alt_rounded,
    'youtube': Icons.play_circle_fill_rounded,
    'telegram': Icons.send_rounded,
    'linkedin': Icons.work_rounded,
    'github': Icons.code_rounded,
    'medium': Icons.article_rounded,
    'reddit': Icons.forum_rounded,
    'pinterest': Icons.push_pin_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 12),
          child: Text(context.t('tagline'), style: context.styleListSubtitle),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.1,
          children: [
            for (final link in AcornLinks.social)
              _SocialTile(
                icon: _icons[link.id] ?? Icons.link_rounded,
                label: link.label,
                onTap: () => _open(link.href),
              ),
          ],
        ),
      ],
    );
  }
}

class _SocialTile extends StatelessWidget {
  const _SocialTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: NeuContainer(
        radius: 16,
        depth: 4,
        blur: 10,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            _IconWell(icon: icon, size: 32, muted: true),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.styleListTitle.copyWith(fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PayMethod { card, paypal }

/// Pick an amount, pick a method, then leave for the payment page once.
class _DonateSection extends StatefulWidget {
  const _DonateSection();

  @override
  State<_DonateSection> createState() => _DonateSectionState();
}

class _DonateSectionState extends State<_DonateSection> {
  /// `null` is the open-ended "Other" tile.
  static const _amounts = <int?>[5, 10, 100, null];

  int _index = 1;
  _PayMethod _method = _PayMethod.card;

  void handleAmount(int index) => setState(() => _index = index);

  void handleMethod(_PayMethod method) => setState(() => _method = method);

  Future<void> handleContinue() {
    final amount = _amounts[_index];
    if (_method == _PayMethod.paypal) {
      return _open(AcornLinks.paypalSend(amount));
    }
    return _open(switch (amount) {
      5 => AcornLinks.stripe5,
      10 => AcornLinks.stripe10,
      100 => AcornLinks.stripe100,
      _ => AcornLinks.stripeOther,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NeuContainer(
          radius: 20,
          depth: 5,
          blur: 14,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const _IconWell(icon: Icons.favorite_rounded, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t('donate'), style: context.styleListTitle),
                    const SizedBox(height: 3),
                    Text(
                      context.t('tagline'),
                      maxLines: 2,
                      style: context.styleMiniLabel,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionLabel(context.t('donateAmount')),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.9,
          children: [
            for (var index = 0; index < _amounts.length; index++)
              _DonateTile(
                label: switch (_amounts[index]) {
                  final int amount => '\$$amount',
                  null => context.t('donateOther'),
                },
                selected: _index == index,
                onTap: () => handleAmount(index),
              ),
          ],
        ),
        const SizedBox(height: 18),
        _SectionLabel(context.t('donateMethod')),
        Row(
          children: [
            Expanded(
              child: _MethodChip(
                icon: Icons.credit_card_rounded,
                label: context.t('donateCard'),
                selected: _method == _PayMethod.card,
                onTap: () => handleMethod(_PayMethod.card),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MethodChip(
                icon: Icons.account_balance_wallet_rounded,
                label: context.t('donatePaypal'),
                selected: _method == _PayMethod.paypal,
                onTap: () => handleMethod(_PayMethod.paypal),
              ),
            ),
          ],
        ),
        if (_method == _PayMethod.paypal) ...[
          const SizedBox(height: 10),
          _ActionRow(
            icon: Icons.alternate_email_rounded,
            title: context.t('contactPaypal'),
            subtitle: AcornLinks.paypalEmail,
            trailing: const _CopyButton(text: AcornLinks.paypalEmail),
          ),
        ],
        const SizedBox(height: 16),
        _PrimaryButton(
          icon: Icons.lock_rounded,
          label: context.t('donateContinue'),
          onTap: handleContinue,
        ),
      ],
    );
  }
}

class _DonateTile extends StatelessWidget {
  const _DonateTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return _Pressable(
      onTap: onTap,
      child: NeuContainer(
        sunken: selected,
        radius: 16,
        depth: selected ? 3 : 4,
        blur: selected ? 8 : 10,
        glow: selected
            ? NeuStyle.glow(palette.accent, blur: 16, spread: -8, opacity: 0.5)
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.styleTrackTitle.copyWith(
                fontSize: 19,
                color: selected ? palette.accent : palette.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text('USD', style: context.styleMiniLabel),
          ],
        ),
      ),
    );
  }
}

/// Card or PayPal, styled like the theme cards so the panel stays consistent.
class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tint = selected ? palette.accent : palette.textSecondary;
    return _Pressable(
      onTap: onTap,
      child: NeuContainer(
        sunken: selected,
        radius: 16,
        depth: selected ? 3 : 4,
        blur: selected ? 8 : 10,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        glow: selected
            ? NeuStyle.glow(palette.accent, blur: 14, spread: -8, opacity: 0.45)
            : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: tint),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.styleListTitle.copyWith(
                  fontSize: 12.5,
                  color: tint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Accent call to action; one per page so the eye knows where to go.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return _Pressable(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              palette.accent,
              Color.lerp(palette.accent, Colors.black, 0.35)!,
            ],
          ),
          boxShadow: [
            ...NeuStyle.raised(depth: 4, blur: 10, palette: palette),
            ...NeuStyle.glow(palette.accent, blur: 18, spread: -8, opacity: 0.5),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.styleListTitle.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Copies text to the clipboard and confirms with a short check state.
class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.text});

  final String text;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> handleCopy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return NeuIconButton(
      icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
      size: 40,
      iconSize: 16,
      iconColor: _copied ? context.palette.accent : null,
      onPressed: handleCopy,
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeuContainer(
          radius: 22,
          depth: 5,
          blur: 16,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              const _AppMark(size: 64),
              const SizedBox(height: 12),
              Text(
                'Acorn Player',
                style: context.styleTrackTitle.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              const _VersionPill(),
              const SizedBox(height: 12),
              Text(
                context.t('tagline'),
                textAlign: TextAlign.center,
                style: context.styleListSubtitle,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ActionRow(
          icon: Icons.workspaces_rounded,
          title: _company,
          subtitle: _place,
        ),
        const SizedBox(height: 8),
        _ActionRow(
          icon: Icons.language_rounded,
          title: context.t('website'),
          subtitle: 'www.Acornik.com',
          onTap: () => _open(AcornLinks.site),
        ),
        const SizedBox(height: 8),
        _ActionRow(
          icon: Icons.code_rounded,
          title: 'GitHub',
          subtitle: AcornLinks.repo,
          onTap: () => _open(AcornLinks.repo),
        ),
        const SizedBox(height: 8),
        _ActionRow(
          icon: Icons.verified_rounded,
          title: context.t('version'),
          subtitle: 'v$_appVersion',
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(context.t('builtBy'), style: context.styleMiniLabel),
        ),
      ],
    );
  }
}

/// Uppercase group heading used inside a category.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Text(
        text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.styleMiniLabel.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// Tap feedback for whole cards: the surface dips like the soft-UI buttons.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void handleDown(TapDownDetails _) => setState(() => _down = true);

  void handleUp(TapUpDetails _) => setState(() => _down = false);

  void handleCancel() => setState(() => _down = false);

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? handleDown : null,
      onTapUp: enabled ? handleUp : null,
      onTapCancel: enabled ? handleCancel : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.975 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Lifts a card into place shortly after the panel opens, one after another.
class _RiseIn extends StatefulWidget {
  const _RiseIn({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<_RiseIn> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(
      Duration(milliseconds: 40 + widget.index * 45),
    ).then((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _shown ? Offset.zero : const Offset(0, 0.14),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 260),
        child: widget.child,
      ),
    );
  }
}

class _CheckDot extends StatelessWidget {
  const _CheckDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.palette.accent,
      ),
      child: const Icon(Icons.check_rounded, size: 10, color: Colors.white),
    );
  }
}

/// Sunken round well holding a glyph. Accent by default; [muted] for dense
/// grids where a wall of accent would shout.
class _IconWell extends StatelessWidget {
  const _IconWell({required this.icon, this.size = 42, this.muted = false});

  final IconData icon;
  final double size;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return NeuContainer(
      circle: true,
      sunken: true,
      width: size,
      height: size,
      depth: 3,
      blur: 7,
      child: Center(
        child: Icon(
          icon,
          size: size * 0.45,
          color: muted ? palette.icon : palette.accent,
        ),
      ),
    );
  }
}

class _VersionPill extends StatelessWidget {
  const _VersionPill();

  @override
  Widget build(BuildContext context) {
    return NeuContainer(
      sunken: true,
      radius: 9,
      depth: 2,
      blur: 5,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      child: Text(
        'v$_appVersion',
        style: context.styleMiniLabel.copyWith(
          color: context.palette.accent,
          fontWeight: FontWeight.w700,
          fontSize: 9.5,
        ),
      ),
    );
  }
}

/// Rounded app icon with a soft lift, used in the header, hero and About.
class _AppMark extends StatelessWidget {
  const _AppMark({this.size = 40, this.halo = false});

  final double size;

  /// Accent bloom behind the mark, used where the brand leads the page.
  final bool halo;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(size * 0.28);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          ...NeuStyle.raised(
            depth: size * 0.07,
            blur: size * 0.22,
            palette: palette,
          ),
          if (halo)
            ...NeuStyle.glow(
              palette.accent,
              blur: size * 0.55,
              spread: -size * 0.18,
              opacity: 0.5,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          'promo/app_icon.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return _Pressable(
      onTap: onTap,
      child: NeuContainer(
        sunken: true,
        radius: 16,
        depth: 3,
        blur: 8,
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: palette.icon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.styleListTitle),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.styleListSubtitle,
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Opens an http or mailto URL in the system handler.
Future<void> _open(String href) async {
  final uri = Uri.parse(href);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
