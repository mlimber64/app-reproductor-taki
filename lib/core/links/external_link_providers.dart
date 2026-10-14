import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/ports/external_link_opener.dart';
import '../domain/services/external_url.dart';

/// Abre enlaces externos con `url_launcher` (navegador del sistema).
class UrlLauncherLinkOpener implements ExternalLinkOpener {
  const UrlLauncherLinkOpener();

  @override
  Future<bool> open(Uri url) async {
    final target = openableUrl(url);
    if (target == null) return false;
    try {
      return await launchUrl(target, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

final externalLinkOpenerProvider = Provider<ExternalLinkOpener>(
  (ref) => const UrlLauncherLinkOpener(),
);
