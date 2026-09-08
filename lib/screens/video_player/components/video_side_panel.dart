import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fladder/models/items/media_streams_model.dart';
import 'package:fladder/models/playback/playback_model.dart';
import 'package:fladder/providers/settings/video_player_settings_provider.dart';
import 'package:fladder/providers/video_player_provider.dart';
import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/util/bitrate_helper.dart';
import 'package:fladder/util/localization_helper.dart';
import 'package:fladder/util/string_extensions.dart';
import 'package:fladder/widgets/shared/track_label.dart';

/// Panneau unique du lecteur — remplace la feuille de réglages centrée,
/// l'encart de pistes centré et la carte de qualité pleine largeur : une
/// seule surface, latérale, largeur fixe, qui glisse par-dessus la vidéo
/// sans la recentrer (cf. `DesktopControls`, qui la positionne).
enum VideoPanelSection {
  audio,
  subtitles,
  image,
  speed,
  quality;

  String get label => switch (this) {
        VideoPanelSection.audio => 'Audio',
        VideoPanelSection.subtitles => 'Sous-titres',
        VideoPanelSection.image => 'Image',
        VideoPanelSection.speed => 'Vitesse',
        VideoPanelSection.quality => 'Qualité',
      };
}

class _PanelItem {
  final Widget content;
  final bool selected;
  final VoidCallback? onActivate;
  const _PanelItem(
      {required this.content, required this.selected, this.onActivate});
}

const _speedPresets = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

/// Largeur fixe du panneau — mesure propre à ce composant, pas un jeton
/// partagé (même politique que les grilles Arr : une constante locale
/// suffit, cf. arr_queue_table.dart/arr_library_grid.dart). Exportée
/// (pas de `_`) : `DesktopControls` en a besoin pour animer la position
/// du panneau depuis hors-écran, sans dupliquer la valeur.
const videoSidePanelWidth = 340.0;

class VideoSidePanel extends ConsumerStatefulWidget {
  final VideoPanelSection initialSection;
  final VoidCallback onClose;

  const VideoSidePanel({
    required this.initialSection,
    required this.onClose,
    super.key,
  });

  @override
  ConsumerState<VideoSidePanel> createState() => _VideoSidePanelState();
}

class _VideoSidePanelState extends ConsumerState<VideoSidePanel> {
  late VideoPanelSection _section = widget.initialSection;
  int _itemIndex = 0;
  bool _qualityExpanded = false;
  final _focusNode = FocusNode(debugLabel: 'VideoSidePanel');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _setSection(VideoPanelSection section) {
    setState(() {
      _section = section;
      _itemIndex = 0;
    });
  }

  void _cycleSection(int delta) {
    final values = VideoPanelSection.values;
    final index = (values.indexOf(_section) + delta) % values.length;
    _setSection(values[(index + values.length) % values.length]);
  }

  Future<void> _selectAudio(AudioStreamModel stream) async {
    final playbackModel = ref.read(playBackModel);
    if (playbackModel == null) return;
    final player = ref.read(videoPlayerProvider);
    final newModel = await playbackModel.setAudio(stream, player);
    ref.read(playBackModel.notifier).update((state) => newModel);
    if (newModel != null) {
      await ref.read(playbackModelHelper).shouldReload(newModel);
    }
  }

  Future<void> _selectSubtitle(SubStreamModel stream) async {
    final playbackModel = ref.read(playBackModel);
    if (playbackModel == null) return;
    final player = ref.read(videoPlayerProvider);
    final newModel = await playbackModel.setSubtitle(stream, player);
    ref.read(playBackModel.notifier).update((state) => newModel);
    if (newModel != null) {
      await ref.read(playbackModelHelper).shouldReload(newModel);
    }
  }

  Future<void> _selectQuality(
      Map<Bitrate, bool> options, Bitrate chosen) async {
    final playbackModel = ref.read(playBackModel);
    final newModel = await playbackModel?.setQualityOption(
      options.map((key, value) => MapEntry(key, key == chosen)),
    );
    ref.read(playBackModel.notifier).update((state) => newModel);
    if (newModel != null) {
      await ref.read(playbackModelHelper).shouldReload(newModel);
    }
  }

  List<_PanelItem> _audioItems(BuildContext context) {
    final playbackModel = ref.watch(playBackModel);
    final currentIndex = playbackModel?.mediaStreams?.defaultAudioStreamIndex;
    final streams = playbackModel?.audioStreams ?? const [];
    return streams
        .map((stream) => _PanelItem(
              content: TrackLabelText(
                info: formatAudioTrackLabel(context, stream),
                selected: stream.index == currentIndex,
              ),
              selected: stream.index == currentIndex,
              onActivate: () => _selectAudio(stream),
            ))
        .toList();
  }

  List<_PanelItem> _subtitleItems(BuildContext context) {
    final playbackModel = ref.watch(playBackModel);
    final currentIndex = playbackModel?.mediaStreams?.defaultSubStreamIndex;
    final streams = [SubStreamModel.no(), ...?playbackModel?.subStreams];
    return streams
        .map((stream) => _PanelItem(
              content: TrackLabelText(
                info: formatSubtitleTrackLabel(context, stream),
                selected: stream.index == (currentIndex ?? -1),
              ),
              selected: stream.index == (currentIndex ?? -1),
              onActivate: () => _selectSubtitle(stream),
            ))
        .toList();
  }

  List<_PanelItem> _imageItems(BuildContext context) {
    final settings = ref.watch(videoPlayerSettingsProvider);
    final fitIndex = BoxFit.values.indexOf(settings.videoFit);
    return [
      _PanelItem(
        content: _SettingRow(
          label: context.localized.scale,
          value: settings.videoFit.name.toUpperCaseSplit(),
        ),
        selected: false,
        onActivate: () => ref
            .read(videoPlayerSettingsProvider.notifier)
            .setFitType(BoxFit.values[(fitIndex + 1) % BoxFit.values.length]),
      ),
      _PanelItem(
        content: _SettingRow(
          label: context.localized.playerSettingsAmbientBlurTitle,
          // Coûteux en 4K sur RDNA2 (BackdropFilter par image) —
          // désactivé par défaut, cf. CLAUDE.md.
          value: settings.ambientBlur ? 'Activé' : 'Désactivé',
        ),
        selected: settings.ambientBlur,
        onActivate: () => ref
            .read(videoPlayerSettingsProvider.notifier)
            .setAmbientBlur(!settings.ambientBlur),
      ),
    ];
  }

  List<_PanelItem> _speedItems(BuildContext context) {
    final current = ref.watch(playbackRateProvider);
    return _speedPresets
        .map((speed) => _PanelItem(
              content: Text('x${speed.toStringAsFixed(2)}'),
              selected: (current - speed).abs() < 0.001,
              onActivate: () {
                ref.read(playbackRateProvider.notifier).state = speed;
                ref.read(videoPlayerProvider).setSpeed(speed);
              },
            ))
        .toList();
  }

  List<_PanelItem> _qualityItems(BuildContext context) {
    final options =
        ref.watch(playBackModel.select((value) => value?.bitRateOptions)) ?? {};
    final visible = <MapEntry<Bitrate, bool>>[];
    final collapsed = <MapEntry<Bitrate, bool>>[];
    for (final entry in options.entries) {
      if (entry.key == Bitrate.original || entry.key == Bitrate.auto) {
        visible.add(entry);
      } else {
        collapsed.add(entry);
      }
    }
    final items = visible
        .map((entry) => _PanelItem(
              content: Text(entry.key.label(context)),
              selected: entry.value,
              onActivate: () => _selectQuality(options, entry.key),
            ))
        .toList();
    if (collapsed.isNotEmpty) {
      items.add(_PanelItem(
        content: Row(
          children: [
            Expanded(
                child: Text('Débit limité',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary))),
            Icon(
              _qualityExpanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
        selected: false,
        onActivate: () => setState(() => _qualityExpanded = !_qualityExpanded),
      ));
      if (_qualityExpanded) {
        items.addAll(collapsed.map((entry) => _PanelItem(
              content: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.md),
                child: Text(entry.key.label(context)),
              ),
              selected: entry.value,
              onActivate: () => _selectQuality(options, entry.key),
            )));
      }
    }
    return items;
  }

  List<_PanelItem> _itemsFor(BuildContext context, VideoPanelSection section) =>
      switch (section) {
        VideoPanelSection.audio => _audioItems(context),
        VideoPanelSection.subtitles => _subtitleItems(context),
        VideoPanelSection.image => _imageItems(context),
        VideoPanelSection.speed => _speedItems(context),
        VideoPanelSection.quality => _qualityItems(context),
      };

  KeyEventResult _onKey(
      FocusNode node, KeyEvent event, List<_PanelItem> items) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isShiftTab = event.logicalKey == LogicalKeyboardKey.tab &&
        HardwareKeyboard.instance.isShiftPressed;
    if (isShiftTab) {
      _cycleSection(-1);
      return KeyEventResult.handled;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.tab:
        _cycleSection(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        if (items.isNotEmpty) {
          setState(
              () => _itemIndex = (_itemIndex + 1).clamp(0, items.length - 1));
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        if (items.isNotEmpty) {
          setState(
              () => _itemIndex = (_itemIndex - 1).clamp(0, items.length - 1));
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        if (items.isNotEmpty) {
          items[_itemIndex.clamp(0, items.length - 1)].onActivate?.call();
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        widget.onClose();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _itemsFor(context, _section);
    if (_itemIndex >= items.length) {
      _itemIndex = items.isEmpty ? 0 : items.length - 1;
    }

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) => _onKey(node, event, items),
      child: Container(
        width: videoSidePanelWidth,
        color: AppColors.surface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.sm, AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Réglages',
                          style: Theme.of(context).textTheme.headlineSmall),
                    ),
                    Tooltip(
                      message: 'Fermer (Échap)',
                      child: IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              // Tab passe d'une section à l'autre — pas la traversée par
              // défaut de Flutter (qui irait aussi dans les lignes de la
              // liste) : ExcludeFocus ici, le clavier passe entièrement
              // par le `Focus` racine ci-dessus.
              ExcludeFocus(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    spacing: AppSpacing.md,
                    children: [
                      for (final section in VideoPanelSection.values)
                        _SectionTab(
                          label: section.label,
                          selected: section == _section,
                          onTap: () => _setSection(section),
                        ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Divider(height: 1),
              ),
              Expanded(
                child: ExcludeFocus(
                  child: items.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: Text('Rien à régler ici.',
                              style: TextStyle(color: AppColors.textSecondary)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs),
                          itemCount: items.length,
                          itemBuilder: (context, index) => _PanelRow(
                            item: items[index],
                            focused: index == _itemIndex,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SectionTab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.textPrimary : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.textPrimary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelRow extends StatelessWidget {
  final _PanelItem item;
  final bool focused;
  const _PanelRow({required this.item, required this.focused});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: focused ? AppColors.surfaceHover : Colors.transparent,
      child: InkWell(
        onTap: item.onActivate,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          child: Row(
            children: [
              Expanded(child: item.content),
              if (item.selected) ...[
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.check_rounded,
                    size: 18, color: AppColors.textPrimary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final String value;
  const _SettingRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textPrimary)),
        ),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}
