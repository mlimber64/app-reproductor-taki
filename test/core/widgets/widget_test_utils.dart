import 'package:flutter/material.dart';
import 'package:taki/core/domain/entities/artwork_reference.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/local_song.dart';

/// Canción de prueba (los tests de core no dependen de helpers de features).
LocalSong testSong({
  int id = 1,
  String title = 'Matador',
  String? artist = 'Los Fabulosos Cadillacs',
  String? album = 'Vasos vacíos',
  int durationMs = 185000,
}) {
  return LocalSong(
    id: id,
    title: title,
    artist: artist,
    album: album,
    albumId: 10,
    artwork: localArtworkReference(10),
    durationMs: durationMs,
    path: '/music/$id.mp3',
    contentUri: 'content://media/external/audio/media/$id',
  );
}

/// Monta [child] en una pantalla de [width] (412 = móvil típico).
Future<void> pumpInScreen(
  WidgetTester tester,
  Widget child, {
  double width = 412,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width * 3, 915 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 915),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: ListView(children: [child])),
      ),
    ),
  );
}
