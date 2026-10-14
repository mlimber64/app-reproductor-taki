import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taki/core/database/sqflite_preferences_store.dart';
import 'package:taki/core/database/taki_database.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/core/domain/entities/song_lookup_result.dart';
import 'package:taki/core/domain/ports/song_lookup.dart';
import 'package:taki/features/library/domain/usecases/recent_songs_usecases.dart';
import 'package:taki/features/library/infrastructure/sqflite_play_history_repository.dart';

import '../../helpers/universal_song.dart';

class _Lookup implements SongLookup {
  _Lookup(this.known);

  final Set<MusicIdentity> known;
  int calls = 0;

  @override
  Future<SongLookupResult> findAll(Iterable<MusicIdentity> identities) async {
    calls++;
    final wanted = identities.toSet();
    return SongLookupResult(
      found: {
        for (final identity in wanted)
          if (known.contains(identity)) identity: buildUniversalSong(identity),
      },
      missing: wanted.difference(known),
    );
  }
}

void main() {
  sqfliteFfiInit();

  late Database db;
  late DateTime now;
  late SqflitePlayHistoryRepository history;

  MusicIdentity id(String external, [String source = 'local']) =>
      MusicIdentity(source, external);

  setUp(() async {
    db = await TakiDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    now = DateTime(2026, 1, 1, 12);
    history = SqflitePlayHistoryRepository(
      () async => db,
      clock: () => now,
      maxEntries: 3,
    );
  });

  tearDown(() async {
    await history.dispose();
    await db.close();
  });

  Future<void> play(MusicIdentity identity) async {
    now = now.add(const Duration(minutes: 1));
    await history.record(identity);
  }

  group('PlayHistoryRepository', () {
    test('starts empty', () async {
      expect(await history.recent(), isEmpty);
    });

    test('lists the most recent first, one entry per song', () async {
      await play(id('1'));
      await play(id('2'));
      await play(id('1'));

      expect(await history.recent(), [id('1'), id('2')]);
    });

    test('counts repeated plays', () async {
      await play(id('1'));
      await play(id('1'));
      await play(id('1'));

      final rows = await db.query(TakiDatabase.playHistoryTable);
      expect(rows.single['play_count'], 3);
    });

    test('keeps sources apart', () async {
      await play(id('7', 'local'));
      await play(id('7', 'jamendo'));

      expect(await history.recent(), [id('7', 'jamendo'), id('7', 'local')]);
    });

    test('respects the limit', () async {
      await play(id('1'));
      await play(id('2'));
      await play(id('3'));

      expect(await history.recent(limit: 2), [id('3'), id('2')]);
    });

    test('keeps only the newest entries', () async {
      for (final n in ['1', '2', '3', '4']) {
        await play(id(n));
      }

      expect(await history.recent(limit: 10), [id('4'), id('3'), id('2')]);
    });

    test('watchRecent emits now and after each play', () async {
      final seen = <List<MusicIdentity>>[];
      final subscription = history.watchRecent().listen(seen.add);
      addTearDown(subscription.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await play(id('1'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(seen.first, isEmpty);
      expect(seen.last, [id('1')]);
    });

    test('clear forgets everything', () async {
      await play(id('1'));

      await history.clear();

      expect(await history.recent(), isEmpty);
    });
  });

  group('GetRecentSongs', () {
    test('keeps the order and drops what cannot be resolved', () async {
      final lookup = _Lookup({id('1'), id('3')});

      final songs = await GetRecentSongs(lookup)
          .call([id('3'), id('2'), id('1')]);

      expect(songs.map((Song s) => s.musicIdentity), [id('3'), id('1')]);
    });

    test('nothing recent does not ask the lookup', () async {
      final lookup = _Lookup({});

      expect(await GetRecentSongs(lookup).call(const []), isEmpty);
      expect(lookup.calls, 0);
    });
  });

  group('SqflitePreferencesStore', () {
    test('reads what was written and replaces it', () async {
      final store = SqflitePreferencesStore(() async => db);

      expect(await store.read('k'), isNull);
      await store.write('k', 'one');
      expect(await store.read('k'), 'one');
      await store.write('k', 'two');
      expect(await store.read('k'), 'two');
    });
  });
}
