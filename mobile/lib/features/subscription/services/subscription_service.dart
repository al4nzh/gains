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
  bool _syncing = false;
  String? _lastSyncUserId;
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
    ('Gains Identity', 'Gym archetype and shareable identity card'),
    ('AI suggestions', 'Smart adjustments before each workout'),
    ('Train next', 'Daily routine pick based on your training history'),
  ];

  void _onSessionChanged() {
    final userId = _session.user?.id;
    if (userId == null) {
      if (_storePremium || _lastSyncUserId != null) {
        _storePremium = false;
        _lastSyncUserId = null;
        notifyListeners();
      }
      return;
    }
    if (_syncing || userId == _lastSyncUserId) return;
    _syncForUser(userId);
  }

  Future<void> bootstrap() async {
    final userId = _session.user?.id;
    if (userId == null) return;
    await _syncForUser(userId);
  }

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    final apiKey = SubscriptionConfig.platformApiKey;
    if (apiKey == null) return;
    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
    await Purchases.configure(PurchasesConfiguration(apiKey));
    _configured = true;
  }

  Future<void> _syncForUser(String userId) async {
    if (!SubscriptionConfig.isStoreConfigured) {
      return;
    }
    if (_syncing) return;
    _syncing = true;
    final wasPremium = isPremium;
    try {
      await _ensureConfigured();
      await Purchases.logIn(userId);
      final info = await Purchases.getCustomerInfo();
      _applyCustomerInfo(info);
      await _session.refreshUser();
      _lastSyncUserId = userId;
    } catch (e) {
      if (kDebugMode) debugPrint('SubscriptionService sync: $e');
    } finally {
      _syncing = false;
    }
    if (isPremium != wasPremium) {
      notifyListeners();
    }
  }

  Future<void> loadOfferings() async {
    if (!SubscriptionConfig.isStoreConfigured) return;
    _loadingOfferings = true;
    _lastError = null;
    notifyListeners();
    try {
      await _ensureConfigured();
      _offerings = await Purchases.getOfferings();
      final packages = _offerings?.current?.availablePackages ?? const <Package>[];
      if (packages.isEmpty) {
        _lastError = _offerings?.current == null
            ? 'No current offering in RevenueCat (set default offering as Current)'
            : 'No packages on current offering (add monthly/yearly in RevenueCat)';
      }
    } catch (e) {
      _lastError = 'Could not load subscription options';
      if (kDebugMode) {
        debugPrint('Offerings: $e');
        _lastError = 'Could not load subscription options: $e';
      }
    } finally {
      _loadingOfferings = false;
      notifyListeners();
    }
  }

  Future<bool> purchase(Package package) async {
    _lastError = null;
    try {
      final info = await Purchases.purchasePackage(package);
      _applyCustomerInfo(info);
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
