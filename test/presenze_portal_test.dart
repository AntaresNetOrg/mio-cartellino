import 'package:cartellino_unisa_mobile/data/presenze_portal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isLoggedInUrl', () {
    test('accepts the desktop page and the mobile redirect target', () {
      expect(PresenzePortal.isLoggedInUrl('https://presenze.unisa.it/default.aspx'), isTrue);
      expect(
        PresenzePortal.isLoggedInUrl('https://presenze.unisa.it/static/mobile/pages/home.html'),
        isTrue,
      );
    });

    test('rejects the portal root and identity provider pages', () {
      expect(PresenzePortal.isLoggedInUrl('https://presenze.unisa.it/'), isFalse);
      expect(
        PresenzePortal.isLoggedInUrl('https://auth.unisa.it/idp/profile/SAML2/Redirect/SSO'),
        isFalse,
      );
    });
  });
}
