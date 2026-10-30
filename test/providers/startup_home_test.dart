import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/views_model.dart';
import 'package:kinos/providers/dashboard/hero_items_provider.dart';
import 'package:kinos/providers/dashboard_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/providers/views_provider.dart';
import 'package:kinos/screens/shared/startup_home.dart';

import '../widgets/seerr_discovery_section_test.dart' show TestUser;

class InitialViews extends ViewsNotifier {
  InitialViews(super.ref, this.ready);
  final Completer<void> ready;
  int calls = 0;
  @override
  Future<ViewsModel?> fetchViews() async {
    calls++;
    await ready.future;
    return state;
  }
}

class InitialDashboard extends DashboardNotifier {
  InitialDashboard(super.ref);
  int calls = 0;
  @override
  Future<void> fetchNextUpAndResume() async => calls++;
}

void main() {
  test('startup waits for home data, reuses it and isolates profiles',
      () async {
    final viewsReady = Completer<void>();
    final heroReady = Completer<List<ItemBaseModel>>();
    final container = ProviderContainer(overrides: [
      userProvider.overrideWith(TestUser.new),
      viewsProvider.overrideWith((ref) => InitialViews(ref, viewsReady)),
      dashboardProvider.overrideWith(InitialDashboard.new),
      heroItemsProvider.overrideWith((ref) => heroReady.future),
    ]);
    addTearDown(container.dispose);
    var done = false;
    final loading =
        container.read(startupHomeProvider.future).then((_) => done = true);
    await Future<void>.delayed(Duration.zero);
    expect(done, isFalse);
    viewsReady.complete();
    await Future<void>.delayed(Duration.zero);
    expect(done, isFalse);
    heroReady.complete([]);
    await loading;
    await container.read(startupHomeProvider.future);
    expect((container.read(viewsProvider.notifier) as InitialViews).calls, 1);
    expect(
        (container.read(dashboardProvider.notifier) as InitialDashboard).calls,
        1);
    (container.read(userProvider.notifier) as TestUser).change('b');
    await container.read(startupHomeProvider.future);
    expect((container.read(viewsProvider.notifier) as InitialViews).calls, 2);
  });
}
