import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/letterboxd/letterboxd_parser.dart';

Uint8List exportZip(Map<String, String> files) {
  final archive = Archive();
  files.forEach((name, text) {
    final bytes = utf8.encode(text);
    archive.add(ArchiveFile(name, bytes.length, bytes));
  });
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  test('official exports ignore deleted and orphaned history directories', () {
    final entries = parseLetterboxdExport(exportZip({
      'watched.csv':
          'Date,Name,Year,Letterboxd URI\n2026-01-01,A,2000,https://boxd.it/a\n',
      'diary.csv':
          'Date,Name,Year,Letterboxd URI,Rating,Rewatch,Tags,Watched Date\n2026-01-02,A,2000,https://boxd.it/log,5,,tag,2026-01-01\n',
      'deleted/diary.csv':
          'Date,Name,Year,Letterboxd URI,Rating,Rewatch,Tags,Watched Date\n',
      'orphaned/diary.csv':
          'Date,Name,Year,Letterboxd URI,Rating,Rewatch,Tags,Watched Date\n2026-01-02,Removed,1999,,1,,,2026-01-01\n',
    }));
    expect(entries.length, 1);
    expect(entries.single.title, 'A');
    expect(entries.single.rating, 5);
    expect(entries.single.watches, 1);
  });
  test('short film and diary links merge by unambiguous title and year', () {
    final entries = parseLetterboxdExport(exportZip({
      'watched.csv':
          'Date,Name,Year,Letterboxd URI\n2026-01-01,A,2000,https://boxd.it/aBc\n',
      'diary.csv':
          'Date,Name,Year,Letterboxd URI,Rating,Rewatch,Watched Date\n2026-02-01,A,2000,https://boxd.it/diary1,4,Yes,2026-01-30\n',
    }));
    expect(entries.length, 1);
    expect(entries.single.uri, 'https://boxd.it/aBc');
    expect(entries.single.watches, 2);
    expect(entries.single.watchedAt, DateTime(2026, 1, 30));
  });
  test('removed films with an empty URI remain importable', () {
    expect(
        parseLetterboxdExport(exportZip({
          'watched.csv': 'Date,Name,Year,Letterboxd URI\n2026-01-01,A,2000,\n'
        })).single.title,
        'A');
  });
  test(
      'merges watched, rating and diary without using activity dates as viewing dates',
      () {
    final entries = parseLetterboxdExport(exportZip({
      'watched.csv':
          '\uFEFFDate,Name,Year,Letterboxd URI\r\n2026-01-01,"Film, ""A""",2001,https://letterboxd.com/film/a/\r\n',
      'ratings.csv':
          'Date,Name,Year,Letterboxd URI,Rating\n2026-02-01,"Film, ""A""",2001,https://letterboxd.com/film/a/,4.5\n',
      'diary.csv':
          'Date,Name,Year,Letterboxd URI,Rating,Rewatch,Watched Date\n2026-01-01,"Film, ""A""",2001,https://letterboxd.com/film/a/,,No,2025-01-01\n2026-01-02,"Film, ""A""",2001,https://letterboxd.com/film/a/,,Yes,2025-02-01\n',
      'watchlist.csv': 'bad data ignored',
    }));
    expect(entries.length, 1);
    final e = entries.single;
    expect(e.title, 'Film, "A"');
    expect(e.rating, 4.5);
    expect(e.watches, 2);
    expect(e.watchedAt, DateTime(2025, 2, 1));
  });
  test('supports quoted newlines and a ratings-only export', () {
    final e = parseLetterboxdExport(exportZip({
      'ratings.csv':
          'Date,Name,Year,Letterboxd URI,Rating\n2026-01-01,"A\nB",1999,https://letterboxd.com/film/a-b/,0.5\n'
    })).single;
    expect(e.title, 'A\nB');
    expect(e.watchedAt, isNull);
    expect(e.rating, 0.5);
  });
  test('latest explicit rating wins independently of diary ratings', () {
    final e = parseLetterboxdExport(exportZip({
      'ratings.csv':
          'Date,Name,Year,Letterboxd URI,Rating\n2025-01-01,A,2000,https://letterboxd.com/film/a/,5\n2026-01-01,A,2000,https://letterboxd.com/film/a/,1\n',
      'diary.csv':
          'Date,Name,Year,Letterboxd URI,Rating,Rewatch,Watched Date\n2026-02-01,A,2000,https://letterboxd.com/film/a/,4,No,2026-02-01\n'
    })).single;
    expect(e.rating, 1);
  });
  test('never treats watched activity date as watch date', () {
    final e = parseLetterboxdExport(exportZip({
      'watched.csv':
          'Date,Name,Year,Letterboxd URI\n2026-01-01,A,2000,https://letterboxd.com/film/a/\n'
    })).single;
    expect(e.watchedAt, isNull);
    expect(e.watches, 1);
  });
  for (final csv in [
    'Name,Year\nA,2000\n',
    'Date,Name,Year,Letterboxd URI,Rating\n2026-01-01,A,2000,https://evil.test/film/a/,4\n',
    'Date,Name,Year,Letterboxd URI,Rating\n2026-01-01,A,2000,https://letterboxd.com/film/a/,4.2\n',
    'Date,Name,Year,Letterboxd URI,Rating\n2026-01-01,"A,2000,https://letterboxd.com/film/a/,4\n',
  ]) {
    test(
        'rejects invalid CSV $csv',
        () => expect(
            () => parseLetterboxdExport(exportZip({'ratings.csv': csv})),
            throwsFormatException));
  }
  test('rejects missing history and duplicated CSV names', () {
    expect(() => parseLetterboxdExport(exportZip({'watchlist.csv': 'ignored'})),
        throwsFormatException);
    expect(
        () => parseLetterboxdExport(
            exportZip({'a/watched.csv': 'x', 'b/watched.csv': 'y'})),
        throwsFormatException);
  });
  test('rejects corrupt archives and bounded input', () {
    expect(() => parseLetterboxdExport(Uint8List.fromList([1, 2, 3])),
        throwsFormatException);
    expect(
        () => parseLetterboxdExport(Uint8List(letterboxdMaxArchiveBytes + 1)),
        throwsFormatException);
  });
}
