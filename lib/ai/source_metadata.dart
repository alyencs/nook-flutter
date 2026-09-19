import 'dart:convert';

import 'package:http/http.dart' as http;

import 'platform_from_url.dart';

/// What kind of thing a saved post actually is.
///
/// Stored separately from the thumbnail, because the thumbnail is just an image
/// either way — it is this that decides whether the badge over it says "Video".
enum PostMediaType {
  video,
  image,
  carousel,
  unknown;

  static PostMediaType parse(String? value) => switch (value) {
        'video' => video,
        'image' => image,
        'carousel' => carousel,
        _ => unknown,
      };

  String get label => switch (this) {
        video => 'Video',
        image => 'Photo',
        carousel => 'Gallery',
        unknown => 'Preview',
      };
}

/// Everything the app can legitimately learn about a link before asking Gemini.
///
/// This is the piece that was missing. Extraction used to hand the model a bare
/// URL, so for `youtube.com/watch?v=Sf9ihvL0Usk` it had eleven characters of
/// video id to work from and quite reasonably answered "Japan". With the real
/// title in front of it — "Rainy Day in Osaka City, hidden gem cafe in
/// Nakazakicho, walk around Osaka station" — it has a neighbourhood, a city and
/// a subject.
class SourceMetadata {
  const SourceMetadata({
    required this.platform,
    required this.url,
    this.sourceId,
    this.title,
    this.description,
    this.creator,
    this.creatorHandle,
    this.thumbnailUrl,
    this.mediaType = PostMediaType.unknown,
    this.fetched = false,
  });

  /// Nothing but what the URL itself says.
  factory SourceMetadata.fromUrlOnly(String url) {
    final platform = NookPlatform.fromUrl(url);
    return SourceMetadata(
      platform: platform,
      url: url,
      sourceId: SourceIds.of(url, platform),
      creatorHandle: SourceIds.handleFrom(url, platform),
      mediaType: SourceIds.mediaTypeFrom(url, platform),
    );
  }

  final String platform;
  final String url;

  /// The platform's own id for the post: a YouTube video id, an Instagram
  /// shortcode, a TikTok video id. Kept as technical metadata, never shown as
  /// the post's title.
  final String? sourceId;

  /// The real, human title. For TikTok and Instagram the caption *is* the
  /// title, which is why [description] can be null while this is long.
  final String? title;
  final String? description;

  /// Display name, e.g. a YouTube channel name.
  final String? creator;

  /// `@handle`, when the URL or the payload carries one.
  final String? creatorHandle;
  final String? thumbnailUrl;
  final PostMediaType mediaType;

  /// True when a real lookup answered. False means the fields here came from
  /// the URL alone, and the extraction is working with much less.
  final bool fetched;

  bool get hasText =>
      (title != null && title!.trim().isNotEmpty) ||
      (description != null && description!.trim().isNotEmpty);

  /// The source, written out for the model to read.
  ///
  /// Labelled and fenced so the model can tell the difference between what the
  /// post says and what the app is asking, and so it can be held to "use only
  /// what is here".
  String toPromptBlock() {
    final buffer = StringBuffer()
      ..writeln('PLATFORM: ${NookPlatform.label(platform)}')
      ..writeln('URL: $url');
    if (sourceId != null) buffer.writeln('SOURCE_ID: $sourceId');
    if (creator != null) buffer.writeln('CREATOR_NAME: $creator');
    if (creatorHandle != null) buffer.writeln('CREATOR_HANDLE: $creatorHandle');
    if (mediaType != PostMediaType.unknown) {
      buffer.writeln('MEDIA_TYPE: ${mediaType.name}');
    }
    if (title != null) buffer.writeln('TITLE:\n$title');
    if (description != null) buffer.writeln('DESCRIPTION:\n$description');
    if (!fetched) {
      buffer.writeln(
        'NOTE: no post text could be retrieved for this platform. Only the URL '
        'is available. Do not guess at content you cannot see.',
      );
    }
    return buffer.toString();
  }
}

/// Reads whatever each platform makes publicly available, without a key.
///
/// What is reachable differs sharply by platform, and the honest position is to
/// say so rather than to pretend:
///
/// * **YouTube** publishes an oEmbed endpoint that returns the real title, the
///   channel name and a thumbnail, no key required.
/// * **TikTok** publishes one too, and there its `title` field is the caption.
/// * **Instagram and Facebook** retired public oEmbed in 2020. Reading a
///   caption from either now needs a Meta app, a token and app review. Those
///   links therefore reach the model as a URL plus whatever the path itself
///   says, and [SourceMetadata.fetched] is false so the model is told as much.
///
/// Both live endpoints send `Access-Control-Allow-Origin: *`, which is what
/// makes them usable from a browser at all. If a network or CORS failure stops
/// one, extraction continues on the URL alone rather than failing: less
/// information is a worse extraction, not a broken one.
abstract final class SourceMetadataFetcher {
  /// Short. This runs before the model call, and a slow lookup would show up
  /// directly as a slower analysis.
  static const timeout = Duration(seconds: 6);

  static Future<SourceMetadata> fetch(String url, {http.Client? client}) async {
    final trimmed = url.trim();
    final platform = NookPlatform.fromUrl(trimmed);
    final fallback = SourceMetadata.fromUrlOnly(trimmed);

    final endpoint = switch (platform) {
      NookPlatform.youtube =>
        'https://www.youtube.com/oembed?format=json&url=${Uri.encodeComponent(trimmed)}',
      NookPlatform.tiktok =>
        'https://www.tiktok.com/oembed?url=${Uri.encodeComponent(trimmed)}',
      _ => null,
    };
    if (endpoint == null) return fallback;

    try {
      final http.Response response;
      final uri = Uri.parse(endpoint);
      if (client != null) {
        response = await client.get(uri).timeout(timeout);
      } else {
        response = await http.get(uri).timeout(timeout);
      }
      if (response.statusCode != 200) return fallback;

      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map<String, dynamic>) return fallback;
      return _fromOEmbed(json, fallback);
    } catch (_) {
      // Offline, CORS, rate-limited, or the shape changed. The extraction still
      // runs; it just has less to go on.
      return fallback;
    }
  }

  /// oEmbed is one shape across providers, with one wrinkle: on YouTube `title`
  /// is the video title and there is no caption field, while on TikTok `title`
  /// carries the whole caption.
  static SourceMetadata _fromOEmbed(
    Map<String, dynamic> json,
    SourceMetadata fallback,
  ) {
    String? text(String key) {
      final value = json[key];
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final authorUrl = text('author_url');
    final handle = text('author_unique_id') ??
        _handleFromAuthorUrl(authorUrl) ??
        fallback.creatorHandle;

    return SourceMetadata(
      platform: fallback.platform,
      url: fallback.url,
      sourceId: fallback.sourceId,
      title: text('title'),
      description: text('description'),
      creator: text('author_name'),
      creatorHandle: handle,
      thumbnailUrl: text('thumbnail_url') ?? fallback.thumbnailUrl,
      mediaType: PostMediaType.parse(text('type')) == PostMediaType.unknown
          ? fallback.mediaType
          : PostMediaType.parse(text('type')),
      fetched: true,
    );
  }

  static String? _handleFromAuthorUrl(String? authorUrl) {
    if (authorUrl == null) return null;
    final segments = Uri.tryParse(authorUrl)?.pathSegments ?? const [];
    for (final segment in segments) {
      if (segment.startsWith('@') && segment.length > 1) return segment;
    }
    return null;
  }
}

/// The parts of a link that can be read without asking anyone.
abstract final class SourceIds {
  /// The platform's own id for the post.
  static String? of(String url, String platform) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    return switch (platform) {
      NookPlatform.youtube => _youTubeId(uri),
      NookPlatform.tiktok => _afterSegment(uri, 'video'),
      NookPlatform.instagram =>
        _afterSegment(uri, 'p') ?? _afterSegment(uri, 'reel'),
      _ => null,
    };
  }

  /// `@handle`, where the URL path carries one.
  static String? handleFrom(String url, String platform) {
    final segments = Uri.tryParse(url.trim())?.pathSegments ?? const [];
    for (final segment in segments) {
      if (segment.startsWith('@') && segment.length > 1) return segment;
    }
    // instagram.com/<username>/p/<code> and facebook.com/<page>/posts/<id>
    if ((platform == NookPlatform.instagram ||
            platform == NookPlatform.facebook) &&
        segments.length >= 2 &&
        !_reserved.contains(segments.first.toLowerCase())) {
      return '@${segments.first}';
    }
    return null;
  }

  /// What the URL shape alone implies about the media.
  ///
  /// A reel or a video path is a video; an Instagram `/p/` is a photo post,
  /// which may turn out to be a carousel. Anything else stays unknown rather
  /// than being assumed to be a video, which is what every card used to do.
  static PostMediaType mediaTypeFrom(String url, String platform) {
    final path = (Uri.tryParse(url.trim())?.path ?? '').toLowerCase();
    if (platform == NookPlatform.youtube) return PostMediaType.video;
    if (path.contains('/reel') ||
        path.contains('/video') ||
        path.contains('/shorts') ||
        path.contains('/watch')) {
      return PostMediaType.video;
    }
    if (platform == NookPlatform.instagram && path.contains('/p/')) {
      return PostMediaType.image;
    }
    if (platform == NookPlatform.facebook && path.contains('/photo')) {
      return PostMediaType.image;
    }
    return PostMediaType.unknown;
  }

  static const _reserved = {
    'p', 'reel', 'reels', 'tv', 'stories', 'explore', 'watch', 'share',
    'permalink.php', 'photo.php', 'posts', 'video', 'groups', 'pages',
  };

  static String? _youTubeId(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host.contains('youtu.be')) {
      return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    }
    final v = uri.queryParameters['v'];
    if (v != null && v.isNotEmpty) return v;
    return _afterSegment(uri, 'shorts') ?? _afterSegment(uri, 'embed');
  }

  static String? _afterSegment(Uri uri, String segment) {
    final segments = uri.pathSegments;
    final index = segments.indexOf(segment);
    if (index == -1 || index + 1 >= segments.length) return null;
    final value = segments[index + 1];
    return value.isEmpty ? null : value;
  }
}
