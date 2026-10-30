import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/models/seerr/seerr_dashboard_model.dart';
import 'package:kinos/screens/seerr/seerr_screen.dart';
import 'package:kinos/seerr/seerr_models.dart';

void main() {
  SeerrDashboardPosterModel poster(SeerrMediaStatus media,
          [SeerrRequestStatus? request]) =>
      SeerrDashboardPosterModel(
        id: 'request',
        type: SeerrMediaType.movie,
        tmdbId: 1,
        title: 'Film',
        overview: '',
        images: ImagesData(),
        mediaStatus: media,
        requestStatus: request,
        jellyfinItemId: null,
      );
  test('availability takes precedence over an older pending request', () {
    expect(
        requestViewOf(
            poster(SeerrMediaStatus.available, SeerrRequestStatus.pending)),
        RequestView.available);
    expect(
        requestViewOf(
            poster(SeerrMediaStatus.unknown, SeerrRequestStatus.completed)),
        RequestView.available);
  });
  test('pending, partial and approved requests retain their own groups', () {
    expect(
        requestViewOf(poster(SeerrMediaStatus.pending)), RequestView.pending);
    expect(requestViewOf(poster(SeerrMediaStatus.partiallyAvailable)),
        RequestView.processing);
    expect(
        requestViewOf(
            poster(SeerrMediaStatus.unknown, SeerrRequestStatus.approved)),
        RequestView.processing);
  });
  test('failed and declined requests remain visible in all requests', () {
    for (final status in [
      SeerrRequestStatus.failed,
      SeerrRequestStatus.declined
    ]) {
      expect(requestViewOf(poster(SeerrMediaStatus.unknown, status)),
          RequestView.all);
    }
  });
}
