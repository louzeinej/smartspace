/// Service utilitaire pour la détection et l'extraction de liens web dans les publications.
class LinkPreviewService {
  LinkPreviewService._();

  static final RegExp _urlRegExp = RegExp(
    r'https?://[^\s<>"{}|\\^`]+',
    caseSensitive: false,
  );

  /// Extrait la première URL présente dans le texte (titre + contenu)
  static String? extractFirstUrl(String text) {
    final match = _urlRegExp.firstMatch(text);
    return match?.group(0);
  }

  /// Extrait le nom de domaine propre (host) d'une URL
  static String extractDomain(String urlString) {
    try {
      final uri = Uri.parse(urlString);
      final host = uri.host.toLowerCase();
      if (host.startsWith('www.')) {
        return host.substring(4);
      }
      return host.isNotEmpty ? host : urlString;
    } catch (_) {
      return urlString;
    }
  }
}
