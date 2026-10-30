import 'package:kinos/models/items/chapters_model.dart';
import 'package:kinos/models/items/media_segments_model.dart';

/// Native segments take precedence; explicitly named chapters fill missing types.
MediaSegment? activeSkipSegment({
  required MediaSegmentsModel? serverSegments,
  required List<Chapter>? chapters,
  required Duration position,
  required Duration duration,
}) {
  final native = serverSegments?.segments ?? const <MediaSegment>[];
  for (final segment in native) {
    if (position >= segment.start && position < segment.end) return segment;
  }
  final ordered = (chapters ?? const <Chapter>[])
      .where((chapter) => chapter.startPosition >= Duration.zero)
      .toList()
    ..sort((a, b) => a.startPosition.compareTo(b.startPosition));
  final index =
      ordered.lastIndexWhere((chapter) => chapter.startPosition <= position);
  if (index < 0) return null;
  final chapter = ordered[index];
  if (index > 0 && ordered[index - 1].startPosition == chapter.startPosition) {
    return null;
  }
  final type = switch (chapter.name.trim().toLowerCase()) {
    'intro' ||
    'opening' ||
    'op' ||
    'générique de début' ||
    "générique d'ouverture" =>
      MediaSegmentType.intro,
    'outro' ||
    'ending' ||
    'ed' ||
    'credits' ||
    'credit' ||
    'crédits' ||
    'crédit' ||
    'end credits' ||
    'générique de fin' =>
      MediaSegmentType.outro,
    _ => null,
  };
  if (type == null || native.any((segment) => segment.type == type)) {
    return null;
  }
  var end =
      index + 1 < ordered.length ? ordered[index + 1].startPosition : duration;
  if (duration > Duration.zero && end > duration) end = duration;
  if (end <= chapter.startPosition || position >= end) return null;
  return MediaSegment(type: type, start: chapter.startPosition, end: end);
}
