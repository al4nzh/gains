import 'package:flutter/material.dart';
import 'package:gains/core/config/legal_config.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens support email, or falls back to the support web page.
Future<void> openSupportContact(BuildContext context) async {
  final email = LegalConfig.supportEmail.trim();
  if (email.isNotEmpty) {
    final mailto = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: const {'subject': 'Gains support'},
    );
    if (await launchUrl(mailto, mode: LaunchMode.externalApplication)) {
      return;
    }
  }

  final url = LegalConfig.supportUrl.trim();
  if (url.isNotEmpty) {
    final uri = Uri.tryParse(url);
    if (uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open support contact')),
    );
  }
}
