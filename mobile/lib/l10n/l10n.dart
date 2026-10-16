import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

final _english = lookupAppLocalizations(const Locale('en'));

/// `context.l10n.cartTitle` - the app's text in the chosen language.
/// Falls back to English where the app's localizations are not set up (tests, previews).
extension L10nContext on BuildContext {
  AppLocalizations get l10n => Localizations.of<AppLocalizations>(this, AppLocalizations) ?? _english;
}
