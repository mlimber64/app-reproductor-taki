import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taki/core/catalog/catalog_sources_providers.dart';
import 'package:taki/core/domain/entities/catalog_provider_info.dart';
import 'package:taki/core/domain/entities/catalog_search.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/provider_attribution.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/core/domain/ports/catalog_search.dart';
import 'package:taki/core/domain/services/source_catalog_sources.dart';
import 'package:taki/features/search/domain/entities/catalog_search_policy.dart';
import 'package:taki/features/search/domain/ports/search_scheduler.dart';
import 'package:taki/features/search/presentation/providers/catalog_search_providers.dart';

import 'universal_song.dart';

/// Fuente de catálogo neutral para pruebas (no es ningún proveedor real).
const String fakeCatalogSource = 'fake';

MusicIdentity fakeIdentity(Object id) => MusicIdentity(fakeCatalogSource, '$id');

Song fakeSong(Object id) => buildUniversalSong(fakeIdentity(id), title: 'T$id');

ProviderAttribution fakeAttribution(Object id) => ProviderAttribution(
      identity: fakeIdentity(id),
      providerName: 'Fake',
      pageUrl: Uri.parse('https://fake.example/track/$id'),
      licenseUrl: Uri.parse('https://creativecommons.org/licenses/by/4.0/'),
      licenseName: 'CC BY 4.0',
    );

/// Página con las canciones `from` … `from + count - 1`. Con [withAttribution]
/// cada canción trae su atribución; con [attributedOnly], solo esos ids.
CatalogSearchPage fakePage(
  int count, {
  int from = 1,
  bool hasMore = false,
  bool withAttribution = false,
  Set<int>? attributedOnly,
}) {
  final ids = [for (var i = 0; i < count; i++) from + i];
  return CatalogSearchPage(
    [for (final id in ids) fakeSong(id)],
    hasMore: hasMore,
    attributions: {
      for (final id in ids)
        if (attributedOnly?.contains(id) ?? withAttribution)
          fakeIdentity(id): fakeAttribution(id),
    },
  );
}

/// `CatalogSearch` guionizado: registra cada consulta y responde con
/// [handler] (que puede devolver un `Future` pendiente para fijar el orden de
/// las respuestas).
class FakeCatalogSearch implements CatalogSearch {
  FakeCatalogSearch([Future<CatalogSearchPage> Function(CatalogSearchQuery)? h])
      : handler = h ?? ((_) async => fakePage(0));

  Future<CatalogSearchPage> Function(CatalogSearchQuery query) handler;
  final List<CatalogSearchQuery> calls = [];

  @override
  Future<CatalogSearchPage> search(CatalogSearchQuery query) {
    calls.add(query);
    return handler(query);
  }
}

/// Reloj manual: nada se ejecuta hasta que el test llama a [advance].
class ManualSearchScheduler implements SearchScheduler {
  Duration _now = Duration.zero;
  final List<_Task> _tasks = [];

  /// Acciones programadas y no canceladas.
  int get pending => _tasks.where((t) => !t.cancelled).length;

  @override
  CancelScheduled schedule(Duration delay, void Function() action) {
    final task = _Task(_now + delay, action);
    _tasks.add(task);
    return () => task.cancelled = true;
  }

  void advance(Duration by) {
    _now += by;
    final due = _tasks.where((t) => !t.cancelled && t.at <= _now).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    for (final task in due) {
      task.cancelled = true;
      task.action();
    }
    _tasks.removeWhere((t) => t.cancelled);
  }
}

class _Task {
  _Task(this.at, this.action);

  final Duration at;
  final void Function() action;
  bool cancelled = false;
}

/// Contenedor con el catálogo y el reloj inyectados. Con `search == null` no
/// hay ninguna fuente registrada.
ProviderContainer catalogContainer({
  CatalogSearch? search,
  ManualSearchScheduler? scheduler,
  CatalogSearchPolicy? policy,
  List<CatalogSourceRegistration>? registrations,
  List<Override> overrides = const [],
}) {
  final container = ProviderContainer(overrides: [
    catalogSourcesProvider.overrideWithValue(SourceCatalogSources(
      registrations ??
          [
            if (search != null)
              CatalogSourceRegistration(
                CatalogProviderInfo(source: fakeCatalogSource, label: 'Fake'),
                search,
              ),
          ],
    )),
    searchSchedulerProvider.overrideWithValue(scheduler ?? ManualSearchScheduler()),
    if (policy != null) catalogSearchPolicyProvider.overrideWithValue(policy),
    ...overrides,
  ]);
  return container;
}
