/// Display and input units for height/weight (API always uses cm/kg).
enum BodyUnitSystem {
  metric,
  imperial,
}

abstract final class BodyUnits {
  static const double cmPerInch = 2.54;
  static const double kgPerLb = 0.45359237;

  static BodyUnitSystem defaultForLocale(String? countryCode) {
    switch (countryCode?.toUpperCase()) {
      case 'US':
      case 'LR':
      case 'MM':
        return BodyUnitSystem.imperial;
      default:
        return BodyUnitSystem.metric;
    }
  }

  static double? parseHeightToCm(String raw, BodyUnitSystem units) {
    final t = raw.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    if (units == BodyUnitSystem.metric) {
      return double.tryParse(t);
    }
    // Imperial: 5'10, 5 ft 10, 70 in, or decimal feet 5.83
    final feetInches = RegExp(r'''^(\d+)\s*[''′]?\s*(\d+)?\s*"?$''').firstMatch(t);
    if (feetInches != null) {
      final ft = int.parse(feetInches.group(1)!);
      final inch = feetInches.group(2) != null ? int.parse(feetInches.group(2)!) : 0;
      return (ft * 12 + inch) * cmPerInch;
    }
    final ftIn = RegExp(r'^(\d+)\s*(?:ft|feet)\s*(\d+)?\s*(?:in|inches)?$', caseSensitive: false)
        .firstMatch(t);
    if (ftIn != null) {
      final ft = int.parse(ftIn.group(1)!);
      final inch = ftIn.group(2) != null ? int.parse(ftIn.group(2)!) : 0;
      return (ft * 12 + inch) * cmPerInch;
    }
    final inchesOnly = RegExp(r'^(\d+(?:\.\d+)?)\s*(?:in|inches)?$', caseSensitive: false)
        .firstMatch(t);
    if (inchesOnly != null) {
      return double.parse(inchesOnly.group(1)!) * cmPerInch;
    }
    final asFeet = double.tryParse(t);
    if (asFeet != null) return asFeet * 12 * cmPerInch;
    return null;
  }

  static double? parseWeightToKg(String raw, BodyUnitSystem units) {
    final t = raw.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    final n = double.tryParse(t);
    if (n == null) return null;
    return units == BodyUnitSystem.imperial ? n * kgPerLb : n;
  }

  static String formatHeightCm(double cm, BodyUnitSystem units) {
    if (units == BodyUnitSystem.metric) {
      if (cm == cm.roundToDouble()) return cm.toInt().toString();
      return cm.toStringAsFixed(1);
    }
    final totalIn = (cm / cmPerInch).round();
    final ft = totalIn ~/ 12;
    final inch = totalIn % 12;
    return "$ft'$inch\"";
  }

  static String formatWeightKg(double kg, BodyUnitSystem units) {
    if (units == BodyUnitSystem.metric) {
      if (kg == kg.roundToDouble()) return kg.toInt().toString();
      return kg.toStringAsFixed(1);
    }
    final lb = kg / kgPerLb;
    if (lb == lb.roundToDouble()) return lb.toInt().toString();
    return lb.toStringAsFixed(1);
  }

  static String? validateHeightInput(String? raw, BodyUnitSystem units) {
    if (raw == null || raw.trim().isEmpty) return 'Required';
    final cm = parseHeightToCm(raw, units);
    if (cm == null) {
      return units == BodyUnitSystem.imperial
          ? 'Use e.g. 5\'10 or 70 in'
          : 'Enter a number';
    }
    if (cm < 50 || cm > 300) {
      return units == BodyUnitSystem.imperial ? 'About 4\'–10\'' : '50–300 cm';
    }
    return null;
  }

  static String? validateWeightInput(String? raw, BodyUnitSystem units) {
    if (raw == null || raw.trim().isEmpty) return 'Required';
    final kg = parseWeightToKg(raw, units);
    if (kg == null) return 'Enter a number';
    if (kg < 20 || kg > 400) {
      return units == BodyUnitSystem.imperial ? '44–880 lb' : '20–400 kg';
    }
    return null;
  }
}
