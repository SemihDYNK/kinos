import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:uuid/uuid.dart';

import 'package:fladder/models/settings/home_row_model.dart';
import 'package:fladder/providers/database_provider.dart';

const _homeRowsSettingKey = 'home_rows';
const _homeRowsSettingScope = 'dashboard';

/// Rangées configurables de l'accueil, triées par [HomeRowModel.order].
/// Persistées dans la table `settings` (clé/valeur, lot 0) — pas de nouvelle
/// table pour un simple tableau de préférences.
final homeRowsProvider =
    StateNotifierProvider<HomeRowsNotifier, List<HomeRowModel>>((ref) {
  return HomeRowsNotifier(ref);
});

class HomeRowsNotifier extends StateNotifier<List<HomeRowModel>> {
  HomeRowsNotifier(this.ref) : super(const []) {
    _load();
  }

  final Ref ref;
  static const _uuid = Uuid();

  Future<void> _load() async {
    final db = ref.read(appDatabaseProvider);
    final setting =
        await db.getSetting(_homeRowsSettingKey, scope: _homeRowsSettingScope);
    if (setting == null) return;
    try {
      final decoded = jsonDecode(setting.value) as List;
      final rows = decoded
          .map((e) => HomeRowModel.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      state = rows;
    } catch (_) {
      // Préférence corrompue : on repart d'une liste vide plutôt que de
      // planter le tableau de bord.
    }
  }

  Future<void> _persist() async {
    final db = ref.read(appDatabaseProvider);
    await db.setSetting(
      _homeRowsSettingKey,
      jsonEncode(state.map((r) => r.toJson()).toList()),
      scope: _homeRowsSettingScope,
    );
  }

  Future<void> add({
    required HomeRowType type,
    required String title,
    Map<String, String> params = const {},
  }) async {
    final row = HomeRowModel(
      id: _uuid.v4(),
      type: type,
      title: title,
      params: params,
      order: state.length,
    );
    state = [...state, row];
    await _persist();
  }

  Future<void> remove(String id) async {
    state = state.where((r) => r.id != id).toList();
    await _persist();
  }

  Future<void> toggle(String id) async {
    state = [
      for (final r in state)
        if (r.id == id) r.copyWith(enabled: !r.enabled) else r,
    ];
    await _persist();
  }

  Future<void> rename(String id, String title) async {
    state = [
      for (final r in state)
        if (r.id == id) r.copyWith(title: title) else r,
    ];
    await _persist();
  }

  /// Glisser-déposer (souris) — `newIndex` suit la convention
  /// [ReorderableListView] (index cible *avant* retrait de l'élément).
  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = [...state];
    if (newIndex > oldIndex) newIndex -= 1;
    final row = list.removeAt(oldIndex);
    list.insert(newIndex, row);
    await _reindexAndPersist(list);
  }

  /// Équivalent clavier du glisser-déposer.
  Future<void> moveUp(String id) => _moveBy(id, -1);
  Future<void> moveDown(String id) => _moveBy(id, 1);

  Future<void> _moveBy(String id, int delta) async {
    final list = [...state];
    final index = list.indexWhere((r) => r.id == id);
    final target = index + delta;
    if (index == -1 || target < 0 || target >= list.length) return;
    final row = list.removeAt(index);
    list.insert(target, row);
    await _reindexAndPersist(list);
  }

  Future<void> _reindexAndPersist(List<HomeRowModel> list) async {
    state = [for (var i = 0; i < list.length; i++) list[i].copyWith(order: i)];
    await _persist();
  }
}
