class Category {
  final int id;
  final String name;
  final String slug;

  Category({required this.id, required this.name, required this.slug});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
    );
  }

  String get displayName {
    final normalizedName = name.trim();
    if (normalizedName.isNotEmpty) {
      return normalizedName;
    }

    final normalizedSlug = slug.trim();
    if (normalizedSlug.isEmpty) {
      return 'Uncategorized';
    }

    return normalizedSlug
        .split(RegExp(r'[-_\s]+'))
        .where((part) => part.isNotEmpty)
        .map(_capitalize)
        .join(' ');
  }

  static String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }

    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }
}
