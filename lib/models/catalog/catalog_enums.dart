enum CatalogMode {
  discovery,
  playable,
  unknown;

  static CatalogMode fromName(Object? value) =>
      _enumFromName(values, value, unknown);
}

enum CatalogSeason {
  winter,
  spring,
  summer,
  fall,
  unknown;

  static CatalogSeason fromName(Object? value) =>
      _enumFromName(values, value, unknown);
}

enum CatalogFormat {
  tv,
  movie,
  ova,
  ona,
  special,
  music,
  unknown;

  static CatalogFormat fromName(Object? value) =>
      _enumFromName(values, value, unknown);
}

enum CatalogStatus {
  upcoming,
  airing,
  completed,
  hiatus,
  cancelled,
  unknown;

  static CatalogStatus fromName(Object? value) =>
      _enumFromName(values, value, unknown);
}

enum CatalogRegion {
  japan,
  china,
  korea,
  western,
  other,
  unknown;

  static CatalogRegion fromName(Object? value) =>
      _enumFromName(values, value, unknown);
}

enum CatalogSort {
  relevance,
  popularity,
  rating,
  updatedAt,
  releaseDate,
  title,
  unknown;

  static CatalogSort fromName(Object? value) =>
      _enumFromName(values, value, unknown);
}

T _enumFromName<T extends Enum>(List<T> values, Object? value, T fallback) {
  final name = value?.toString();
  if (name == null) return fallback;
  for (final candidate in values) {
    if (candidate.name == name) return candidate;
  }
  return fallback;
}
