import 'package:flutter/material.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/features/subscription/presentation/paywall_sheet.dart';

extension PremiumApiException on ApiException {
  bool get isPremiumRequired =>
      statusCode == 403 &&
      (code == 'premium_required' ||
          message.toLowerCase().contains('premium subscription'));
}

Future<void> showPaywallForApiError(BuildContext context, ApiException e) async {
  if (e.isPremiumRequired) {
    await showPaywallSheet(context);
  }
}
