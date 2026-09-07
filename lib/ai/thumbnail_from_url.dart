import 'dart:convert';

import 'package:http/http.dart' as http;

import 'platform_from_url.dart';

/// Works out a preview image for a saved link.
///
/// Two routes, and both are honest about what they cannot do:
///
/// * **YouTube** — the thumbnail URL is derivable from the video id, with no
///   network call and no API key. This always works.
/// * **TikTok** — its public oEmbed endpoint returns a `thumbnail_url`. It is
///   attempted with a short timeout and failure is silent, because a browser
///   can only read it if TikTok sends CORS headers, and that is their call to
///   make, not ours.
///
/// **Instagram and Facebook return nothing.** Both retired their public oEmbed
/// endpoints; reading a thumbnail from either now needs a Meta app, an access
/// token and review. Those posts keep the drawn placeholder rather than a
/// broken image.
abstract final class PostThumbnails {
  /// The part that needs no network. Safe to call anywhere.
  static String? fromUrl(String url) {
    final id = youTubeVideoId(url);
    return id == null ? null : 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }

  /// [fromUrl] first, then a best-effort oEmbed lookup for TikTok.
  static Future<String?> resolve(String url) async {
    final direct = fromUrl(url);
    if (direct != null) return direct;

    if (NookPlatform.fromUrl(url) != NookPlatform.tiktok) return null;

    try {
      final response = await http
          .get(Uri.parse('https://www.tiktok.com/oembed?url=$url'))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) return null;
      final thumbnail = json['thumbnail_url'];
      return thumbnail is String && thumbnail.startsWith('http')
          ? thumbnail
          : null;
    } catch (_) {
      // Blocked by CORS, offline, rate-limited, or the shape changed. A post
      // without a thumbnail is a normal state, not an error worth surfacing.
      return null;
    }
  }

  /// Pulls the video id out of any of YouTube's URL shapes.
  static String? youTubeVideoId(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    final host = uri.host.toLowerCase();

    if (host.contains('youtu.be')) {
      final id = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
      return _valid(id) ? id : null;
    }
    if (!host.contains('youtube')) return null;

    final query = uri.queryParameters['v'];
    if (_valid(query)) return query;

    // /shorts/<id>, /embed/<id>, /live/<id>
    final segments = uri.pathSegments;
    for (final prefix in ['shorts', 'embed', 'live', 'v']) {
      final index = segments.indexOf(prefix);
      if (index != -1 && index + 1 < segments.length) {
        final id = segments[index + 1];
        if (_valid(id)) return id;
      }
    }
    return null;
  }

  /// YouTube ids are 11 characters of URL-safe base64.
  static bool _valid(String? id) =>
      id != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id);
}
