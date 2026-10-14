import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the bundled font licenses (SIL OFL 1.1) to the app license page.
///
/// Call once at startup. Missing assets are ignored: the license page must
/// never fail because of them.
void registerFontLicenses({AssetBundle? bundle}) {
  final assets = bundle ?? rootBundle;
  const fonts = {
    'Sora': 'assets/fonts/Sora-OFL.txt',
    'DM Sans': 'assets/fonts/DMSans-OFL.txt',
  };

  LicenseRegistry.addLicense(() async* {
    for (final entry in fonts.entries) {
      try {
        final text = await assets.loadString(entry.value);
        yield LicenseEntryWithLineBreaks([entry.key], text);
      } catch (_) {
        // Asset not bundled: skip this font.
      }
    }
  });
}
