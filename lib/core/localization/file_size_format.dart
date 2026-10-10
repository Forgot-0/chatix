import 'package:intl/intl.dart';

import 'package:chatix/gen/l10n/app_localizations.dart';

/// A byte count the way a reader of [locale] writes it: "2.0 MB", "2,0 МБ".
///
/// The units come from the translations and the digits from `intl`, so a
/// Russian reader gets both "МБ" and a decimal comma. Binary multiples,
/// like every file manager: a 2 097 152-byte file is "2.0 MB" there and
/// here. Kilobytes are whole, because a tenth of one is nothing anyone
/// waits for; megabytes and up carry one decimal.
String formatFileSize(
  int bytes,
  AppLocalizations l10n, {
  required String locale,
}) {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;

  final tag = NumberFormat.localeExists(locale) ? locale : 'en';
  String whole(num value) => NumberFormat('0', tag).format(value);
  String tenths(num value) => NumberFormat('0.0', tag).format(value);

  if (bytes < kb) return l10n.sizeBytes(whole(bytes < 0 ? 0 : bytes));

  // Each unit hands over to the next where its own rounding would print
  // the next one in disguise — "1024 KB", "1024.0 MB".
  final kilobytes = bytes / kb;
  if (kilobytes.round() < kb) return l10n.sizeKilobytes(whole(kilobytes));

  final megabytes = bytes / mb;
  if ((megabytes * 10).round() < kb * 10) {
    return l10n.sizeMegabytes(tenths(megabytes));
  }

  return l10n.sizeGigabytes(tenths(bytes / gb));
}
