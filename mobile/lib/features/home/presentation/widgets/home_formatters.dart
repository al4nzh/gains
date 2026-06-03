/// [percentile] = share of rated lifters you're stronger than (0–100, from API).
String formatStrengthPercentile(int percentile) {
  if (percentile >= 90) {
    final top = (100 - percentile).clamp(1, 50);
    return top == 1 ? 'Top 1%' : 'Top $top%';
  }
  return '$percentile${_ordinalSuffix(percentile)} percentile';
}

String _ordinalSuffix(int n) {
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 13) return 'th';
  return switch (n % 10) {
    1 => 'st',
    2 => 'nd',
    3 => 'rd',
    _ => 'th',
  };
}

String formatEloChange(int? delta) {
  if (delta == null) return '—';
  if (delta > 0) return '+$delta';
  return delta.toString();
}

String formatVolumeKg(double kg) {
  if (kg >= 1000) return '${(kg / 1000).toStringAsFixed(1)}k kg';
  return '${kg.toStringAsFixed(0)} kg';
}

String formatDuration(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (m >= 60) {
    final h = m ~/ 60;
    final rm = m % 60;
    return '${h}h ${rm}m';
  }
  return s > 0 ? '${m}m ${s}s' : '${m}m';
}

String formatRelativeDate(DateTime dt) {
  final now = DateTime.now().toUtc();
  final d = dt.toUtc();
  final diff = now.difference(d);
  if (diff.inDays == 0) return 'Today';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String humanizeSnake(String value) {
  return value.split('_').map((w) {
    if (w.isEmpty) return w;
    return '${w[0].toUpperCase()}${w.substring(1)}';
  }).join(' ');
}
