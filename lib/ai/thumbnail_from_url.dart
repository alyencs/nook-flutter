import 'dart:convert';

import 'package:http/http.dart' as http;

import 'platform_from_url.dart';
import 'source_metadata.dart';

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
  /// Short on purpose. A thumbnail is a nicety; waiting on one is not worth
  /// making the user watch a spinner, and a browser blocked by CORS may never
  /// answer at all.
  static const lookupTimeout = Duration(milliseconds: 2500);

  /// The part that needs no network. Safe to call anywhere.
  ///
  /// **Not `hqdefault.jpg`.** That file is 480x360 — 4:3 — and YouTube fits the
  /// 16:9 frame inside it by painting black bars along the top and bottom. Those
  /// bars are pixels in the image, so no `BoxFit` can remove them: cover crops
  /// the picture, not the letterboxing, and the result is the black padding on
  /// every card. `mqdefault.jpg` is 320x180, true 16:9, has no bars, and exists
  /// for every video ever uploaded.
  static String? fromUrl(String url) {
    final id = youTubeVideoId(url);
    return id == null ? null : mqDefault(id);
  }

  /// 320x180, 16:9, always present.
  static String mqDefault(String videoId) =>
      'https://img.youtube.com/vi/$videoId/mqdefault.jpg';

  /// 1280x720, 16:9, present for most modern uploads and absent for old ones.
  /// Worth trying first for the large preview, with [mqDefault] behind it.
  static String hd720(String videoId) =>
      'https://img.youtube.com/vi/$videoId/hq720.jpg';

  /// The sharper variant for a given thumbnail URL, or null if there is none.
  static String? sharperVariant(String? url) {
    if (url == null) return null;
    final match = RegExp(r'img\.youtube\.com/vi/([^/]+)/mqdefault\.jpg')
        .firstMatch(url);
    return match == null ? null : hd720(match.group(1)!);
  }

  /// The best preview image available for a link.
  ///
  /// [source] is passed in when the caller has already looked the post up, so
  /// that a thumbnail the platform itself named — TikTok's, or YouTube's from
  /// oEmbed — is preferred over one derived from the URL. YouTube's oEmbed
  /// hands back `hqdefault.jpg`, the letterboxed one, so that specific case is
  /// rewritten to the 16:9 file.
  static Future<String?> resolve(String url, {SourceMetadata? source}) async {
    final fromSource = _unletterboxed(source?.thumbnailUrl);
    if (fromSource != null) return fromSource;

    final direct = fromUrl(url);
    if (direct != null) return direct;

    if (NookPlatform.fromUrl(url) != NookPlatform.tiktok) return null;

    try {
      final response = await http
          .get(Uri.parse('https://www.tiktok.com/oembed?url=$url'))
          .timeout(lookupTimeout);
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

  /// Swaps YouTube's letterboxed 4:3 files for the 16:9 one.
  static String? _unletterboxed(String? url) {
    if (url == null || url.isEmpty) return null;
    final match = RegExp(r'(img\.youtube\.com|i\.ytimg\.com)/vi/([^/]+)/'
            r'(hqdefault|sddefault|default)\.jpg')
        .firstMatch(url);
    return match == null ? url : mqDefault(match.group(2)!);
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
