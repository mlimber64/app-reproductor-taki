import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/catalog/catalog_sources_providers.dart';
import '../../../../core/theme/taki_colors.dart';
import '../../../../core/utils/duration_format.dart';
import '../../../../core/widgets/taki_section_header.dart';
import '../../../../core/widgets/taki_settings_tile.dart';
import '../../../library/presentation/providers/songs_notifier.dart';
import '../../domain/entities/app_info.dart';
import '../../domain/entities/storage_usage.dart';
import '../../domain/usecases/settings_usecases.dart';
import '../format_bytes.dart';
import '../providers/settings_providers.dart';

/// Settings: library actions, storage, online catalogs, privacy and About.
///
/// There are no persisted preferences yet; every row is either an action or
/// read-only information.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const String title = 'Ajustes';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text(title)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: const [
          _LibrarySection(),
          _StorageSection(),
          _CatalogSection(),
          _PrivacySection(),
          _AboutSection(),
        ],
      ),
    );
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _LibrarySection extends ConsumerWidget {
  const _LibrarySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(songsProvider);
    final notifier = ref.read(songsProvider.notifier);
    final state = library.valueOrNull;
    final needsPermission = state is LibraryNeedsPermission;

    final String summary;
    VoidCallback? onSummaryTap;
    if (library.isLoading && state == null) {
      summary = 'Leyendo tu música…';
    } else if (library.hasError && state == null) {
      summary = 'No pudimos leer tu música';
      onSummaryTap = notifier.retry;
    } else {
      summary = switch (state) {
        LibraryNeedsPermission(:final permanentlyDenied) => permanentlyDenied
            ? 'Sin permiso. Toca para abrir los ajustes del sistema'
            : 'Sin permiso. Toca para permitir el acceso',
        LibraryLoaded() =>
          formatSongsSummary(state.songs.length, state.totalDuration),
        _ => 'No se encontró música en el teléfono',
      };
      if (needsPermission) onSummaryTap = notifier.requestPermission;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TakiSectionHeader(
          title: 'Biblioteca',
          variant: TakiSectionHeaderVariant.group,
          isFirst: true,
        ),
        TakiSettingsTile(
          icon: needsPermission
              ? Icons.lock_outline_rounded
              : Icons.library_music_outlined,
          title: 'Música en tu teléfono',
          subtitle: summary,
          onTap: onSummaryTap,
        ),
        TakiSettingsTile(
          icon: Icons.refresh_rounded,
          title: 'Volver a escanear',
          subtitle: 'Busca canciones nuevas o cambios en tu música',
          onTap: needsPermission || library.isLoading
              ? null
              : () async {
                  await notifier.rescan();
                  if (context.mounted) {
                    _showMessage(context, 'Biblioteca actualizada');
                  }
                },
        ),
      ],
    );
  }
}

class _StorageSection extends ConsumerWidget {
  const _StorageSection();

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Vaciar la caché de carátulas?'),
        content: const Text(
          'Se borrarán las imágenes guardadas para la notificación y la '
          'pantalla de bloqueo. Se vuelven a generar al reproducir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final freed = await ref.read(clearArtworkCacheProvider).call();
    ref.invalidate(artworkCacheUsageProvider);
    if (context.mounted) {
      _showMessage(context, 'Se liberaron ${formatBytes(freed.bytes)}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(artworkCacheUsageProvider);
    final value = usage.valueOrNull;

    final subtitle = usage.isLoading && value == null
        ? 'Calculando…'
        : value == null || value.isEmpty
            ? 'Vacía'
            : '${value.fileCount} '
                '${value.fileCount == 1 ? 'archivo' : 'archivos'} · '
                '${formatBytes(value.bytes)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TakiSectionHeader(
          title: 'Almacenamiento',
          variant: TakiSectionHeaderVariant.group,
        ),
        TakiSettingsTile(
          icon: Icons.image_outlined,
          title: 'Caché de carátulas',
          subtitle: subtitle,
        ),
        TakiSettingsTile(
          icon: Icons.delete_outline_rounded,
          title: 'Vaciar caché de carátulas',
          subtitle: 'No afecta a tus canciones, favoritos ni playlists',
          destructive: true,
          onTap: value == null || value.isEmpty
              ? null
              : () => _clear(context, ref),
        ),
      ],
    );
  }
}

class _CatalogSection extends ConsumerWidget {
  const _CatalogSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers = ref.watch(catalogSourcesProvider).available;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TakiSectionHeader(
          title: 'Catálogo en línea',
          variant: TakiSectionHeaderVariant.group,
        ),
        if (providers.isEmpty)
          const TakiSettingsTile(
            icon: Icons.cloud_off_outlined,
            title: 'Sin catálogos en línea',
            subtitle: 'Taki funciona solo con la música de tu teléfono',
          )
        else ...[
          for (final provider in providers)
            TakiSettingsTile(
              icon: Icons.cloud_outlined,
              title: provider.label,
              subtitle: 'Disponible en Buscar',
            ),
          const TakiSettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'Origen y licencia',
            subtitle: 'Cada canción en línea muestra su origen y su licencia '
                'en Reproduciendo',
          ),
        ],
      ],
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TakiSectionHeader(
          title: 'Privacidad',
          variant: TakiSectionHeaderVariant.group,
        ),
        TakiSettingsTile(
          icon: Icons.shield_outlined,
          title: 'Tus datos',
          subtitle: 'Tus favoritos y playlists se guardan solo en este '
              'teléfono. Taki no tiene cuentas ni servidor propio. La letra de una '
              'canción se consulta en LRCLIB, con su título y artista, solo '
              'cuando la abres',
        ),
      ],
    );
  }
}

class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  Future<void> _copyDiagnostics(
    BuildContext context,
    WidgetRef ref,
    AppInfo info,
  ) async {
    final library = ref.read(songsProvider).valueOrNull;
    final cache =
        ref.read(artworkCacheUsageProvider).valueOrNull ?? StorageUsage.empty;

    final report = buildDiagnosticsReport(
      info: info,
      catalogSources: [
        for (final p in ref.read(catalogSourcesProvider).available) p.label,
      ],
      libraryStatus: switch (library) {
        LibraryNeedsPermission() => 'permission needed',
        LibraryLoaded(:final songs) => '${songs.length} songs',
        LibraryEmpty() => 'empty',
        null => 'unknown',
      },
      artworkCache: cache,
      artworkCacheSize: formatBytes(cache.bytes),
    );

    await Clipboard.setData(ClipboardData(text: report));
    if (context.mounted) {
      _showMessage(context, 'Información copiada al portapapeles');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(appInfoProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TakiSectionHeader(
          title: 'Acerca de',
          variant: TakiSectionHeaderVariant.group,
        ),
        TakiSettingsTile(
          icon: Icons.music_note_rounded,
          title: 'Taki',
          subtitle: info == null
              ? 'Versión…'
              : 'Versión ${info.displayVersion}',
        ),
        TakiSettingsTile(
          icon: Icons.description_outlined,
          title: 'Licencias de código abierto',
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: TakiColors.iconSecondary,
          ),
          onTap: () => showLicensePage(
            context: context,
            applicationName: info?.name ?? 'Taki',
            applicationVersion: info?.displayVersion,
          ),
        ),
        TakiSettingsTile(
          icon: Icons.content_copy_rounded,
          title: 'Copiar información de diagnóstico',
          subtitle: 'Versión, sistema y contadores, sin datos personales',
          onTap: info == null
              ? null
              : () => _copyDiagnostics(context, ref, info),
        ),
      ],
    );
  }
}
