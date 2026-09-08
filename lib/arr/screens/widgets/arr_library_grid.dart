import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fladder/arr/models/arr_library_entry.dart';
import 'package:fladder/arr/models/arr_library_poster.dart';
import 'package:fladder/theme/app_theme.dart';

/// Grille de jaquettes de la bibliothèque — virtualisée (`GridView
/// .builder`, la bibliothèque peut faire plusieurs milliers d'entrées) :
/// à cette échelle, un `FocusNode` réel par jaquette n'est pas
/// envisageable (il faudrait matérialiser tous les enfants pour les
/// enregistrer dans l'arbre de focus, ce qui annulerait la
/// virtualisation elle-même). Un seul `Focus` couvre toute la grille, un
/// index "focus logique" tenu en état local pilote le déplacement aux
/// flèches et le rendu de l'anneau visible sur la jaquette concernée —
/// même garantie perçue par le clavier (focus toujours visible, jamais
/// perdu), sans les nœuds de focus individuels.
class ArrLibraryGrid extends StatefulWidget {
  final List<ArrLibraryEntry> entries;
  final String baseUrl;
  final String apiKey;
  final void Function(ArrLibraryEntry entry) onOpenDetail;
  final void Function(ArrLibraryEntry entry) onSearch;
  final void Function(ArrLibraryEntry entry) onToggleMonitored;
  final void Function(ArrLibraryEntry entry) onEdit;
  final void Function(ArrLibraryEntry entry) onRemove;

  const ArrLibraryGrid({
    required this.entries,
    required this.baseUrl,
    required this.apiKey,
    required this.onOpenDetail,
    required this.onSearch,
    required this.onToggleMonitored,
    required this.onEdit,
    required this.onRemove,
    super.key,
  });

  @override
  State<ArrLibraryGrid> createState() => _ArrLibraryGridState();
}

class _ArrLibraryGridState extends State<ArrLibraryGrid> {
  static const _targetTileWidth = 180.0;
  static const _gap = AppSpacing.sm;
  static const _aspectRatio = 2 / 3;

  final _focusNode = FocusNode(debugLabel: 'ArrLibraryGrid');
  final _scrollController = ScrollController();
  // Ancre explicite sur le viewport de la grille — plus fiable que
  // `context.findRenderObject()` sur le State lui-même (qui dépend de la
  // forme exacte de l'arbre construit par `build`, ex. si un widget non
  // porteur de RenderObject s'intercale) pour la conversion coordonnées
  // locales -> globales utilisée par `_tileCenter`/`_ensureVisible`.
  final _gridKey = GlobalKey();
  int _focusedIndex = 0;

  RenderBox? get _gridBox =>
      _gridKey.currentContext?.findRenderObject() as RenderBox?;

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ArrLibraryGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusedIndex >= widget.entries.length) {
      _focusedIndex = widget.entries.isEmpty ? 0 : widget.entries.length - 1;
    }
  }

  int _crossAxisCount(double width) =>
      (width / (_targetTileWidth + _gap)).round().clamp(6, 8);

  double _tileWidth(double width, int crossAxisCount) =>
      (width - _gap * (crossAxisCount - 1)) / crossAxisCount;

  void _move(int delta, int crossAxisCount) {
    if (widget.entries.isEmpty) return;
    final next = (_focusedIndex + delta).clamp(0, widget.entries.length - 1);
    setState(() => _focusedIndex = next);
    _ensureVisible(next, crossAxisCount,
        _tileWidth(_gridBox?.size.width ?? 0, crossAxisCount));
  }

  void _ensureVisible(int index, int crossAxisCount, double tileWidth) {
    if (!_scrollController.hasClients) return;
    final tileHeight = tileWidth / _aspectRatio;
    final row = index ~/ crossAxisCount;
    final rowTop = row * (tileHeight + _gap);
    final rowBottom = rowTop + tileHeight;
    final viewport = _scrollController.position.viewportDimension;
    final current = _scrollController.offset;
    if (rowTop < current) {
      _scrollController.jumpTo(rowTop);
    } else if (rowBottom > current + viewport) {
      _scrollController.jumpTo((rowBottom - viewport)
          .clamp(0, _scrollController.position.maxScrollExtent));
    }
  }

  Offset _tileCenter(int index, int crossAxisCount, double tileWidth) {
    final box = _gridBox;
    if (box == null) return Offset.zero;
    final tileHeight = tileWidth / _aspectRatio;
    final row = index ~/ crossAxisCount;
    final col = index % crossAxisCount;
    final local = Offset(
      col * (tileWidth + _gap) + tileWidth / 2,
      row * (tileHeight + _gap) - _scrollController.offset + tileHeight / 2,
    );
    return box.localToGlobal(local);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event, int crossAxisCount) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _move(-1, crossAxisCount);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _move(1, crossAxisCount);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _move(-crossAxisCount, crossAxisCount);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _move(crossAxisCount, crossAxisCount);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        if (widget.entries.isNotEmpty) {
          widget.onOpenDetail(widget.entries[_focusedIndex]);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.contextMenu:
        if (widget.entries.isNotEmpty) {
          final position = _tileCenter(_focusedIndex, crossAxisCount,
              _tileWidth(_gridBox?.size.width ?? 0, crossAxisCount));
          _showContextMenu(context, position, widget.entries[_focusedIndex]);
        }
        return KeyEventResult.handled;
      default:
        // Repli clavier « standard » : Maj+F10 ouvre aussi le menu
        // contextuel, pour les claviers/dispositions sans touche Menu
        // dédiée.
        if (event.logicalKey == LogicalKeyboardKey.f10 &&
            HardwareKeyboard.instance.isShiftPressed &&
            widget.entries.isNotEmpty) {
          final position = _tileCenter(_focusedIndex, crossAxisCount,
              _tileWidth(_gridBox?.size.width ?? 0, crossAxisCount));
          _showContextMenu(context, position, widget.entries[_focusedIndex]);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
    }
  }

  void _showContextMenu(
      BuildContext context, Offset globalPosition, ArrLibraryEntry entry) {
    final position = RelativeRect.fromLTRB(globalPosition.dx, globalPosition.dy,
        globalPosition.dx, globalPosition.dy);
    showMenu<void>(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          onTap: () => widget.onSearch(entry),
          child:
              const _MenuLabel(icon: Icons.search_rounded, label: 'Rechercher'),
        ),
        PopupMenuItem(
          onTap: () => widget.onToggleMonitored(entry),
          child: _MenuLabel(
            icon: entry.monitored
                ? Icons.bookmark_remove_outlined
                : Icons.bookmark_add_outlined,
            label: entry.monitored ? 'Ne plus surveiller' : 'Surveiller',
          ),
        ),
        PopupMenuItem(
          onTap: () => widget.onEdit(entry),
          child: const _MenuLabel(icon: Icons.edit_outlined, label: 'Modifier'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: () => widget.onRemove(entry),
          child: const _MenuLabel(
              icon: Icons.delete_outline_rounded, label: 'Supprimer'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = _crossAxisCount(constraints.maxWidth);
      final tileWidth = _tileWidth(constraints.maxWidth, crossAxisCount);
      return Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) => _onKey(node, event, crossAxisCount),
        child: widget.entries.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Text('Bibliothèque vide.',
                    style: TextStyle(color: AppColors.textSecondary)),
              )
            : GridView.builder(
                key: _gridKey,
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: _gap,
                  crossAxisSpacing: _gap,
                  childAspectRatio: _aspectRatio,
                ),
                itemCount: widget.entries.length,
                itemBuilder: (context, index) {
                  final entry = widget.entries[index];
                  return _ArrLibraryTile(
                    key: ValueKey(entry.id),
                    entry: entry,
                    focused: index == _focusedIndex,
                    tileWidth: tileWidth,
                    cacheWidth: (tileWidth * dpr).round(),
                    baseUrl: widget.baseUrl,
                    apiKey: widget.apiKey,
                    onTap: () {
                      setState(() => _focusedIndex = index);
                      _focusNode.requestFocus();
                      widget.onOpenDetail(entry);
                    },
                    onSecondaryTapUp: (details) {
                      setState(() => _focusedIndex = index);
                      _focusNode.requestFocus();
                      _showContextMenu(context, details.globalPosition, entry);
                    },
                  );
                },
              ),
      );
    });
  }
}

class _MenuLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Text(label),
      ],
    );
  }
}

class _ArrLibraryTile extends StatefulWidget {
  final ArrLibraryEntry entry;
  final bool focused;
  final double tileWidth;
  final int cacheWidth;
  final String baseUrl;
  final String apiKey;
  final VoidCallback onTap;
  final void Function(TapUpDetails details) onSecondaryTapUp;

  const _ArrLibraryTile({
    required this.entry,
    required this.focused,
    required this.tileWidth,
    required this.cacheWidth,
    required this.baseUrl,
    required this.apiKey,
    required this.onTap,
    required this.onSecondaryTapUp,
    super.key,
  });

  @override
  State<_ArrLibraryTile> createState() => _ArrLibraryTileState();
}

class _ArrLibraryTileState extends State<_ArrLibraryTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    // Non surveillé ou fichier absent : désaturation + opacité réduite —
    // jamais de pastille ni de bandeau de couleur (cf. CLAUDE.md, aucune
    // couleur d'accent décorative dans cette grille).
    final dimmed = !entry.monitored || !entry.hasContent;
    final posterUrl = arrNativePosterUrl(entry.id, baseUrl: widget.baseUrl);

    Widget poster = Image.network(
      posterUrl,
      headers: {'X-Api-Key': widget.apiKey},
      cacheWidth: widget.cacheWidth,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const ColoredBox(
        color: AppColors.surface,
        child: Center(
          child: Icon(Icons.movie_creation_outlined,
              color: AppColors.textDisabled, size: 32),
        ),
      ),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const ColoredBox(color: AppColors.surface),
    );

    if (dimmed) {
      poster = Opacity(
        opacity: 0.55,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126,
            0.7152,
            0.0722,
            0,
            0,
            0.2126,
            0.7152,
            0.0722,
            0,
            0,
            0.2126,
            0.7152,
            0.0722,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ]),
          child: poster,
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapUp: widget.onSecondaryTapUp,
        child: AnimatedContainer(
          duration: AppDurations.focusRing,
          decoration: BoxDecoration(
            borderRadius: AppRadii.cardBorder,
            border: Border.all(
              color: widget.focused ? AppColors.focus : Colors.transparent,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: AppRadii.cardBorder,
            child: Stack(
              fit: StackFit.expand,
              children: [
                poster,
                if (_hovered) _HoverOverlay(entry: entry),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Métadonnées au survol seulement, dans un voile dégradé sur le bas de
/// la jaquette — règle « texte sur image » du CLAUDE.md : textPrimary
/// pour le principal, textPrimary à 75% pour le secondaire, jamais
/// textSecondary (pas de garantie de contraste sur une image).
class _HoverOverlay extends StatelessWidget {
  final ArrLibraryEntry entry;
  const _HoverOverlay({required this.entry});

  @override
  Widget build(BuildContext context) {
    final year = entry.year;
    final subtitleParts = [
      if (entry.qualityName != null) entry.qualityName!,
      entry.statusLabel,
    ];
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs, AppSpacing.lg, AppSpacing.xs, AppSpacing.xs),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              AppColors.scrim.withValues(alpha: 0.85),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              year == null ? entry.title : '${entry.title} ($year)',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            if (subtitleParts.isNotEmpty)
              Text(
                subtitleParts.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary.withValues(alpha: 0.75)),
              ),
          ],
        ),
      ),
    );
  }
}
