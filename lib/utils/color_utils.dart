import 'dart:ui';

Color parseColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.isEmpty || hex.length > 8) return const Color(0xFF9E9E9E);
  try {
    return Color(int.parse('FF$hex', radix: 16));
  } catch (_) {
    return const Color(0xFF9E9E9E);
  }
}
