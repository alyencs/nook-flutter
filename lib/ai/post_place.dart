import 'dart:convert';

/// One place a post named.
///
/// "5 Cafes in Kyoto" is five of these plus a city. Before this existed the
/// whole post collapsed to `Kyoto`, because there was one destination field and
/// five cafes to put in it.
class PostPlace {
  const PostPlace({required this.name, this.kind, this.area, this.note});

  /// The place itself: "Taiyo no Tou", "Fushimi Inari".
  final String name;

  /// cafe | restaurant | bar | hotel | shop | landmark | viewpoint | other.
  final String? kind;

  /// Where within the destination — a district, a street, a station.
  final String? area;

  /// What the source said about it, in the source's own terms.
  final String? note;

  static PostPlace? fromJson(Object? value) {
    if (value is! Map) return null;
    final name = _string(value['name']);
    if (name == null) return null;
    return PostPlace(
      name: name,
      kind: _string(value['kind']),
      area: _string(value['area']),
      note: _string(value['note']),
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    if (kind != null) 'kind': kind,
    if (area != null) 'area': area,
    if (note != null) 'note': note,
  };

  /// The line a card shows: "Taiyo no Tou · Nakazakicho".
  String get summary => area == null ? name : '$name · $area';

  static String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty || trimmed.toLowerCase() == 'null' ? null : trimmed;
  }

  /// Decodes the JSON held in `saved_posts.ai_places`.
  static List<PostPlace> decode(String? json) {
    if (json == null || json.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return const [];
      return decoded
          .map(PostPlace.fromJson)
          .whereType<PostPlace>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Encodes for storage. An empty list is stored as null, not `[]`, so that
  /// "nothing was found" and "nobody has looked" read the same to every screen.
  static String? encode(List<PostPlace> places) => places.isEmpty
      ? null
      : jsonEncode(places.map((p) => p.toJson()).toList());
}

/// Activities, recommendations and tips, as the source gave them.
abstract final class PostHighlights {
  static List<String> decode(String? json) {
    if (json == null || json.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return const [];
      return decoded
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static String? encode(List<String> highlights) =>
      highlights.isEmpty ? null : jsonEncode(highlights);
}
