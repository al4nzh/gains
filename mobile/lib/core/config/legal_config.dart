/// Legal / support URLs for App Store compliance.
///
/// Override at build time:
/// `--dart-define=PRIVACY_POLICY_URL=https://...`
class LegalConfig {
  LegalConfig._();

  static const String privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://gainsai.net/privacy',
  );

  static const String termsUrl = String.fromEnvironment(
    'TERMS_URL',
    defaultValue: 'https://gainsai.net/terms',
  );

  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'stixietv@gmail.com',
  );

  static const String supportUrl = String.fromEnvironment(
    'SUPPORT_URL',
    defaultValue: 'https://gainsai.net/support',
  );

  static bool get hasSupportEmail => supportEmail.trim().isNotEmpty;
  static bool get hasSupportUrl => supportUrl.trim().isNotEmpty;

  static bool get hasPrivacyUrl => privacyPolicyUrl.trim().isNotEmpty;
  static bool get hasTermsUrl => termsUrl.trim().isNotEmpty;
}
