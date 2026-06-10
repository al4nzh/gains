import 'package:flutter/material.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/subscription/services/subscription_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';

Future<void> showPaywallSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return ChangeNotifierProvider.value(
        value: context.read<SubscriptionService>(),
        child: const _PaywallSheet(),
      );
    },
  );
}

class _PaywallSheet extends StatefulWidget {
  const _PaywallSheet();

  @override
  State<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<_PaywallSheet> {
  bool _purchasing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionService>().loadOfferings();
    });
  }

  Future<void> _buy(Package package) async {
    setState(() => _purchasing = true);
    final ok = await context.read<SubscriptionService>().purchase(package);
    if (!mounted) return;
    setState(() => _purchasing = false);
    if (ok) Navigator.pop(context);
  }

  Future<void> _restore() async {
    setState(() => _purchasing = true);
    final ok = await context.read<SubscriptionService>().restore();
    if (!mounted) return;
    setState(() => _purchasing = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      final err = context.read<SubscriptionService>().lastError;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionService>();
    final packages = sub.offerings?.current?.availablePackages ?? const <Package>[];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Gains Premium',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Unlock AI coaching and advanced tools. Logging workouts, progress, and gym archetype stay free.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            for (final (title, desc) in SubscriptionService.premiumFeatures) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(desc, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            if (sub.isLoadingOfferings)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!sub.isStoreConfigured)
              Text(
                'Subscriptions are configured in release builds. Core training features remain free.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              )
            else if (packages.isEmpty)
              Text(
                sub.lastError ?? 'No subscription packages available yet.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              )
            else
              for (final pkg in packages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: _purchasing ? null : () => _buy(pkg),
                    child: Text(_packageLabel(pkg)),
                  ),
                ),
            if (sub.isStoreConfigured) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: _purchasing ? null : _restore,
                child: const Text('Restore purchases'),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }

  String _packageLabel(Package pkg) {
    final product = pkg.storeProduct;
    final price = product.priceString;
    switch (pkg.packageType) {
      case PackageType.monthly:
        return 'Monthly · $price';
      case PackageType.annual:
        return 'Annual · $price';
      case PackageType.weekly:
        return 'Weekly · $price';
      default:
        return '${product.title} · $price';
    }
  }
}
