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

/// Joins only the non-blank region and country into one display string, or null
/// when both are blank/absent.
///
/// The short counterpart to [formatAddress]: a compact card says roughly where
/// a place is, and leaves the street line to the detail screen.
String? formatRegionCountry({String? region, String? country}) {
  final String joined = <String?>[region, country]
      .whereType<String>()
      .map((String part) => part.trim())
      .where((String part) => part.isNotEmpty)
      .join(', ');
  return joined.isEmpty ? null : joined;
}
