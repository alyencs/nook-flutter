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

/// Everything the app can legitimately learn about a link before asking the
/// model.
///
/// A bare URL gives the model eleven characters of video id to work from, and
/// it answers "Japan". The post's real title gives it a neighbourhood, a city
/// and a subject.
class SourceMetadata {
  const SourceMetadata({
    required this.platform,
    required this.url,
    this.sourceId,
    this.title,
    this.description,
    this.creator,
    this.creatorHandle,
    this.creatorUrl,
    this.creatorAvatarUrl,
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

  /// The platform's own id: a YouTube video id, an Instagram shortcode, a
  /// TikTok video id. Technical metadata, never shown as the post's title.
  final String? sourceId;

  /// The real, human title. For TikTok and Instagram the caption *is* the
  /// title, which is why [description] can be null while this is long.
  final String? title;
  final String? description;

  /// Display name, e.g. a YouTube channel name.
  final String? creator;

  /// `@handle`, when the URL or the payload carries one.
  final String? creatorHandle;

  /// The creator's page, from oEmbed's `author_url`. The one piece of creator
  /// identity all four providers return.
  final String? creatorUrl;

  /// The creator's profile picture, when the platform publishes one.
  ///
  /// YouTube and only YouTube, and only with a `YOUTUBE_API_KEY` — it takes a
  /// second Data API call, because oEmbed carries no avatar field. TikTok
  /// publishes none, and Instagram and Facebook need a permission Nook does not
  /// ask for. So this is usually null, and the UI draws an initial rather than
  /// inventing a face.
  final String? creatorAvatarUrl;

  final String? thumbnailUrl;
  final PostMediaType mediaType;

  /// True when a real lookup answered. False means the fields here came from
  /// the URL alone, and the extraction is working with much less.
  final bool fetched;

  bool get hasText =>
      (title != null && title!.trim().isNotEmpty) ||
      (description != null && description!.trim().isNotEmpty);

  /// Whether this source carries a creator avatar at all.
  bool get hasCreatorAvatar =>
      creatorAvatarUrl != null && creatorAvatarUrl!.trim().isNotEmpty;

  /// The source, written out for the model to read. Labelled and fenced so it
  /// can be held to "use only what is here".
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
    buffer.writeln(_sourceNote());
    return buffer.toString();
  }

  /// What the model should understand about this kind of source.
  ///
  /// Each platform keeps its travel detail somewhere different, and each has a
  /// different ceiling on what can be read at all. Saying which is which, per
  /// post, stops the model treating a bare URL as licence to invent.
  String _sourceNote() {
    if (!fetched) {
      return switch (platform) {
        NookPlatform.instagram || NookPlatform.facebook =>
          'NOTE: this post could not be read. Instagram and Facebook stopped '
              'serving post text publicly in 2020, and this build has no Meta '
              'app token configured, so only the URL is available. Extract '
              'only what the URL itself supports — often nothing beyond the '
              'platform and the account name. Leave everything else null. Do '
              'not guess at the caption, the place, or the content.',
        _ =>
          'NOTE: no post text could be retrieved. Only the URL is available. '
              'Do not guess at content you cannot see.',
      };
    }

    final where = switch (platform) {
      NookPlatform.youtube =>
        'This is a YouTube video. The description often lists the exact places '
            'visited, with addresses, opening hours, prices and chapter '
            'timestamps. Read it closely; it is usually more specific than the '
            'title.',
      NookPlatform.tiktok =>
        'This is a TikTok. The caption is short and often carries the place '
            'name and hashtags; hashtags naming a city or venue are real '
            'signal, but a generic one like #fyp or #travel is not.',
      NookPlatform.instagram =>
        'This is an Instagram post. The caption is frequently the whole guide — '
            'a numbered list of cafes, a set of tips — so read all of it. A '
            'carousel means several images of the same subject, not several '
            'subjects.',
      NookPlatform.facebook =>
        'This is a Facebook post. The text may be a long write-up or a single '
            'line; treat it as the post body rather than a title.',
      _ => 'Read whatever text is present.',
    };

    if (description == null) {
      return 'NOTE: $where Only the title or caption was available for this '
          'post — there is no fuller description and no transcript. Extract '
          'what it supports and leave the rest null.';
    }
    return 'NOTE: $where';
  }
}

/// Reads whatever each platform makes publicly available.
///
/// YouTube and TikTok publish keyless oEmbed endpoints that send
/// `Access-Control-Allow-Origin: *`, which is what makes them usable from a
/// browser. Instagram and Facebook retired public oEmbed in 2020, so without a
/// Meta token those links reach the model as a URL alone and
/// [SourceMetadata.fetched] is false.
///
/// A network or CORS failure continues on the URL alone rather than failing:
/// less information is a worse extraction, not a broken one.
abstract final class SourceMetadataFetcher {
  /// Short. This runs before the model call, and a slow lookup would show up
  /// directly as a slower analysis.
  static const timeout = Duration(seconds: 6);

  /// Reads each platform through the mechanism that platform offers.
  ///
  /// * YouTube — keyless oEmbed for the title and channel. With
  ///   `YOUTUBE_API_KEY`, the Data API adds the description, which is where the
  ///   cafe names, addresses and prices live.
  /// * TikTok — keyless oEmbed; the caption arrives as the title.
  /// * Instagram and Facebook — behind the Graph API since 2020, so they need
  ///   [facebookToken]. Without it, only what the URL itself says.
  ///
  /// Nothing here guesses: a platform that returns nothing produces a source
  /// marked `fetched: false`, and the prompt block says so.
  static Future<SourceMetadata> fetch(
    String url, {
    http.Client? client,
    String? youTubeApiKey,
    String? facebookToken,
  }) async {
    final trimmed = url.trim();
    final platform = NookPlatform.fromUrl(trimmed);
    final fallback = SourceMetadata.fromUrlOnly(trimmed);

    final endpoint = endpointFor(
      trimmed,
      platform,
      facebookToken: facebookToken,
    );
    if (endpoint == null) return fallback;

    SourceMetadata result = fallback;
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
      if (json is Map<String, dynamic>) result = _fromOEmbed(json, fallback);
    } catch (_) {
      // Offline, CORS, rate-limited, or the shape changed. The extraction still
      // runs; it just has less to go on.
    }

    if (platform == NookPlatform.youtube &&
        youTubeApiKey != null &&
        youTubeApiKey.isNotEmpty &&
        result.sourceId != null) {
      result = await _withYouTubeSnippet(result, youTubeApiKey, client);
    }
    return result;
  }

  /// The oEmbed endpoint for a link, or null when the platform offers none this
  /// build can reach. Separated out so the routing is testable without a
  /// network.
  static String? endpointFor(
    String url,
    String platform, {
    String? facebookToken,
  }) {
    final encoded = Uri.encodeComponent(url.trim());
    final hasToken = facebookToken != null && facebookToken.trim().isNotEmpty;
    final token = hasToken ? Uri.encodeComponent(facebookToken.trim()) : null;

    return switch (platform) {
      // Keyless and CORS-enabled, both of them.
      NookPlatform.youtube =>
        'https://www.youtube.com/oembed?format=json&url=$encoded',
      NookPlatform.tiktok => 'https://www.tiktok.com/oembed?url=$encoded',
      // Meta's two need an app token. `instagram_oembed` and `oembed_post` are
      // the endpoints that replaced the public ones.
      NookPlatform.instagram when hasToken =>
        'https://graph.facebook.com/v21.0/instagram_oembed'
            '?url=$encoded&omitscript=true&access_token=$token',
      NookPlatform.facebook when hasToken =>
        'https://graph.facebook.com/v21.0/oembed_post'
            '?url=$encoded&omitscript=true&access_token=$token',
      _ => null,
    };
  }

  /// Whether this build can read anything beyond the URL for [platform].
  ///
  /// Drives the Connected Platforms screen, so the app can say which of the
  /// four are fully wired rather than implying all four behave alike.
  static bool canReadPostText(String platform, {String? facebookToken}) =>
      endpointFor(
        'https://example.com/x',
        platform,
        facebookToken: facebookToken,
      ) !=
      null;

  /// Adds the description, and the channel if oEmbed did not supply one.
  static Future<SourceMetadata> _withYouTubeSnippet(
    SourceMetadata source,
    String apiKey,
    http.Client? client,
  ) async {
    final uri = Uri.parse(
      'https://www.googleapis.com/youtube/v3/videos'
      '?part=snippet&id=${source.sourceId}&key=$apiKey',
    );
    try {
      final response = client != null
          ? await client.get(uri).timeout(timeout)
          : await http.get(uri).timeout(timeout);
      if (response.statusCode != 200) return source;

      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map) return source;
      final items = json['items'];
      if (items is! List || items.isEmpty) return source;
      final snippet = (items.first as Map)['snippet'];
      if (snippet is! Map) return source;

      String? text(String key) {
        final value = snippet[key];
        if (value is! String) return null;
        final trimmed = value.trim();
        return trimmed.isEmpty ? null : trimmed;
      }

      // The channel id is the only route to a creator's avatar that any of the
      // four platforms offers Nook. It costs one more call on the same key.
      final channelId = text('channelId');
      final avatar = channelId == null
          ? source.creatorAvatarUrl
          : await _youTubeChannelAvatar(channelId, apiKey, client) ??
                source.creatorAvatarUrl;

      return SourceMetadata(
        platform: source.platform,
        url: source.url,
        sourceId: source.sourceId,
        title: text('title') ?? source.title,
        description: text('description') ?? source.description,
        creator: text('channelTitle') ?? source.creator,
        creatorHandle: source.creatorHandle,
        creatorUrl:
            source.creatorUrl ??
            (channelId == null
                ? null
                : 'https://www.youtube.com/channel/$channelId'),
        creatorAvatarUrl: avatar,
        thumbnailUrl: source.thumbnailUrl,
        mediaType: source.mediaType,
        fetched: true,
      );
    } catch (_) {
      return source;
    }
  }

  /// A channel's profile picture, from the Data API.
  ///
  /// Never throws: an avatar is the least important part of an extraction, and
  /// losing the save because a decorative image 403'd would be absurd. The
  /// largest published size wins, because the UI draws it at 2x or 3x.
  static Future<String?> _youTubeChannelAvatar(
    String channelId,
    String apiKey,
    http.Client? client,
  ) async {
    final uri = Uri.parse(
      'https://www.googleapis.com/youtube/v3/channels'
      '?part=snippet&id=$channelId&key=$apiKey',
    );
    try {
      final response = client != null
          ? await client.get(uri).timeout(timeout)
          : await http.get(uri).timeout(timeout);
      if (response.statusCode != 200) return null;

      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map) return null;
      final items = json['items'];
      if (items is! List || items.isEmpty) return null;
      final thumbnails =
          ((items.first as Map)['snippet'] as Map?)?['thumbnails'];
      if (thumbnails is! Map) return null;

      for (final size in const ['high', 'medium', 'default']) {
        final url = (thumbnails[size] as Map?)?['url'];
        if (url is String && url.trim().isNotEmpty) return url.trim();
      }
      return null;
    } catch (_) {
      return null;
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
    final handle =
        text('author_unique_id') ??
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
      creatorUrl: authorUrl ?? fallback.creatorUrl,
      // oEmbed carries no avatar on any of the four. YouTube's arrives later,
      // from the Data API, if there is a key for it.
      creatorAvatarUrl: fallback.creatorAvatarUrl,
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
        _afterSegment(uri, 'p') ??
            _afterSegment(uri, 'reel') ??
            _afterSegment(uri, 'tv'),
      // facebook.com/<page>/posts/<id>, /videos/<id>, /reel/<id>,
      // /watch/?v=<id>, and fb.watch/<code>.
      NookPlatform.facebook =>
        _afterSegment(uri, 'posts') ??
            _afterSegment(uri, 'videos') ??
            _afterSegment(uri, 'reel') ??
            uri.queryParameters['v'] ??
            (uri.host.contains('fb.watch') && uri.pathSegments.isNotEmpty
                ? uri.pathSegments.first
                : null),
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
  /// A reel or video path is a video; an Instagram `/p/` is a photo post.
  /// Anything else stays unknown rather than being assumed to be a video.
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
    'p',
    'reel',
    'reels',
    'tv',
    'stories',
    'explore',
    'watch',
    'share',
    'permalink.php',
    'photo.php',
    'posts',
    'video',
    'groups',
    'pages',
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