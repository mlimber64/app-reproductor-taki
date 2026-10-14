import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/provider_attribution.dart';
import '../../../../core/domain/entities/song.dart';
import '../../../../core/domain/services/external_url.dart';
import '../../../../core/links/external_link_providers.dart';
import '../../../../core/theme/taki_colors.dart';
import '../../../../core/theme/taki_spacing.dart';
import '../../../../core/theme/taki_typography.dart';
import '../../../../core/widgets/taki_button.dart';
import '../providers/attribution_providers.dart';

/// Origen y licencia de la canción que suena (Reproduciendo, secundario).
///
/// Es provider-agnostic: pide la atribución por `MusicIdentity` y pinta lo que
/// llega. No ocupa nada mientras carga, si no hay atribución (ausente) ni si la
/// consulta falla: la reproducción no depende de ella y no se enseña un error.
/// Solo muestra los enlaces que existen y son `http(s)`.
class AttributionSection extends ConsumerWidget {
  const AttributionSection({super.key, required this.song});

  final Song song;

  static const String originLabel = 'Origen';
  static const String licenseLabel = 'Licencia';
  static const String viewSong = 'Ver canción';
  static const String viewLicense = 'Ver licencia';
  static const String linkFailed = 'No se pudo abrir el enlace';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attribution =
        ref.watch(attributionProvider(song.musicIdentity)).valueOrNull;
    // Defensa: nunca se pinta la atribución de otra canción.
    if (attribution == null || attribution.identity != song.musicIdentity) {
      return const SizedBox.shrink();
    }
    return _Content(song: song, attribution: attribution);
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.song, required this.attribution});

  final Song song;
  final ProviderAttribution attribution;

  Future<void> _open(BuildContext context, WidgetRef ref, Uri url) async {
    final opened = await ref.read(externalLinkOpenerProvider).open(url);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(AttributionSection.linkFailed)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageUrl = openableUrl(attribution.pageUrl);
    final licenseUrl = openableUrl(attribution.licenseUrl);
    final licenseName = attribution.licenseName?.trim();
    final provider = attribution.providerName;
    final style =
        TakiTypography.caption.copyWith(color: TakiColors.textSecondary);

    return Semantics(
      container: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${AttributionSection.originLabel} · $provider',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
          if (licenseName != null && licenseName.isNotEmpty)
            Text(
              '${AttributionSection.licenseLabel} · $licenseName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          if (pageUrl != null || licenseUrl != null)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: TakiSpacing.sm,
              children: [
                if (pageUrl != null)
                  TakiButton(
                    label: AttributionSection.viewSong,
                    icon: Icons.open_in_new_rounded,
                    variant: TakiButtonVariant.tertiary,
                    semanticLabel: 'Ver «${song.title}» en $provider',
                    onPressed: () => _open(context, ref, pageUrl),
                  ),
                if (licenseUrl != null)
                  TakiButton(
                    label: AttributionSection.viewLicense,
                    icon: Icons.open_in_new_rounded,
                    variant: TakiButtonVariant.tertiary,
                    semanticLabel: 'Ver la licencia de «${song.title}»',
                    onPressed: () => _open(context, ref, licenseUrl),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
