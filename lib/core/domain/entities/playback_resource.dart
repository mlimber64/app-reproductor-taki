/// Cómo puede reproducirse una canción, una vez resuelta su identidad.
///
/// Responde «¿cómo se reproduce?», no «¿qué canción es?» (eso es
/// `MusicIdentity`) ni «¿dónde está su portada?» (eso es el artwork). Lo
/// produce un `PlaybackResolver` y lo convierte a una tecnología concreta el
/// adaptador del reproductor; el dominio solo describe la intención.
///
/// Es una jerarquía **sellada** de cuatro casos (no es «una URL»):
/// - [LocalUriResource]: una URI del propio dispositivo.
/// - [RemoteUriResource]: una URI de red que un reproductor de URI puede abrir.
/// - [ProviderPlaybackResource]: no hay URI; lo reproduce un motor propio de la
///   fuente (p. ej. un SDK). El dominio no sabe cuál.
/// - [UnavailableResource]: la canción existe pero no tiene un recurso
///   reproducible disponible.
///
/// Las URI se guardan como [String] opacas (sin `Uri` ni tipos de Flutter); el
/// adaptador las interpreta. HLS/DASH no necesitan un tipo propio: si hay una
/// URI que el reproductor puede abrir, es una [RemoteUriResource] y el formato
/// lo decide el adaptador.
///
/// Dart puro, inmutable, con igualdad por valor. No contiene `AudioSource`,
/// `MediaItem`, objetos de SDK ni nombres de proveedores.
sealed class PlaybackResource {
  const PlaybackResource();
}

/// URI del propio dispositivo (hoy, un `content://` de MediaStore).
final class LocalUriResource extends PlaybackResource {
  LocalUriResource(this.uri) {
    _requireNotBlank(uri, 'uri');
  }

  /// URI tal como la entrega la fuente local; opaca.
  final String uri;

  @override
  bool operator ==(Object other) =>
      other is LocalUriResource && other.uri == uri;

  @override
  int get hashCode => Object.hash(LocalUriResource, uri);

  @override
  String toString() => 'LocalUriResource($uri)';
}

/// URI de red que un reproductor de URI puede abrir.
///
/// Se distingue de [LocalUriResource] porque tiene otra semántica: puede
/// caducar ([expiresAt]) y puede fallar por motivos de red. Remote sources produce it.
final class RemoteUriResource extends PlaybackResource {
  RemoteUriResource(this.uri, {this.expiresAt}) {
    _requireNotBlank(uri, 'uri');
  }

  /// URI de red; opaca.
  final String uri;

  /// Momento a partir del cual la URI deja de valer, si la fuente lo indica.
  /// `null` = la fuente no informa de caducidad (no significa «no caduca»).
  final DateTime? expiresAt;

  @override
  bool operator ==(Object other) =>
      other is RemoteUriResource &&
      other.uri == uri &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(RemoteUriResource, uri, expiresAt);

  @override
  String toString() => 'RemoteUriResource($uri, expiresAt: $expiresAt)';
}

/// La reproducción la hace un motor propio de la fuente, no un reproductor de
/// URI.
///
/// Información mínima: [engine] (etiqueta opaca del motor que debe
/// reproducirlo; el dominio solo la compara) y, si el motor la necesita,
/// [reference] (dato opaco con el que iniciar la reproducción). La identidad de
/// la canción ya la conoce quien pidió la resolución.
final class ProviderPlaybackResource extends PlaybackResource {
  ProviderPlaybackResource(this.engine, {this.reference}) {
    _requireNotBlank(engine, 'engine');
    final reference = this.reference;
    if (reference != null) _requireNotBlank(reference, 'reference');
  }

  /// Etiqueta opaca del motor de reproducción.
  final String engine;

  /// Dato opaco para el motor, o `null` si no hace falta.
  final String? reference;

  @override
  bool operator ==(Object other) =>
      other is ProviderPlaybackResource &&
      other.engine == engine &&
      other.reference == reference;

  @override
  int get hashCode => Object.hash(ProviderPlaybackResource, engine, reference);

  @override
  String toString() =>
      'ProviderPlaybackResource(engine: $engine, reference: $reference)';
}

/// La canción existe, pero no tiene un recurso reproducible disponible.
///
/// Es un resultado **definitivo de la resolución**, no un error: un fallo
/// transitorio (p. ej. de red) no debe convertirse en esto, sino lanzarse como
/// `PlaybackResolutionException` para poder reintentarse.
final class UnavailableResource extends PlaybackResource {
  const UnavailableResource({this.reason});

  /// Motivo legible para depuración; opcional y sin significado para el
  /// dominio.
  final String? reason;

  @override
  bool operator ==(Object other) =>
      other is UnavailableResource && other.reason == reason;

  @override
  int get hashCode => Object.hash(UnavailableResource, reason);

  @override
  String toString() => 'UnavailableResource(reason: $reason)';
}

void _requireNotBlank(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'no puede estar vacío');
  }
}
