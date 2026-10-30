import 'package:kinos/util/text_metrics.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kinos/arr/models/arr_library_entry.dart';
import 'package:kinos/arr/models/arr_library_poster.dart';
import 'package:kinos/theme/app_theme.dart';

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
  final Widget? header;
  final EdgeInsets contentPadding;
  final String baseUrl;
  final String apiKey;
  final void Function(ArrLibraryEntry entry) onOpenDetail;
  final void Function(ArrLibraryEntry entry) onSearch;
  final void Function(ArrLibraryEntry entry) onToggleMonitored;
  final void Function(ArrLibraryEntry entry) onEdit;
  final void Function(ArrLibraryEntry entry) onRemove;

  const ArrLibraryGrid({
    required this.entries,
    this.header,
    this.contentPadding = EdgeInsets.zero,
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
  static const _gap = AppSpacing.sm;
  static const _aspectRatio = AppMedia.posterAspectRatio;

  final _focusNode = FocusNode(debugLabel: 'ArrLibraryGrid');
  final _scrollController = ScrollController();
  // Ancre explicite sur le viewport de la grille — plus fiable que
  // `context.findRenderObject()` sur le State lui-même (qui dépend de la
  // forme exacte de l'arbre construit par `build`, ex. si un widget non
  // porteur de RenderObject s'intercale) pour la conversion coordonnées
  // locales -> globales utilisée par `_tileCenter`/`_ensureVisible`.
  final _gridKey = GlobalKey();
  final _headerKey = GlobalKey();

  double get _headerHeight =>
      (_headerKey.currentContext?.findRenderObject() as RenderBox?)
          ?.size
          .height ??
      0;
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

  int _crossAxisCount(double width) => context.tokens.density.columnsFor(width);

  double _tileHeight(double width) =>
      width / _aspectRatio +
      AppSpacing.xs +
      measuredLineHeight(context, AppTypography.cardTitle) +
      measuredLineHeight(context, AppTypography.meta) * 2;

  double _tileWidth(double width, int crossAxisCount) =>
      (width - _gap * (crossAxisCount - 1)) / crossAxisCount;

  KeyEventResult _move(int delta, int crossAxisCount) {
    final next = _focusedIndex + delta;
    if (next < 0 || next >= widget.entries.length) {
      return KeyEventResult.ignored;
    }
    setState(() => _focusedIndex = next);
    _ensureVisible(
        next,
        crossAxisCount,
        _tileWidth(
            (_gridBox?.size.width ?? 0) - widget.contentPadding.horizontal,
            crossAxisCount));
    return KeyEventResult.handled;
  }

  void _ensureVisible(int index, int crossAxisCount, double tileWidth) {
    if (!_scrollController.hasClients) return;
    final tileHeight = _tileHeight(tileWidth);
    final row = index ~/ crossAxisCount;
    final rowTop =
        widget.contentPadding.top + _headerHeight + row * (tileHeight + _gap);
    final rowBottom = rowTop + tileHeight;
    final viewport = _scrollController.position.viewportDimension;
    final current = _scrollController.offset;
    final overlay =
        widget.contentPadding.top.clamp(0.0, AppTopNavigation.contentInset);
    if (rowTop < current + overlay) {
      _scrollController.jumpTo((rowTop - overlay)
          .clamp(0, _scrollController.position.maxScrollExtent));
    } else if (rowBottom > current + viewport) {
      _scrollController.jumpTo((rowBottom - viewport)
          .clamp(0, _scrollController.position.maxScrollExtent));
    }
  }

  Offset _tileCenter(int index, int crossAxisCount, double tileWidth) {
    final box = _gridBox;
    if (box == null) return Offset.zero;
    final tileHeight = _tileHeight(tileWidth);
    final row = index ~/ crossAxisCount;
    final col = index % crossAxisCount;
    final local = Offset(
      widget.contentPadding.left + col * (tileWidth + _gap) + tileWidth / 2,
      widget.contentPadding.top +
          _headerHeight +
          row * (tileHeight + _gap) -
          _scrollController.offset +
          tileHeight / 2,
    );
    return box.localToGlobal(local);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event, int crossAxisCount) {
    if (event is! KeyDownEvent || !node.hasPrimaryFocus) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        return _move(-1, crossAxisCount);
      case LogicalKeyboardKey.arrowRight:
        return _move(1, crossAxisCount);
      case LogicalKeyboardKey.arrowUp:
        return _move(-crossAxisCount, crossAxisCount);
      case LogicalKeyboardKey.arrowDown:
        return _move(crossAxisCount, crossAxisCount);
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        if (widget.entries.isNotEmpty) {
          widget.onOpenDetail(widget.entries[_focusedIndex]);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.contextMenu:
        if (widget.entries.isNotEmpty) {
          final position = _tileCenter(
              _focusedIndex,
              crossAxisCount,
              _tileWidth(
                  (_gridBox?.size.width ?? 0) -
                      widget.contentPadding.horizontal,
                  crossAxisCount));
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
          final position = _tileCenter(
              _focusedIndex,
              crossAxisCount,
              _tileWidth(
                  (_gridBox?.size.width ?? 0) -
                      widget.contentPadding.horizontal,
                  crossAxisCount));
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
    showGlassMenu<void>(
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
      final width = constraints.maxWidth - widget.contentPadding.horizontal;
      final crossAxisCount = _crossAxisCount(width);
      final tileWidth = _tileWidth(width, crossAxisCount);
      return Focus(
        focusNode: _focusNode,
        autofocus: false,
        onFocusChange: (_) => setState(() {}),
        onKeyEvent: (node, event) => _onKey(node, event, crossAxisCount),
        child: CustomScrollView(
          key: _gridKey,
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: widget.contentPadding.copyWith(bottom: 0),
              sliver: SliverToBoxAdapter(
                  child: SizedBox(key: _headerKey, child: widget.header)),
            ),
            SliverPadding(
              padding: widget.contentPadding.copyWith(top: 0),
              sliver: widget.entries.isEmpty
                  ? const SliverToBoxAdapter(
                      child:
                          Text('Bibliothèque vide.', style: AppTypography.meta))
                  : SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: _gap,
                        crossAxisSpacing: _gap,
                        mainAxisExtent: _tileHeight(tileWidth),
                      ),
                      itemCount: widget.entries.length,
                      itemBuilder: (context, index) {
                        final entry = widget.entries[index];
                        return _ArrLibraryTile(
                          key: ValueKey(entry.id),
                          entry: entry,
                          focused:
                              _focusNode.hasFocus && index == _focusedIndex,
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
                            _showContextMenu(
                                context, details.globalPosition, entry);
                          },
                        );
                      },
                    ),
            ),
          ],
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

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapUp: widget.onSecondaryTapUp,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: PosterHoverMotion(
                  active: _hovered,
                  builder: (context, _) => AnimatedContainer(
                        duration: AppDurations.focusRing,
                        decoration: BoxDecoration(
                            borderRadius: AppRadii.cardBorder,
                            border: Border.all(
                                color: widget.focused
                                    ? AppColors.focus
                                    : _hovered
                                        ? AppColors.posterHoverBorder
                                        : Colors.transparent,
                                width: context.tokens.density.focusWidth)),
                        child: ClipRRect(
                            borderRadius: AppRadii.cardBorder, child: poster),
                      ))),
          const SizedBox(height: AppSpacing.xs),
          Text(entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.cardTitle),
          Text(entry.year?.toString() ?? '', style: AppTypography.meta),
          Row(children: [
            Icon(
                !entry.monitored
                    ? Icons.visibility_off_outlined
                    : entry.hasContent
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                size: AppTypography.meta.fontSize,
                color: !entry.monitored
                    ? AppColors.textSecondary
                    : entry.hasContent
                        ? AppColors.success
                        : AppColors.warning),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(
                child: Text(
                    !entry.monitored ? 'Non surveillé' : entry.statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.meta)),
          ]),
        ]),
      ),
    );
  }
}
