import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gains/core/config/legal_config.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

/// Privacy + terms links for welcome, register, and login.
class LegalFooter extends StatelessWidget {
  const LegalFooter({
    super.key,
    this.prefix = 'By continuing, you agree to our ',
    this.center = true,
  });

  final String prefix;
  final bool center;

  @override
  Widget build(BuildContext context) {
    if (!LegalConfig.hasPrivacyUrl && !LegalConfig.hasTermsUrl) {
      return const SizedBox.shrink();
    }

    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textMuted,
          height: 1.4,
        );
    final linkStyle = style?.copyWith(
      color: AppColors.primary,
      decoration: TextDecoration.underline,
    );

    final spans = <InlineSpan>[
      TextSpan(text: prefix, style: style),
    ];

    if (LegalConfig.hasTermsUrl) {
      spans.add(
        TextSpan(
          text: 'Terms',
          style: linkStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () => _open(context, LegalConfig.termsUrl),
        ),
      );
    }
    if (LegalConfig.hasPrivacyUrl && LegalConfig.hasTermsUrl) {
      spans.add(TextSpan(text: ' and ', style: style));
    }
    if (LegalConfig.hasPrivacyUrl) {
      spans.add(
        TextSpan(
          text: 'Privacy Policy',
          style: linkStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () => _open(context, LegalConfig.privacyPolicyUrl),
        ),
      );
    }
    spans.add(TextSpan(text: '.', style: style));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: RichText(
        textAlign: center ? TextAlign.center : TextAlign.start,
        text: TextSpan(children: spans),
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }
}
