import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/features/jamendo/domain/services/jamendo_song_mapper.dart';
import 'package:taki/features/jamendo/infrastructure/jamendo_response_parser.dart';

String envelope(String results) =>
    '{"headers":{"status":"success","code":0,"results_count":1},"results":$results}';

void main() {
  group('entidades HTML en el parser', () {
    test('se decodifican título, artista y álbum', () {
      final parsed = parseJamendoTracks(envelope('''[{
        "id":"1","name":"Don&#039;t Cry","artist_name":"Tom &amp; Jerry",
        "album_name":"&quot;Hits&quot; &lt;3"}]'''));
      final t = parsed.tracks.single;
      expect(t.name, "Don't Cry");
      expect(t.artistName, 'Tom & Jerry');
      expect(t.albumName, '"Hits" <3');
    });

    test('no se tocan URLs, ids ni licencia', () {
      final parsed = parseJamendoTracks(envelope('''[{
        "id":"1&amp;2","name":"X",
        "album_image":"https://img.example/a?x=1&amp;y=2",
        "audio":"https://a.example/x?a=1&amp;b=2",
        "shareurl":"https://www.jamendo.com/track/1?a=&amp;b",
        "license_ccurl":"http://creativecommons.org/licenses/by/3.0/?a=&amp;b"}]'''));
      final t = parsed.tracks.single;
      expect(t.id, '1&amp;2');
      expect(t.albumImage, 'https://img.example/a?x=1&amp;y=2');
      expect(t.audio, 'https://a.example/x?a=1&amp;b=2');
      expect(t.shareUrl, 'https://www.jamendo.com/track/1?a=&amp;b');
      expect(t.licenseUrl, contains('?a=&amp;b'));
    });

    test('no hay doble decodificación', () {
      final parsed = parseJamendoTracks(envelope(
          '[{"id":"1","name":"&amp;quot;x&amp;quot;","artist_name":"&amp;amp;"}]'));
      expect(parsed.tracks.single.name, '&quot;x&quot;');
      expect(parsed.tracks.single.artistName, '&amp;');
    });

    test('un nombre que solo es &nbsp; es un nombre vacío: se omite', () {
      final parsed = parseJamendoTracks(
          envelope('[{"id":"1","name":"&nbsp;"},{"id":"2","name":"Ok"}]'));
      expect(parsed.tracks.map((t) => t.id), ['2']);
      expect(parsed.rawCount, 2);
    });

    test('artista o álbum que solo son espacios: el mapper los anula', () {
      final parsed = parseJamendoTracks(envelope(
          '[{"id":"1","name":"X","artist_name":"&nbsp;","album_name":"&#32;"}]'));
      final song = songFromJamendoTrack(parsed.tracks.single);
      expect(song.artist, isNull);
      expect(song.album, isNull);
    });

    test('entidades inválidas o desconocidas quedan como llegaron', () {
      final parsed = parseJamendoTracks(envelope(
          '[{"id":"1","name":"A&foo;B &#0; &amp","artist_name":"AT&T"}]'));
      expect(parsed.tracks.single.name, 'A&foo;B &#0; &amp');
      expect(parsed.tracks.single.artistName, 'AT&T');
    });

    test('texto sin entidades y campos vacíos no cambian', () {
      final parsed = parseJamendoTracks(envelope(
          '[{"id":"1","name":"Plain"},{"id":"2","name":"Y","artist_name":""}]'));
      expect(parsed.tracks.first.name, 'Plain');
      expect(parsed.tracks.first.artistName, isNull);
      expect(parsed.tracks.last.artistName, isNull);
    });

    test('el Song resultante muestra el texto correcto', () {
      final parsed = parseJamendoTracks(envelope(
          '[{"id":"7","name":"Don&#039;t Cry","artist_name":"Tom &amp; Jerry","album_name":"A &amp; B"}]'));
      final song = songFromJamendoTrack(parsed.tracks.single);
      expect(song.title, "Don't Cry");
      expect(song.artist, 'Tom & Jerry');
      expect(song.album, 'A & B');
      expect(song.musicIdentity, MusicIdentity('jamendo', '7'));
    });
  });
}
