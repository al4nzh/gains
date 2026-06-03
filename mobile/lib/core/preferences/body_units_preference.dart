import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:gains/core/units/body_units.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists metric vs imperial for height/weight fields.
class BodyUnitsPreference extends ChangeNotifier {
  BodyUnitsPreference(this._prefs) : _units = _loadInitial(_prefs);

  static const _key = 'body_unit_system';

  final SharedPreferences _prefs;
  BodyUnitSystem _units;

  BodyUnitSystem get units => _units;

  bool get isMetric => _units == BodyUnitSystem.metric;

  static BodyUnitSystem _loadInitial(SharedPreferences prefs) {
    final stored = prefs.getString(_key);
    if (stored == 'imperial') return BodyUnitSystem.imperial;
    if (stored == 'metric') return BodyUnitSystem.metric;
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return BodyUnits.defaultForLocale(locale.countryCode);
  }

  static Future<BodyUnitsPreference> load() async {
    final prefs = await SharedPreferences.getInstance();
    return BodyUnitsPreference(prefs);
  }

  Future<void> setUnits(BodyUnitSystem value) async {
    if (_units == value) return;
    _units = value;
    await _prefs.setString(
      _key,
      value == BodyUnitSystem.imperial ? 'imperial' : 'metric',
    );
    notifyListeners();
  }

  Future<void> toggle() => setUnits(
        isMetric ? BodyUnitSystem.imperial : BodyUnitSystem.metric,
      );
}
