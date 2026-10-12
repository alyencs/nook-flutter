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
    this.hashtags = const [],
    this.canonicalUrl,
    this.mediaType = PostMediaType.unknown,
    this.fetched = false,
    this.unreadableReason,
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

  /// `#tags` found in the caption, in the order written.
  ///
  /// Signal, but weak signal: `#baguio` names a place and `#fyp` names
  /// nothing. They are passed to the model labelled as hashtags so it can
  /// weigh them that way rather than reading them as prose.
  final List<String> hashtags;

  /// Where a short link actually went. `vt.tiktok.com/ZSAbCdEf` is what the
  /// share sheet copies, and it carries no video id and no handle; the
  /// resolved address carries both.
  final String? canonicalUrl;

  final PostMediaType mediaType;

  /// True when a real lookup answered. False means the fields here came from
  /// the URL alone, and the extraction is working with much less.
  final bool fetched;

  /// Why nothing could be read, when nothing could.
  ///
  /// A private, deleted or login-gated post is a different thing from a bug,
  /// and the person pasting the link is the only one who can tell them apart
  /// — so they are told which it was.
  final String? unreadableReason;

  bool get hasText =>
      (title != null && title!.trim().isNotEmpty) ||
      (description != null && description!.trim().isNotEmpty);

  /// Whether [title] is a title, or a caption sitting in the title field.
  ///
  /// It depends entirely on the platform, and getting it wrong costs either
  /// way. YouTube videos have real titles — a person wrote "5 Hidden Cafes in
  /// Kyoto" into a title box — and discarding one for a model's paraphrase
  /// throws away a stated fact.
  ///
  /// TikTok, Instagram and Facebook posts have no title field at all. What
  /// arrives as `title` is the caption (TikTok's oEmbed) or a byline built
  /// around it (`nina.reyes on Instagram: "we found…"`). Using either as a
  /// title is how a post ended up named after a paragraph.
  bool get hasRealTitle {
    final heading = title?.trim();
    if (heading == null || heading.isEmpty) return false;
    return switch (platform) {
      NookPlatform.youtube => true,
      NookPlatform.tiktok ||
      NookPlatform.instagram ||
      NookPlatform.facebook => false,
      // An unknown platform gets the benefit of the doubt, unless the "title"
      // is just the body repeated.
      _ => heading != description?.trim(),
    };
  }

  /// The post's own words, wherever they turned out to live.
  ///
  /// On YouTube that is the description, under a real title. On TikTok,
  /// Instagram and Facebook there is usually no title at all and the caption is
  /// the entire post — which is why nothing may key off [title] being present.
  /// A post with a caption and no title is a complete post.
  String? get caption {
    final body = description?.trim();
    if (body != null && body.isNotEmpty) return body;
    // No description, so a "title" that is really a caption is the only text
    // this post has. On a platform with real titles it stays a title.
    if (hasRealTitle) return null;
    final heading = title?.trim();
    return (heading != null && heading.isNotEmpty) ? heading : null;
  }

  /// Whether there is anything to read at all, title or not.
  bool get hasCaption => caption != null;

  /// Whether this source carries a creator avatar at all.
  bool get hasCreatorAvatar =>
      creatorAvatarUrl != null && creatorAvatarUrl!.trim().isNotEmpty;

  /// The source, written out for the model to read. Labelled and fenced so it
  /// can be held to "use only what is here".
  String toPromptBlock() {
    final buffer = StringBuffer()
      ..writeln('PLATFORM: ${NookPlatform.label(platform)}')
      ..writeln('URL: $url');
    if (canonicalUrl != null) buffer.writeln('RESOLVED_URL: $canonicalUrl');
    if (sourceId != null) buffer.writeln('SOURCE_ID: $sourceId');
    if (creator != null) buffer.writeln('CREATOR_NAME: $creator');
    if (creatorHandle != null) buffer.writeln('CREATOR_HANDLE: $creatorHandle');
    if (mediaType != PostMediaType.unknown) {
      buffer.writeln('MEDIA_TYPE: ${mediaType.name}');
    }

    // The caption goes in under its own label whether or not there is a title,
    // and it goes in whole. Writing it only as `DESCRIPTION` under a `TITLE`
    // meant that on the three platforms where the caption is the entire post,
    // the post's own words arrived labelled as its title — or, when the model
    // was told a title and a caption that match are a duplicate, did not
    // arrive at all.
    // Keyed on whether the title is a title, not on whether the field is set.
    // TikTok's oEmbed puts the caption in `title`, so going by the field alone
    // wrote the same text twice — once as TITLE and once as CAPTION — and
    // presented a caption as a title on exactly the platforms where that was
    // the bug being fixed.
    if (hasRealTitle) {
      buffer.writeln('TITLE:\n${title!.trim()}');
    } else {
      buffer.writeln('TITLE: (none — this post has no title, which is normal)');
    }

    final body = caption;
    if (body != null) buffer.writeln('CAPTION:\n$body');
    if (hashtags.isNotEmpty) {
      buffer.writeln('HASHTAGS: ${hashtags.map((tag) => '#$tag').join(' ')}');
    }
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
      final why = unreadableReason;
      return 'NOTE: this post could not be read. '
          '${why == null ? '' : '$why '}'
          'Only the URL is available, so extract only what the URL itself '
          'supports — often nothing beyond the platform and the account name. '
          'Leave everything else null. Do not guess at the caption, the place, '
          'or the content.';
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

    final hashtagNote = hashtags.isEmpty
        ? ''
        : ' HASHTAGS are weak evidence: one naming a city or a venue '
              '("#baguio", "#cafekyoto") supports a place, while "#fyp", '
              '"#viral" or "#travel" supports nothing. Never treat a hashtag '
              'as a confirmed fact on its own.';

    if (caption == null) {
      return 'NOTE: $where Nothing but the platform and the account could be '
          'read for this post — no title, no caption, no transcript. Extract '
          'what that supports and leave the rest null.$hashtagNote';
    }
    if (!hasRealTitle) {
      return 'NOTE: $where This post has NO TITLE, which is completely normal '
          'on this platform and is not a sign the post is empty. The CAPTION '
          'is the post. Read it for the place, the venue, the city, prices and '
          'recommendations exactly as you would a description, and write a '
          'short title of your own from what it says.$hashtagNote';
    }
    return 'NOTE: $where$hashtagNote';
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
  static const timeout = Duration(seconds: 12);

  /// The service's metadata route, relative to the backend address. Pinned in
  /// `server/api-contract.json` and asserted from both sides.
  static const metadataPath = 'v1/metadata';

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
    String? backendUrl,
  }) async {
    final trimmed = url.trim();
    final platform = NookPlatform.fromUrl(trimmed);
    final fallback = SourceMetadata.fromUrlOnly(trimmed);

    // Nook's own service first, when there is one. It reads the post from a
    // server, which is the only place the reading can be done: a static site
    // asking a platform for a page is a cross-origin request, and Instagram
    // and Facebook send no CORS headers — which is why those two arrived at
    // the model as a bare URL however public the post was.
    if (backendUrl != null && backendUrl.trim().isNotEmpty) {
      final viaService = await _fromService(
        trimmed,
        backendUrl.trim(),
        fallback,
        client,
      );
      if (viaService != null) {
        // YouTube's description and avatar still come from the Data API, which
        // needs a key the service does not hold.
        if (platform == NookPlatform.youtube &&
            youTubeApiKey != null &&
            youTubeApiKey.isNotEmpty &&
            viaService.sourceId != null) {
          return _withYouTubeSnippet(viaService, youTubeApiKey, client);
        }
        return viaService;
      }
      // The service is unreachable or refused. Fall through to the direct
      // lookups below, which still work for YouTube and sometimes TikTok.
    }

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

  /// Asks Nook's service to read the post, and maps its answer.
  ///
  /// Returns null when the service could not be asked at all — unreachable,
  /// refused, a shape that does not parse — so the caller can fall back. A
  /// service that answers "this post is private" is not null: that is a real
  /// answer and it carries the reason the person needs to see.
  static Future<SourceMetadata?> _fromService(
    String url,
    String backendUrl,
    SourceMetadata fallback,
    http.Client? client,
  ) async {
    var base = backendUrl;
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/v1')) base = base.substring(0, base.length - 3);

    try {
      final uri = Uri.parse('$base/$metadataPath');
      final body = jsonEncode({'url': url});
      const headers = {'content-type': 'application/json'};
      final response = client != null
          ? await client.post(uri, headers: headers, body: body).timeout(timeout)
          : await http.post(uri, headers: headers, body: body).timeout(timeout);

      if (response.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map<String, dynamic>) return null;
      return _fromServiceJson(json, fallback);
    } catch (_) {
      // Offline, timed out, or the service is an older build with no metadata
      // route. Neither is fatal: extraction runs on less.
      return null;
    }
  }

  /// The service's answer, mapped onto [SourceMetadata].
  ///
  /// The URL-derived fallback is kept underneath every field rather than
  /// replaced, so a service that reads a caption but no handle does not lose
  /// the handle the URL already gave.
  static SourceMetadata _fromServiceJson(
    Map<String, dynamic> json,
    SourceMetadata fallback,
  ) {
    String? text(String key) {
      final value = json[key];
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final tags = json['hashtags'];
    final mediaType = PostMediaType.parse(text('mediaType'));

    return SourceMetadata(
      platform: fallback.platform,
      url: fallback.url,
      sourceId:
          fallback.sourceId ??
          SourceIds.of(text('canonicalUrl') ?? '', fallback.platform),
      title: text('title'),
      description: text('caption'),
      creator: text('creator'),
      creatorHandle: text('creatorHandle') ?? fallback.creatorHandle,
      creatorUrl: text('creatorUrl') ?? fallback.creatorUrl,
      creatorAvatarUrl: sanitiseImageUrl(text('creatorAvatarUrl')),
      thumbnailUrl: sanitiseImageUrl(text('thumbnailUrl')) ?? fallback.thumbnailUrl,
      hashtags: tags is List
          ? tags.whereType<String>().toList(growable: false)
          : const [],
      canonicalUrl: text('canonicalUrl'),
      mediaType: mediaType == PostMediaType.unknown
          ? fallback.mediaType
          : mediaType,
      fetched: json['fetched'] == true,
      unreadableReason: text('reason'),
    );
  }

  /// An image URL safe to hand to `Image.network`, or null.
  ///
  /// Protocol-relative and root-relative URLs both turn up in platform
  /// metadata, and a `data:` or `javascript:` URL in an image field has no
  /// legitimate source. The service normalises what it reads itself; this is
  /// the same check on the app's side of the boundary, because a value that
  /// reaches the widget malformed is a broken avatar on screen.
  static String? sanitiseImageUrl(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final withScheme = trimmed.startsWith('//') ? 'https:$trimmed' : trimmed;
    final uri = Uri.tryParse(withScheme);
    if (uri == null || !uri.hasAuthority) return null;
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    return uri.toString();
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
  /// With a service configured, all four can be: it reads each post's public
  /// page from a server, where there is no origin to be refused for. Without
  /// one the app is back to what a browser can fetch cross-origin, which is
  /// YouTube and TikTok, plus Meta's two if a token happens to be set.
  ///
  /// Stated per platform rather than implied, so the app can say which are
  /// wired rather than suggesting the four behave alike.
  static bool canReadPostText(
    String platform, {
    String? facebookToken,
    String? backendUrl,
  }) {
    if (backendUrl != null && backendUrl.trim().isNotEmpty) {
      return const {
        NookPlatform.youtube,
        NookPlatform.tiktok,
        NookPlatform.instagram,
        NookPlatform.facebook,
      }.contains(platform);
    }
    return endpointFor(
          'https://example.com/x',
          platform,
          facebookToken: facebookToken,
        ) !=
        null;
  }

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
        creatorAvatarUrl: sanitiseImageUrl(avatar),
        thumbnailUrl: source.thumbnailUrl,
        hashtags: source.hashtags.isNotEmpty
            ? source.hashtags
            : _hashtagsFrom(text('description')),
        canonicalUrl: source.canonicalUrl,
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
      thumbnailUrl:
          sanitiseImageUrl(text('thumbnail_url')) ?? fallback.thumbnailUrl,
      hashtags: _hashtagsFrom(text('title') ?? text('description')),
      canonicalUrl: fallback.canonicalUrl,
      mediaType: PostMediaType.parse(text('type')) == PostMediaType.unknown
          ? fallback.mediaType
          : PostMediaType.parse(text('type')),
      fetched: true,
    );
  }

  /// `#tags` in a caption, in the order written, de-duplicated.
  ///
  /// Unicode-aware, because a Japanese or Filipino caption tags in its own
  /// script and `\w` would drop the tag entirely.
  static List<String> _hashtagsFrom(String? text) {
    if (text == null || text.isEmpty) return const [];
    final found = <String>[];
    final seen = <String>{};
    for (final match in RegExp(
      r'#([\p{L}\p{N}_]{1,60})',
      unicode: true,
    ).allMatches(text)) {
      final tag = match.group(1)!;
      if (seen.add(tag.toLowerCase())) found.add(tag);
    }
    return found;
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
    // A short link's path is an opaque share code, not an account. Reading
    // `fb.watch/aBcDeFgHiJ` as `@aBcDeFgHiJ` put a fabricated creator on the
    // post — worse than the blank it replaced, because it looks like a fact.
    final host = (Uri.tryParse(url.trim())?.host ?? '').toLowerCase();
    if (_shortLinkHosts.any((h) => host == h || host.endsWith('.$h'))) {
      return null;
    }

    // instagram.com/<username>/p/<code> and facebook.com/<page>/posts/<id>.
    // A username is only there when a second, non-reserved segment follows it;
    // a single trailing empty segment from a trailing slash does not count.
    if (platform == NookPlatform.instagram ||
        platform == NookPlatform.facebook) {
      final named = segments.where((s) => s.isNotEmpty).toList();
      if (named.length >= 2 &&
          !_reserved.contains(named.first.toLowerCase()) &&
          !_looksLikeId(named.first)) {
        return '@${named.first}';
      }
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

  /// Hosts whose entire path is a redirect code.
  static const _shortLinkHosts = {
    'fb.watch',
    'fb.me',
    'vt.tiktok.com',
    'vm.tiktok.com',
    'instagr.am',
    'youtu.be',
  };

  /// Whether a path segment is an id rather than a username: all digits, or a
  /// Facebook `pfbid...` blob. Neither is ever an account name.
  static bool _looksLikeId(String segment) =>
      RegExp(r'^\d+$').hasMatch(segment) || segment.startsWith('pfbid');

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