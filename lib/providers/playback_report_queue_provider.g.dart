// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_report_queue_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$playbackReportQueueWorkerHash() =>
    r'024a435e985feaf29c94b9c9918d669e515bf48e';

/// Drains `playback_queue`: playback start/progress/stop reports that were
/// written to the local database before being sent, so a network failure
/// loses nothing - see [JellyService.sessionsPlayingPost] and friends.
///
/// Activated once at app startup (see [BaseAppWrapperState]) and then runs
/// for the lifetime of the app: it retries pending entries on a timer with
/// per-entry exponential backoff, and immediately whenever connectivity
/// comes back after being offline.
///
/// Copied from [PlaybackReportQueueWorker].
@ProviderFor(PlaybackReportQueueWorker)
final playbackReportQueueWorkerProvider =
    NotifierProvider<PlaybackReportQueueWorker, void>.internal(
  PlaybackReportQueueWorker.new,
  name: r'playbackReportQueueWorkerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$playbackReportQueueWorkerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$PlaybackReportQueueWorker = Notifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
