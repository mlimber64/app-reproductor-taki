import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/provider_attribution.dart';
import '../../../../core/domain/entities/song.dart';

/// Un resultado de búsqueda: la [song] universal y, si la fuente la entregó,
/// la [attribution] del proveedor.
///
/// La atribución viaja **junto a** la canción, no dentro: `Song` no cambia. Es
/// `null` cuando la fuente no la dio (la UI debe degradar con gracia). Solo en
/// memoria. La identidad para favoritos y playlists es
/// `song.musicIdentity`.
final class CatalogResultItem extends Equatable {
  const CatalogResultItem(this.song, {this.attribution});

  final Song song;
  final ProviderAttribution? attribution;

  @override
  List<Object?> get props => [song, attribution];
}

/// Una página de resultados ya traducida a [CatalogResultItem].
final class CatalogResultPage {
  const CatalogResultPage({required this.items, required this.hasMore});

  final List<CatalogResultItem> items;
  final bool hasMore;
}
