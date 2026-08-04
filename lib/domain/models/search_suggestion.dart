class SearchSuggestion {
  const SearchSuggestion({required this.mapboxId, required this.name, this.fullAddress});

  final String mapboxId;
  final String name;
  final String? fullAddress;

  factory SearchSuggestion.fromJson(Map<String, dynamic> json) => SearchSuggestion(
        mapboxId: json['mapbox_id'] as String,
        name: json['name'] as String,
        fullAddress: json['full_address'] as String? ?? json['place_formatted'] as String?,
      );
}
