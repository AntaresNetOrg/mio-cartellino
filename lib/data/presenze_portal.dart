/// presenze.unisa.it constants and URL builders.
///
/// Mirrors `get.py` (`ottieni_cartellino`) of the desktop app.
library;

abstract final class PresenzePortal {
  static final home = Uri.parse('https://presenze.unisa.it/');

  /// Whether [url] is a portal page only reachable after a successful SSO login.
  /// With a mobile user agent `default.aspx` immediately redirects to the separate
  /// mobile site under `/static/mobile/`, so it never finishes loading itself.
  static bool isLoggedInUrl(String url) =>
      url.contains('presenze.unisa.it/default.aspx') ||
      url.contains('presenze.unisa.it/static/mobile/');

  /// Set after login so the portal serves the desktop page with table `#1011`
  /// instead of redirecting to the mobile site. Login itself must keep the mobile
  /// user agent, so that identity providers approve on the phone (no QR code).
  static const desktopUserAgent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15';

  /// JavaScript channel name used by `assets/js/extract_cartellino.js`.
  static const jsChannel = 'CartellinoChannel';

  /// Full-year cartellino page (table `#1011`). The employee comes from the
  /// session: unlike desktop `get.py`, no `iddip` is passed.
  static Uri cartellinoUrl(int year) {
    final start = DateTime(year, 1, 1).millisecondsSinceEpoch;
    final end = DateTime(year, 12, 31).millisecondsSinceEpoch;
    return Uri.parse('https://presenze.unisa.it/default.aspx?page=cartellino'
        '#dtfine=$end&dtinizio=$start&view=full');
  }
}
