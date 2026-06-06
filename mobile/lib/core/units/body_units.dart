/// Display and input units for height/weight (API always uses cm/kg).
enum BodyUnitSystem {
  metric,
  imperial,
}

abstract final class BodyUnits {
  static const double cmPerInch = 2.54;
  static const double kgPerLb = 0.45359237;

  /// Slider ranges (stored values still validated against API limits).
  static const int minHeightCm = 50;
  static const int maxHeightCm = 220;
  static const int minTotalInches = 48; // 4'0"
  static const int maxTotalInches = 84; // 7'0"
  static const int minWeightKg = 20;
  static const int maxWeightKg = 200;
  static const int minWeightLb = 66;
  static const int maxWeightLb = 440;

  static const double defaultHeightCm = 170;
  static const double defaultWeightKg = 75;

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

  static int cmToTotalInches(double cm) => (cm / cmPerInch).round().clamp(minTotalInches, maxTotalInches);

  static double totalInchesToCm(int totalInches) => totalInches * cmPerInch;

  static int kgToLb(double kg) => (kg / kgPerLb).round().clamp(minWeightLb, maxWeightLb);

  static double lbToKg(int lb) => lb * kgPerLb;

  static String formatHeightDisplay(double cm, BodyUnitSystem units) {
    if (units == BodyUnitSystem.metric) {
      return '${cm.round()} cm';
    }
    final totalIn = cmToTotalInches(cm);
    final ft = totalIn ~/ 12;
    final inch = totalIn % 12;
    return "$ft'$inch\"";
  }

  static String formatWeightDisplay(double kg, BodyUnitSystem units) {
    if (units == BodyUnitSystem.metric) {
      return '${kg.round()} kg';
    }
    return '${kgToLb(kg)} lb';
  }

  static String? validateHeightCm(double cm) {
    if (cm < 50 || cm > 300) {
      return 'Height must be between 50–300 cm';
    }
    return null;
  }

  static String? validateWeightKg(double kg) {
    if (kg < 20 || kg > 400) {
      return 'Weight must be between 20–400 kg';
    }
    return null;
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

  /// Total tonnage (sum of weight×reps stored as kg).
  static String formatVolumeKg(double kg, BodyUnitSystem units) {
    if (units == BodyUnitSystem.imperial) {
      final lb = kg / kgPerLb;
      if (lb >= 1000) return '${(lb / 1000).toStringAsFixed(1)}k lb';
      return '${lb.toStringAsFixed(0)} lb';
    }
    if (kg >= 1000) return '${(kg / 1000).toStringAsFixed(1)}k kg';
    return '${kg.toStringAsFixed(0)} kg';
  }

  /// Converts "85 kg" style phrases in AI copy when user prefers imperial.
  static String formatAiWeightUnitsInText(String text, BodyUnitSystem units) {
    if (units == BodyUnitSystem.metric) return text;
    return text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*kg\b', caseSensitive: false),
      (m) {
        final kg = double.parse(m.group(1)!);
        return '${formatWeightKg(kg, units)} lb';
      },
    );
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
