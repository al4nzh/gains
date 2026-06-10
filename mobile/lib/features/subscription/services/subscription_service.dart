import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gains/core/config/subscription_config.dart';
import 'package:gains/features/auth/session/auth_session.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Premium access via server flag + RevenueCat entitlements.
class SubscriptionService extends ChangeNotifier {
  SubscriptionService(this._session) {
    _session.addListener(_onSessionChanged);
  }

  final AuthSession _session;

  bool _configured = false;
  bool _storePremium = false;
  bool _loadingOfferings = false;
  Offerings? _offerings;
  String? _lastError;

  bool get isPremium => _storePremium || (_session.user?.isPremium ?? false);
  bool get isStoreConfigured => SubscriptionConfig.isStoreConfigured;
  bool get isLoadingOfferings => _loadingOfferings;
  Offerings? get offerings => _offerings;
  String? get lastError => _lastError;

  static const premiumFeatures = [
    ('AI Coach', 'Chat, actions, and training advice'),
    ('Workout analysis', 'Post-session AI insights'),
    ('Routine generator', 'Build programs from a prompt'),
    ('Physique scans', 'AI body-fat estimates from photos'),
  ];

  void _onSessionChanged() {
    final userId = _session.user?.id;
    if (userId == null) {
      _storePremium = false;
      notifyListeners();
      return;
    }
    _syncForUser(userId);
  }

  Future<void> bootstrap() async {
    final userId = _session.user?.id;
    if (userId == null) return;
    await _syncForUser(userId);
  }

  Future<void> _syncForUser(String userId) async {
    if (!SubscriptionConfig.isStoreConfigured) {
      notifyListeners();
      return;
    }
    try {
      if (!_configured) {
        final apiKey = SubscriptionConfig.platformApiKey;
        if (apiKey == null) return;
        await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
        await Purchases.configure(PurchasesConfiguration(apiKey));
        _configured = true;
      }
      await Purchases.logIn(userId);
      final info = await Purchases.getCustomerInfo();
      _applyCustomerInfo(info);
      await _session.refreshUser();
    } catch (e) {
      if (kDebugMode) debugPrint('SubscriptionService sync: $e');
    }
    notifyListeners();
  }

  Future<void> loadOfferings() async {
    if (!SubscriptionConfig.isStoreConfigured) return;
    _loadingOfferings = true;
    _lastError = null;
    notifyListeners();
    try {
      _offerings = await Purchases.getOfferings();
    } catch (e) {
      _lastError = 'Could not load subscription options';
      if (kDebugMode) debugPrint('Offerings: $e');
    } finally {
      _loadingOfferings = false;
      notifyListeners();
    }
  }

  Future<bool> purchase(Package package) async {
    _lastError = null;
    try {
      final result = await Purchases.purchasePackage(package);
      _applyCustomerInfo(result.customerInfo);
      await _session.refreshUser();
      notifyListeners();
      return isPremium;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return false;
      _lastError = 'Purchase failed';
      notifyListeners();
      return false;
    } catch (_) {
      _lastError = 'Purchase failed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> restore() async {
    _lastError = null;
    try {
      final info = await Purchases.restorePurchases();
      _applyCustomerInfo(info);
      await _session.refreshUser();
      notifyListeners();
      return isPremium;
    } catch (_) {
      _lastError = 'Could not restore purchases';
      notifyListeners();
      return false;
    }
  }

  void _applyCustomerInfo(CustomerInfo info) {
    _storePremium = info.entitlements.active.containsKey(SubscriptionConfig.entitlementId);
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }
}
