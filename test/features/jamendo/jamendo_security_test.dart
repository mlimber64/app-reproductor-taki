import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taki/core/database/taki_database.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/features/jamendo/domain/entities/jamendo_exception.dart';
import 'package:taki/features/jamendo/domain/services/jamendo_song_mapper.dart';
import 'package:taki/features/jamendo/infrastructure/http_jamendo_api.dart';
import 'package:taki/features/jamendo/infrastructure/jamendo_credentials.dart';
import 'package:taki/features/jamendo/infrastructure/jamendo_response_parser.dart';
import 'package:taki/features/playlists/infrastructure/sqflite_playlists_repository.dart';

import '../../helpers/jamendo_fakes.dart';

List<File> dartFiles(String dir) => [
      for (final f in Directory(dir).listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart')) f,
    ];

String read(File f) => f.readAsStringSync();

String body(String headers, [String results = '[]']) =>
    '{"headers":$headers,"results":$results}';

void main() {
  final nextWithId =
      'https://api.jamendo.com/v3.0/tracks?client_id=$fakeClientId&offset=2';

  group('`next` (puede traer el client_id)', () {
    test('éxito con next: el resultado no lo contiene en ningún campo', () {
      final parsed = parseJamendoTracks(
        body('{"status":"success","code":0,"next":"$nextWithId"}',
            '[{"id":"1","name":"x","audio":"https://a/1"}]'),
        clientId: fakeClientId,
      );
      final dump = parsed.tracks
          .map((t) => '${t.id}|${t.name}|${t.artistName}|${t.albumName}|'
              '${t.albumImage}|${t.audio}|${t.shareUrl}|${t.licenseUrl}')
          .join();
      expect(dump, isNot(contains(fakeClientId)));
      expect(dump, isNot(contains('client_id')));
    });

    test('error con next: ninguna excepción lo contiene', () {
      for (final headers in [
        '{"status":"failed","code":3,"error_message":"m","next":"$nextWithId"}',
        '{"status":"failed","code":5,"next":"$nextWithId"}',
        '{"status":"failed","code":7,"error_message":"$nextWithId"}',
        '{"status":"failed","code":7,"error_message":"ver '
            'http://api.jamendo.com/x?client_id=$fakeClientId ok"}',
        '{"status":"failed","code":7,"error_message":"VER '
            'HTTP://API.JAMENDO.COM/X?CLIENT_ID=OTRO"}',
      ]) {
        try {
          parseJamendoTracks(body(headers), clientId: fakeClientId);
          fail('debía lanzar');
        } on JamendoException catch (e) {
          expect('$e ${e.message}', isNot(contains(fakeClientId)));
          expect('$e', isNot(contains('client_id=')));
          expect('$e'.toLowerCase(), isNot(contains('http')));
        }
      }
    });

    test('la paginación usa offset: la siguiente request se reconstruye sin '
        'next y sin guardar URL', () async {
      final http = FakeHttp(
        body: '{"headers":{"status":"success","code":0,'
            '"next":"$nextWithId"},"results":'
            '[{"id":"1","name":"a"},{"id":"2","name":"b"}]}',
      );
      final api = HttpJamendoApi(
        http,
        const StaticJamendoCredentials(fakeClientId),
        emptyRetries: 0,
      );
      final page = await api.searchTracks(name: 'a', limit: 2, offset: 0);
      expect(page.hasMore, isTrue);
      await api.searchTracks(name: 'a', limit: 2, offset: 2);
      expect(http.requests[1].queryParameters['offset'], '2');
      expect(http.requests[1].toString(), isNot(contains('offset=2&offset')));
    });

    test('ningún código de Jamendo lee ni referencia `next`', () {
      final files = [
        ...dartFiles('lib/features/jamendo'),
        File('lib/app/jamendo_wiring.dart'),
      ];
      for (final f in files) {
        final code = read(f)
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        expect(code, isNot(contains("'next'")), reason: f.path);
        expect(code, isNot(contains('"next"')), reason: f.path);
        expect(code, isNot(contains('.next')), reason: f.path);
      }
    });

    test('la capa Jamendo no loguea nada', () {
      final files = [
        ...dartFiles('lib/features/jamendo'),
        File('lib/app/jamendo_wiring.dart'),
      ];
      for (final f in files) {
        final code = read(f);
        for (final banned in ['print(', 'debugPrint', 'log(', 'stdout', 'stderr']) {
          expect(code, isNot(contains(banned)), reason: '${f.path}: $banned');
        }
      }
    });
  });

  group('fixtures', () {
    final files = Directory('test/fixtures/jamendo')
        .listSync()
        .whereType<File>()
        .toList();

    test('inventario: exactamente los 4 fixtures documentados', () {
      expect(
        files.map((f) => f.uri.pathSegments.last).toSet(),
        {
          'tracks_search.json',
          'empty_results.json',
          'error_invalid_client.json',
          'error_bad_param.json',
        },
      );
    });

    test('ninguno contiene credenciales, tokens ni `next` con URL', () {
      for (final f in files) {
        // Se decodifica para ver el texto real (sin escapes \uXXXX).
        final text = jsonEncode(jsonDecode(read(f)));
        final name = f.path;
        expect(text, isNot(contains('client_id')), reason: name);
        expect(text.toLowerCase(), isNot(contains('client_secret')), reason: name);
        expect(text.toLowerCase(), isNot(contains('secret')), reason: name);
        expect(text, isNot(contains('"next":  "http')), reason: name);
        expect(text, isNot(contains('"next":"http')), reason: name);
        // El único token permitido es el marcador.
        for (final m in RegExp(r'from=([^"&\\]*)').allMatches(text)) {
          expect(m.group(1), anyOf('<TOKEN>', '%3CTOKEN%3E'), reason: name);
        }
        // Nada que parezca un id hexadecimal de 8 como valor de credencial.
        expect(RegExp(r'client[_-]?id', caseSensitive: false).hasMatch(text),
            isFalse, reason: name);
        expect(text.codeUnitAt(0), isNot(0xFEFF), reason: '$name tiene BOM');
      }
    });

    test('todos los fixtures los usa algún test', () {
      final tests = dartFiles('test').map(read).join('\n');
      for (final f in files) {
        final base = f.uri.pathSegments.last;
        expect(tests, contains("'$base'"), reason: base);
      }
    });
  });

  group('caché de audio y persistencia', () {
    test('la capa Jamendo no toca disco ni SQLite', () {
      for (final f in [
        ...dartFiles('lib/features/jamendo'),
        File('lib/app/jamendo_wiring.dart'),
      ]) {
        final code = read(f);
        for (final banned in [
          'dart:io',
          'sqflite',
          'path_provider',
          'shared_preferences',
          'File(',
          'Directory(',
          'writeAsBytes',
          'writeAsString',
          'hive',
        ]) {
          expect(code, isNot(contains(banned)), reason: '${f.path}: $banned');
        }
      }
    });

    test('la persistencia no depende de Jamendo', () {
      final persistence = [
        ...dartFiles('lib/core/database'),
        ...dartFiles('lib/features/library/infrastructure'),
        ...dartFiles('lib/features/playlists/infrastructure'),
        ...dartFiles('lib/features/library/domain'),
        ...dartFiles('lib/features/playlists/domain'),
      ];
      for (final f in persistence) {
        expect(read(f).toLowerCase(), isNot(contains('jamendo')),
            reason: f.path);
      }
    });

    test('Song y MusicIdentity no conocen Jamendo ni audio/client_id', () {
      for (final path in [
        'lib/core/domain/entities/song.dart',
        'lib/core/domain/entities/music_identity.dart',
      ]) {
        final code = read(File(path)).toLowerCase();
        expect(code, isNot(contains('jamendo')), reason: path);
        expect(code, isNot(contains('client_id')), reason: path);
      }
    });

    test('el core no conoce Jamendo', () {
      for (final f in dartFiles('lib/core')) {
        expect(read(f).toLowerCase(), isNot(contains('jamendo')),
            reason: f.path);
      }
    });

    test('un solo cliente HTTP: el de artwork; Jamendo no abre sockets', () {
      for (final f in dartFiles('lib/features/jamendo')) {
        final code = read(f);
        expect(code, isNot(contains('HttpClient(')), reason: f.path);
        expect(code, isNot(contains('package:http')), reason: f.path);
      }
      final httpClients = [
        for (final f in dartFiles('lib'))
          if (RegExp(r'(?<![A-Za-z])HttpClient\(').hasMatch(read(f))) f.path,
      ];
      expect(httpClients, hasLength(1));
      expect(httpClients.single, endsWith('io_artwork_http_client.dart'));
    });
  });

  group('identidades Jamendo en playlists (SQLite sin cambios)', () {
    setUpAll(sqfliteFfiInit);

    test('una playlist guarda y devuelve MusicIdentity("jamendo", id)', () async {
      final db = await TakiDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final repo = SqflitePlaylistsRepository(() async => db);
      final id = await repo.create('Remotas');
      await repo.addSongs(id, [
        songFromJamendoTrack(buildTrack('0042')),
        songFromJamendoTrack(buildTrack('7')),
      ]);

      final entries = await repo.getEntries(id);
      expect(entries.map((e) => e.musicIdentity), [
        MusicIdentity('jamendo', '0042'),
        MusicIdentity('jamendo', '7'),
      ]);
      final dump = (await db.query('playlist_songs'))
          .map((r) => r.values.join('|'))
          .join();
      expect(dump, isNot(contains('audio.example')));
      expect(dump, isNot(contains('creativecommons')));
      await repo.dispose();
      await db.close();
    });
  });

  group('artwork', () {
    test('width obligatorio y acotado: nunca 1000, nunca sin width', () {
      for (final bad in [0, 24, 601, 1000, -1]) {
        expect(
          () => jamendoArtworkReference('https://usercontent.jamendo.com?id=1', width: bad),
          throwsArgumentError,
          reason: '$bad',
        );
      }
      for (final ok in [25, 300, 600]) {
        expect(
          () => jamendoArtworkReference('https://usercontent.jamendo.com?id=1', width: ok),
          returnsNormally,
        );
      }
      expect(jamendoArtworkMinWidth, 25);
      expect(jamendoArtworkMaxWidth, 600);
    });

    test('toda referencia generada lleva width entre 25 y 600', () {
      for (final url in [
        'https://usercontent.jamendo.com?type=album&id=1',
        'https://usercontent.jamendo.com?type=album&id=1&width=1000',
        'https://usercontent.jamendo.com?width=5',
      ]) {
        final ref = jamendoArtworkReference(url);
        final w = int.parse(Uri.parse((ref as dynamic).url as String)
            .queryParameters['width']!);
        expect(w, inInclusiveRange(25, 600));
      }
    });
  });
}
