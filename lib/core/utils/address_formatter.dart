/// Joins the non-blank address components into one display string (for the
/// detail screen's share text, say), or null when every component is
/// blank/absent.
String? formatAddress({
  String? streetAddress,
  String? city,
  String? region,
  String? country,
}) {
  final String joined = <String?>[streetAddress, city, region, country]
      .whereType<String>()
      .map((String part) => part.trim())
      .where((String part) => part.isNotEmpty)
      .join(', ');
  return joined.isEmpty ? null : joined;
}
