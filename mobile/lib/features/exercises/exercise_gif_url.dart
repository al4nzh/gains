/// ExerciseDB GIF URLs — normalize broken hosts and prefer API proxy for Image.network.
String resolveExerciseGifUrl(String apiBaseUrl, String? raw) {
  var url = raw?.trim() ?? '';
  if (url.isEmpty) return url;

  url = url
      .replaceFirst('https://static.exercisedb.dev/media/', 'https://exercisedb.dev/media/')
      .replaceFirst('http://static.exercisedb.dev/media/', 'https://exercisedb.dev/media/');

  final match = RegExp(r'/media/([^/?#]+)\.gif').firstMatch(url);
  if (match != null) {
    final id = match.group(1);
    if (id != null && id.isNotEmpty) {
      final base = apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
      return '$base/media/exercise-gifs/$id.gif';
    }
  }
  return url;
}
