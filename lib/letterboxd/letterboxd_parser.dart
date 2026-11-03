import 'dart:convert';
import 'dart:io' show ZLibDecoder;
import 'dart:typed_data';
import 'package:archive/archive.dart' as archive;
import 'letterboxd_model.dart';

const letterboxdMaxArchiveBytes = 64 * 1024 * 1024;
const _maxCsvBytes = 32 * 1024 * 1024;

class _BoundedBytes implements Sink<List<int>> {
  final int limit;
  final bytes = BytesBuilder(copy: false);
  _BoundedBytes(this.limit);
  @override
  void add(List<int> data) {
    if (bytes.length + data.length > limit) {
      throw const FormatException('CSV too large');
    }
    bytes.add(data);
  }

  @override
  void close() {}
}

List<LetterboxdFilm> parseLetterboxdExport(Uint8List bytes) {
  try {
    return _parse(bytes);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('Invalid Letterboxd export');
  }
}

List<LetterboxdFilm> _parse(Uint8List bytes) {
  if (bytes.length > letterboxdMaxArchiveBytes || bytes.length < 22) {
    throw const FormatException('ZIP size');
  }
  // Inspect the directory before archive objects are allocated; no ZIP64 export is needed at this size.
  final view = ByteData.sublistView(bytes);
  int? end;
  for (var i = bytes.length - 22;
      i >= (bytes.length - 65557).clamp(0, bytes.length);
      i--) {
    if (view.getUint32(i, Endian.little) == 0x06054b50) {
      end = i;
      break;
    }
  }
  if (end == null ||
      view.getUint16(end + 8, Endian.little) > 20000 ||
      view.getUint16(end + 10, Endian.little) > 20000 ||
      view.getUint16(end + 4, Endian.little) != 0 ||
      view.getUint32(end + 12, Endian.little) > 8 * 1024 * 1024) {
    throw const FormatException('ZIP directory');
  }
  final directory = archive.ZipDirectory()
    ..read(archive.InputMemoryStream(bytes));
  final files = <String, String>{};
  var total = 0;
  for (final header in directory.fileHeaders) {
    // Official exports keep active history at the root; nested files are deleted/orphaned records.
    final name = header.filename.replaceAll('\\', '/').toLowerCase();
    if (!['watched.csv', 'ratings.csv', 'diary.csv'].contains(name)) continue;
    if (files.containsKey(name) ||
        (header.generalPurposeBitFlag & 1) != 0 ||
        ![0, 8].contains(header.compressionMethod) ||
        header.uncompressedSize > _maxCsvBytes ||
        header.uncompressedSize < 0 ||
        (total += header.uncompressedSize) > letterboxdMaxArchiveBytes) {
      throw const FormatException('ZIP entry');
    }
    final output = _BoundedBytes(header.uncompressedSize);
    final raw = header.file!.getRawContent();
    if (header.compressionMethod == 8) {
      final decoder = ZLibDecoder(raw: true).startChunkedConversion(output);
      for (var i = 0; i < raw.length; i += 16384) {
        decoder.add(raw.sublist(i, (i + 16384).clamp(0, raw.length)));
      }
      decoder.close();
    } else {
      output.add(raw);
    }
    final data = output.bytes.takeBytes();
    if (data.length != header.uncompressedSize ||
        archive.getCrc32(data) != header.crc32) {
      throw const FormatException('ZIP checksum');
    }
    files[name] = utf8.decode(data);
  }
  if (files.isEmpty) throw const FormatException('No watched films');
  final films = <String, _Film>{};
  final byTitle = <(String, int?), List<_Film>>{};
  for (final name in ['watched.csv', 'ratings.csv', 'diary.csv']) {
    final csv = files[name];
    if (csv == null) continue;
    final rows = _csv(csv);
    if (rows.isEmpty) throw const FormatException('Missing header');
    final headers = rows.first.map((v) => v.trim()).toList();
    if (headers.toSet().length != headers.length ||
        ![
          'Name',
          'Year',
          'Letterboxd URI',
          if (name == 'ratings.csv') 'Rating',
          if (name == 'diary.csv') 'Watched Date'
        ].every(headers.contains)) {
      throw const FormatException('Columns');
    }
    for (final row in rows.skip(1)) {
      if (row.every((v) => v.trim().isEmpty)) continue;
      if (row.length != headers.length) throw const FormatException('Columns');
      final map = Map<String, String>.fromIterables(headers, row);
      final title = map['Name']!.trim();
      final rawYear = map['Year']!.trim();
      final year = rawYear.isEmpty ? null : int.tryParse(rawYear);
      if (title.isEmpty ||
          title.length > 2000 ||
          (rawYear.isNotEmpty &&
              (year == null || year < 1850 || year > 2200))) {
        throw const FormatException('Film');
      }
      final uri = map['Letterboxd URI']!.trim().isEmpty
          ? 'urn:kinos:letterboxd:${base64Url.encode(utf8.encode('$title|$year'))}'
          : letterboxdFilmUri(map['Letterboxd URI']!);
      final sameTitle = byTitle[(title, year)] ?? const <_Film>[];
      final identity = films.containsKey(uri)
          ? uri
          : sameTitle.length == 1 && name != 'watched.csv'
              ? sameTitle.single.uri
              : uri;
      final existing = films[identity];
      if (existing != null && existing.year != year) {
        throw const FormatException('Conflicting film');
      }
      final film = films.putIfAbsent(identity, () {
        final created = _Film(uri, title, year);
        byTitle.putIfAbsent((title, year), () => []).add(created);
        return created;
      });
      if (films.length > 20000) throw const FormatException('Too many films');
      final date = _date(map['Date']);
      final ratingRaw = map['Rating']?.trim() ?? '';
      final rating = ratingRaw.isEmpty ? null : double.tryParse(ratingRaw);
      if (ratingRaw.isNotEmpty &&
          (rating == null ||
              !rating.isFinite ||
              rating < .5 ||
              rating > 5 ||
              rating * 2 != (rating * 2).roundToDouble())) {
        throw const FormatException('Rating');
      }
      if (rating != null &&
          (name == 'ratings.csv' || !film.explicitRating) &&
          (name == 'ratings.csv' && !film.explicitRating ||
              film.ratedAt == null ||
              date == null ||
              !date.isBefore(film.ratedAt!))) {
        film.rating = rating;
        film.ratedAt = date;
        film.explicitRating = name == 'ratings.csv';
      }
      if (name == 'diary.csv') {
        final watched = _date(map['Watched Date']);
        if (watched != null &&
            (film.watchedAt == null || watched.isAfter(film.watchedAt!))) {
          film.watchedAt = watched;
        }
        film.diaryEntries++;
        if (map['Rewatch']?.toLowerCase() == 'yes') film.rewatch = true;
      }
    }
  }
  if (films.isEmpty) throw const FormatException('No watched films');
  return [
    for (final f in films.values)
      LetterboxdFilm(
          uri: f.uri,
          title: f.title,
          year: f.year,
          rating: f.rating,
          ratedAt: f.ratedAt,
          watchedAt: f.watchedAt,
          watches: f.diaryEntries > 1
              ? f.diaryEntries
              : f.rewatch
                  ? 2
                  : 1)
  ];
}

class _Film {
  final String uri, title;
  final int? year;
  double? rating;
  DateTime? ratedAt, watchedAt;
  int diaryEntries = 0;
  bool explicitRating = false, rewatch = false;
  _Film(this.uri, this.title, this.year);
}

DateTime? _date(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final value = raw.trim();
  final date = DateTime.tryParse(value);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
      date == null ||
      date.toIso8601String().substring(0, 10) != value) {
    throw const FormatException('Date');
  }
  return date;
}

List<List<String>> _csv(String text) {
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  final rows = <List<String>>[];
  var row = <String>[];
  var field = StringBuffer();
  var quoted = false;
  var closed = false;
  void endField() {
    row.add(field.toString());
    field = StringBuffer();
    closed = false;
  }

  void endRow() {
    endField();
    rows.add(row);
    row = [];
    if (rows.length > 200001) throw const FormatException('Too many rows');
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
          closed = true;
        }
      } else {
        field.write(c);
      }
    } else if (c == ',') {
      endField();
    } else if (c == '\r' || c == '\n') {
      endRow();
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
    } else if (c == '"' && field.isEmpty && !closed) {
      quoted = true;
    } else {
      if (closed || c == '"') throw const FormatException('CSV quoting');
      field.write(c);
    }
  }
  if (quoted) throw const FormatException('CSV quoting');
  if (field.isNotEmpty || row.isNotEmpty || closed) endRow();
  return rows;
}
