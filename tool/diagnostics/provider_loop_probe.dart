// Diagnostic entrypoint: records provider lifecycles without observing or changing them.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/main.dart' as app;
import 'package:kinos/bootstrap/app_bootstrap.dart';
import 'package:kinos/providers/arguments_provider.dart';
import 'package:kinos/providers/crash_log_provider.dart';
import 'package:kinos/providers/shared_provider.dart';
import 'package:kinos/providers/sync_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/providers/dashboard_provider.dart';
import 'package:kinos/providers/views_provider.dart';
import 'package:kinos/providers/dashboard/home_row_random_seed_provider.dart';
import 'package:kinos/letterboxd/letterboxd_providers.dart';
import 'package:kinos/recommendations/providers/home_catalog_providers.dart';
import 'package:kinos/recommendations/providers/recommendation_providers.dart';
import 'package:kinos/recommendations/seerr/discovery_registry.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/application_info.dart';

class LoopObserver extends ProviderObserver {
  final clock = Stopwatch()..start();
  final labels = <ProviderBase, String>{
    homeSeedRowsResultProvider: 'seedRows',
    homeCatalogInventoryResultProvider: 'inventory',
    playedItemsProvider: 'played',
    resumableItemsProvider: 'resumable',
    unwatchedLibraryProvider: 'unwatched',
    unwatchedLibraryFirstPageProvider: 'firstPage',
    recommendationResultProvider: 'recommendations',
    recommendationRegistrySeedProvider: 'registrySeed',
    recommendationRecomputeNeededProvider: 'freshness',
    letterboxdSnapshotProvider: 'letterboxd',
    letterboxdScopeProvider: 'accountScope',
    dashboardProvider: 'dashboard',
    viewsProvider: 'views',
    userProvider: 'account',
    homeRowRandomSeedProvider: 'sessionSeed',
  };
  void record(ProviderBase provider, String event, Object? value) {
    final label = labels[provider] ??
        (provider.from == discoveryRegistryProvider
            ? 'discoveryRegistry'
            : null);
    if (label == null) return;
    // Types only: never log profile data, titles, URLs or credentials.
    stdout.writeln(
        '[provider ${clock.elapsedMilliseconds}] $label $event ${value.runtimeType}');
  }

  @override
  void didAddProvider(
          ProviderBase provider, Object? value, ProviderContainer container) =>
      record(provider, 'add', value);
  @override
  void didUpdateProvider(ProviderBase provider, Object? previousValue,
          Object? newValue, ProviderContainer container) =>
      record(provider, 'update', newValue);
  @override
  void didDisposeProvider(ProviderBase provider, ProviderContainer container) =>
      record(provider, 'dispose', null);
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = await bootstrapApplication(args);
  runApp(ProviderScope(observers: [
    LoopObserver()
  ], overrides: [
    sharedPreferencesProvider
        .overrideWith((ref) => bootstrap.sharedPreferences),
    applicationInfoProvider.overrideWith((ref) => bootstrap.applicationInfo),
    crashLogProvider.overrideWith((ref) => bootstrap.crashProvider),
    argumentsStateProvider.overrideWith((ref) => bootstrap.argumentsModel),
    syncProvider.overrideWith(
        (ref) => SyncNotifier(ref, bootstrap.applicationDirectory)),
  ], child: AdaptiveLayoutBuilder(child: (context) => const app.Main())));
}
