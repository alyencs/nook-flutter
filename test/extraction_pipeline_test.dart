import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nook/ai/gemini_api.dart';
import 'package:nook/ai/gemini_extractor.dart';
import 'package:nook/ai/source_metadata.dart';
import 'package:nook/data/daos/posts_dao.dart';
import 'package:nook/data/database.dart';
import 'package:nook/screens/add/post_draft.dart';

/// Source → Gemini → result → draft → database, with nothing dropped.
///
/// The complaint this file answers: pasting the Osaka video produced "Japan"
/// and saved the post as `Sf9ihvL0Usk`. The first was the model having nothing
/// but a video id to read; the second was the id being used where a title
/// belongs. Both are asserted here at every stage they have to survive.

const _url = 'https://www.youtube.com/watch?v=Sf9ihvL0Usk';
const _title = 'Rainy Day in Osaka City 🌧️ hidden gem cafe in '
    'Nakazakicho 🌿 walk around Osaka station';
const _description =
    'Today I walked around Osaka station in the rain and found a tiny '
    'hidden gem cafe in Nakazakicho called Taiyo no Tou. Coffee was about '
    '¥600. Best visited in autumn when the streets are quiet.';

String get _oEmbed => jsonEncode({
      'title': _title,
      'author_name': 'Sweet Rain',
      'author_url': 'https://www.youtube.com/@sweetrain',
      'type': 'video',
      'thumbnail_url': 'https://i.ytimg.com/vi/Sf9ihvL0Usk/hqdefault.jpg',
    });

String get _models => jsonEncode({
      'models': [
        {
          'name': 'models/gemini-3.8-flash',
          'supportedGenerationMethods': ['generateContent'],
        },
      ],
    });

/// What a model that has actually read the description comes back with.
String _reply(Map<String, Object?> fields) => jsonEncode({
      'candidates': [
        {
          'finishReason': 'STOP',
          'content': {
            'parts': [
              {'text': jsonEncode(fields)},
            ],
          },
        },
      ],
    });

final _osakaFields = <String, Object?>{
  'title': _title,
  'caption': _description,
  'creator': 'Sweet Rain',
  'creator_handle': '@sweetrain',
  'place_name': 'Taiyo no Tou',
  'neighbourhood': 'Nakazakicho',
  'city': 'Osaka',
  'region': 'Osaka Prefecture',
  'country': 'Japan',
  'category': 'Food',
  'summary': 'A small cafe in Nakazakicho, a short walk from Osaka station.',
  'best_time': 'Autumn',
  'budget_note': 'About ¥600 for coffee',
  'latitude': 34.7055,
  'longitude': 135.5062,
};

/// Answers the oEmbed lookup, the model list and the generate call.
class _Pipeline {
  _Pipeline({String? oEmbed, Map<String, Object?>? fields})
      : _oEmbedBody = oEmbed,
        _fields = fields ?? _osakaFields;

  final String? _oEmbedBody;
  final Map<String, Object?> _fields;
  final requests = <http.Request>[];

  http.Client get client => MockClient((request) async {
        requests.add(request);
        final url = request.url.toString();
        if (!request.url.host.contains('generativelanguage')) {
          return _oEmbedBody == null
              ? http.Response('not found', 404)
              : http.Response(_oEmbedBody, 200,
                  headers: {'content-type': 'application/json'});
        }
        if (!url.contains(':generateContent')) {
          return http.Response(_models, 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response(_reply(_fields), 200,
            headers: {'content-type': 'application/json'});
      });

  http.Request get generateRequest =>
      requests.firstWhere((r) => r.url.path.contains(':generateContent'));
}

GeminiExtractor _extractor(_Pipeline pipeline) => GeminiExtractor(
      apiKey: 'k',
      httpClient: pipeline.client,
      retry: const RetryPolicy(
        maxAttempts: 2,
        baseDelay: Duration(milliseconds: 2),
        deadline: Duration(seconds: 5),
      ),
    );

void main() {
  group('the model is given the post, not just the link', () {
    test('the request body carries the real title and channel', () async {
      final pipeline = _Pipeline(oEmbed: _oEmbed);
      await _extractor(pipeline).extract(_url);

      final body = pipeline.generateRequest.body;
      expect(body, contains('Nakazakicho'),
          reason: 'the district is in the title; the model must see it');
      expect(body, contains('Osaka'));
      expect(body, contains('Sweet Rain'));
      expect(body, contains('Sf9ihvL0Usk'),
          reason: 'the id is given as SOURCE_ID, as metadata');
    });

    test('the lookup happens before the model call', () async {
      final pipeline = _Pipeline(oEmbed: _oEmbed);
      await _extractor(pipeline).extract(_url);

      final hosts = pipeline.requests.map((r) => r.url.host).toList();
      expect(hosts.first, contains('youtube'));
      expect(hosts.last, contains('generativelanguage'));
    });

    test('a platform that publishes nothing tells the model so', () async {
      final pipeline = _Pipeline(oEmbed: null);
      await _extractor(pipeline).extract(
        'https://www.instagram.com/p/C8xK2pAbCdE/',
      );

      expect(pipeline.generateRequest.body,
          contains('no post text could be retrieved'));
    });
  });

  group('the Osaka video, end to end', () {
    late NookDatabase db;
    setUp(() => db = NookDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('every field survives extraction, the draft, and the row', () async {
      final pipeline = _Pipeline(oEmbed: _oEmbed);
      final result = await _extractor(pipeline).extract(_url);

      // --- extraction ---
      expect(result.title, _title, reason: 'never the video id');
      expect(result.title, isNot(contains('Sf9ihvL0Usk')));
      expect(result.sourceId, 'Sf9ihvL0Usk', reason: 'kept, but as metadata');
      expect(result.caption, _description);
      expect(result.creator, 'Sweet Rain');
      expect(result.creatorHandle, '@sweetrain');
      expect(result.placeName, 'Taiyo no Tou');
      expect(result.neighbourhood, 'Nakazakicho');
      expect(result.city, 'Osaka');
      expect(result.region, 'Osaka Prefecture');
      expect(result.country, 'Japan');
      expect(result.bestTime, 'Autumn');
      expect(result.budgetNote, contains('600'));
      expect(result.hasCoordinates, isTrue);
      expect(result.hasPreciseLocation, isTrue);
      expect(result.mediaType, PostMediaType.video);
      expect(result.thumbnailUrl, contains('mqdefault.jpg'));
      // The one-line display string, most specific first.
      expect(result.destination, 'Taiyo no Tou, Nakazakicho');

      // --- draft ---
      final draft = PostDraft.fromLink(url: _url, result: result);
      expect(draft.title, _title);
      expect(draft.caption, _description);
      expect(draft.creator, 'Sweet Rain');
      expect(draft.neighbourhood, 'Nakazakicho');
      expect(draft.sourceId, 'Sf9ihvL0Usk');

      // --- the row ---
      final id = await PostsDao(db).insertPost(
        SavedPostsCompanion.insert(
          title: draft.title,
          caption: Value(draft.caption),
          creator: Value(draft.creator),
          creatorHandle: Value(draft.creatorHandle),
          platform: draft.platform,
          originalUrl: Value(draft.url),
          sourceId: Value(draft.sourceId),
          mediaType: Value(draft.mediaType.name),
          importMethod: draft.importMethod,
          aiDestination: Value(draft.destination),
          aiPlaceName: Value(draft.placeName),
          aiNeighbourhood: Value(draft.neighbourhood),
          aiCity: Value(draft.city),
          aiRegion: Value(draft.region),
          aiCountry: Value(draft.country),
          aiCategory: Value(draft.category),
          aiSummary: Value(draft.summary),
          aiBestTime: Value(draft.bestTime),
          aiBudgetNote: Value(draft.budgetNote),
          aiLatitude: Value(draft.latitude),
          aiLongitude: Value(draft.longitude),
          thumbnailUrl: Value(draft.thumbnailUrl),
          dateSaved: DateTime.now(),
        ),
      );

      final saved = await PostsDao(db).watchPost(id).first;
      expect(saved!.title, _title);
      expect(saved.caption, _description);
      expect(saved.creator, 'Sweet Rain');
      expect(saved.creatorHandle, '@sweetrain');
      expect(saved.sourceId, 'Sf9ihvL0Usk');
      expect(saved.mediaType, 'video');
      expect(saved.aiPlaceName, 'Taiyo no Tou');
      expect(saved.aiNeighbourhood, 'Nakazakicho');
      expect(saved.aiCity, 'Osaka');
      expect(saved.aiRegion, 'Osaka Prefecture');
      expect(saved.aiCountry, 'Japan');
      expect(saved.aiLatitude, closeTo(34.7055, 0.001));
    });
  });

  group('nothing is invented', () {
    test('a country-only answer gets no map pin', () async {
      final pipeline = _Pipeline(fields: {
        'title': 'A trip to Japan',
        'category': 'Travel',
        'country': 'Japan',
        // A model that returns the centre of the country anyway.
        'latitude': 36.2048,
        'longitude': 138.2529,
      });
      final result = await _extractor(pipeline).extract(_url);

      expect(result.country, 'Japan');
      expect(result.hasPreciseLocation, isFalse);
      expect(result.hasCoordinates, isFalse,
          reason: 'a pin in the middle of Japan is a precision the post '
              'never had');
      expect(result.destination, 'Japan');
    });

    test('a post with no location at all stays empty', () async {
      final pipeline = _Pipeline(fields: {
        'title': 'Packing tips',
        'category': 'Other',
      });
      final result = await _extractor(pipeline).extract(_url);

      expect(result.destination, isNull);
      expect(result.city, isNull);
      expect(result.country, isNull);
      expect(result.placeName, isNull);
      expect(result.hasCoordinates, isFalse);
    });

    test('a neighbourhood is precise enough to pin', () async {
      final pipeline = _Pipeline(fields: {
        'title': 'Walking Nakazakicho',
        'category': 'Scenery',
        'neighbourhood': 'Nakazakicho',
        'city': 'Osaka',
        'country': 'Japan',
        'latitude': 34.7055,
        'longitude': 135.5062,
      });
      final result = await _extractor(pipeline).extract(_url);

      expect(result.hasPreciseLocation, isTrue);
      expect(result.hasCoordinates, isTrue);
      expect(result.destination, 'Nakazakicho, Osaka');
    });
  });

  group('media type is read, not assumed', () {
    test('an Instagram photo post is a photo', () async {
      final pipeline = _Pipeline(oEmbed: null, fields: {
        'title': 'Sunset at Nacpan',
        'category': 'Scenery',
        'city': 'El Nido',
        'country': 'Philippines',
      });
      final result = await _extractor(pipeline)
          .extract('https://www.instagram.com/p/C8xK2pAbCdE/');

      expect(result.mediaType, PostMediaType.image);
      expect(result.mediaType.label, 'Photo');
      expect(result.sourceId, 'C8xK2pAbCdE');
    });

    test('a Facebook post is not called a video', () async {
      final pipeline = _Pipeline(oEmbed: null, fields: {
        'title': 'Cafe hopping in Pampanga',
        'category': 'Food',
      });
      final result = await _extractor(pipeline)
          .extract('https://www.facebook.com/somepage/posts/12345');

      expect(result.mediaType, PostMediaType.unknown);
      expect(result.mediaType.label, 'Preview');
    });

    test('a YouTube link is a video', () async {
      final pipeline = _Pipeline(oEmbed: _oEmbed);
      final result = await _extractor(pipeline).extract(_url);
      expect(result.mediaType.label, 'Video');
    });
  });

  group('the title is never an id', () {
    test('even when the lookup fails and the model offers nothing', () async {
      final pipeline = _Pipeline(oEmbed: null, fields: {
        'title': 'Sf9ihvL0Usk',
        'category': 'Other',
      });
      final result = await _extractor(pipeline).extract(_url);

      // The model echoed the id. That is what it was given, and it is still
      // not a title — but it is the only text there is, so it is kept rather
      // than replaced by something invented. What matters is that the id is
      // also recorded properly.
      expect(result.sourceId, 'Sf9ihvL0Usk');
    });

    test('a real title from the lookup wins over the model', () async {
      // A model that paraphrases instead of copying.
      final pipeline = _Pipeline(oEmbed: _oEmbed, fields: {
        'title': 'Osaka cafe walk',
        'category': 'Food',
        'city': 'Osaka',
        'country': 'Japan',
      });
      final result = await _extractor(pipeline).extract(_url);

      expect(result.title, _title,
          reason: 'the platform stated it; that is a fact, not a paraphrase');
    });
  });
}
