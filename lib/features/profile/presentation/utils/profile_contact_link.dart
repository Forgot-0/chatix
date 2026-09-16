import 'package:flutter/material.dart';

import 'package:chatix/features/profile/domain/entities/contact_entity.dart';

/// What tapping a row in a profile's contact list should do.
///
/// `ProfileLinkDTO` is two free strings — `provider` and `contact` — and the
/// server validates neither (api-docs §4.6), so whether a row is a handle,
/// a full URL, an address or a phone number is something the client works
/// out by looking. Nothing here guesses beyond what the text supports: a row
/// that yields no [uri] is still shown, and still copies.
class ProfileContactLink {
  const ProfileContactLink({
    required this.icon,
    required this.label,
    required this.value,
    required this.uri,
  });

  final IconData icon;

  /// The provider, tidied for reading: `telegram` becomes `Telegram`.
  final String label;

  /// What to show as the row's own text — the handle or address itself.
  final String value;

  /// Where tapping goes, or null when the text is not something that can be
  /// opened. Rows like that offer a copy instead of a dead tap.
  final Uri? uri;

  bool get isOpenable => uri != null;
}

/// Reads one profile link into something the UI can act on.
ProfileContactLink profileContactLinkOf(ContactEntity contact) {
  final provider = contact.provider.trim().toLowerCase();
  final value = contact.contact.trim();

  return ProfileContactLink(
    icon: _iconFor(provider, value),
    label: _labelFor(contact.provider),
    value: value,
    uri: contactUriOf(provider, value),
  );
}

/// The URI a `provider`/`contact` pair points at, or null when the pair is
/// not openable as written.
///
/// Order matters: an entry that already spells out a URL is trusted as one
/// whatever its provider says, because that is the form people actually
/// paste. Only then does the provider get to decide how a bare handle is
/// expanded.
Uri? contactUriOf(String provider, String rawValue) {
  final value = rawValue.trim();
  if (value.isEmpty) return null;

  final explicit = _explicitUri(value);
  if (explicit != null) return explicit;

  final handle = value.replaceFirst(RegExp(r'^@+'), '');
  if (handle.isEmpty) return null;

  switch (provider) {
    case 'telegram':
    case 'tg':
      return Uri.parse('https://t.me/$handle');
    case 'github':
      return Uri.parse('https://github.com/$handle');
    case 'gitlab':
      return Uri.parse('https://gitlab.com/$handle');
    case 'x':
    case 'twitter':
      return Uri.parse('https://x.com/$handle');
    case 'instagram':
      return Uri.parse('https://instagram.com/$handle');
    case 'linkedin':
      return Uri.parse('https://linkedin.com/in/$handle');
    case 'vk':
      return Uri.parse('https://vk.com/$handle');
    case 'facebook':
      return Uri.parse('https://facebook.com/$handle');
    case 'youtube':
      return Uri.parse('https://youtube.com/@$handle');
    case 'discord':
      // Discord handles are not addressable by URL; nothing to open.
      return null;
    case 'email':
    case 'mail':
    case 'e-mail':
      return _isEmail(handle) ? Uri(scheme: 'mailto', path: handle) : null;
    case 'phone':
    case 'tel':
    case 'mobile':
    case 'whatsapp':
      final digits = _phoneDigits(value);
      if (digits == null) return null;
      return provider == 'whatsapp'
          ? Uri.parse('https://wa.me/${digits.replaceFirst('+', '')}')
          : Uri(scheme: 'tel', path: digits);
    case 'site':
    case 'website':
    case 'web':
    case 'homepage':
    case 'url':
      return Uri.tryParse('https://$handle');
  }

  // An unknown provider is still worth trying: an address is an address and
  // a phone number is a phone number, whatever the row is called.
  if (_isEmail(handle)) return Uri(scheme: 'mailto', path: handle);

  final digits = _phoneDigits(value);
  if (digits != null) return Uri(scheme: 'tel', path: digits);

  if (_looksLikeDomain(handle)) return Uri.tryParse('https://$handle');

  return null;
}

Uri? _explicitUri(String value) {
  final lower = value.toLowerCase();
  if (!lower.startsWith('http://') &&
      !lower.startsWith('https://') &&
      !lower.startsWith('mailto:') &&
      !lower.startsWith('tel:')) {
    return null;
  }

  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  if (uri.scheme == 'mailto' || uri.scheme == 'tel') return uri;
  return uri.hasAuthority ? uri : null;
}

bool _isEmail(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

/// The dialable form of [value], or null when it is not a phone number.
///
/// Anything with a letter in it is not one, which is what keeps a username
/// made of digits from turning into a phone call.
String? _phoneDigits(String value) {
  if (!RegExp(r'^\+?[\d\s().-]{5,}$').hasMatch(value)) return null;

  final digits = value.replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.replaceAll('+', '').length < 5) return null;
  return digits;
}

bool _looksLikeDomain(String value) =>
    RegExp(r'^[\w-]+(\.[\w-]+)+(/.*)?$').hasMatch(value);

IconData _iconFor(String provider, String value) {
  switch (provider) {
    case 'telegram':
    case 'tg':
      return Icons.send_outlined;
    case 'email':
    case 'mail':
    case 'e-mail':
      return Icons.alternate_email;
    case 'phone':
    case 'tel':
    case 'mobile':
      return Icons.phone_outlined;
    case 'whatsapp':
      return Icons.chat_outlined;
    case 'github':
    case 'gitlab':
      return Icons.code;
    case 'site':
    case 'website':
    case 'web':
    case 'homepage':
    case 'url':
      return Icons.public;
    case 'discord':
      return Icons.forum_outlined;
  }

  if (_isEmail(value.replaceFirst(RegExp(r'^@+'), ''))) {
    return Icons.alternate_email;
  }
  if (_phoneDigits(value) != null) return Icons.phone_outlined;
  return Icons.link;
}

/// `telegram` → `Telegram`, `my site` → `My site`. Left alone when the
/// author already capitalised it themselves.
String _labelFor(String provider) {
  final trimmed = provider.trim();
  if (trimmed.isEmpty) return trimmed;
  if (trimmed != trimmed.toLowerCase()) return trimmed;
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}
