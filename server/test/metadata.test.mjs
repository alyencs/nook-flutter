// Reading a post's public metadata, against fixtures rather than live posts.
//
// Fixtures on purpose. The shapes below are what these four platforms serve to
// an unauthenticated GET, trimmed to the tags that matter; pointing the suite
// at real posts would make it fail when a caption is edited, a post is deleted
// or a platform rate-limits the runner, and none of those are this code being
// wrong. The live check is `tool/live_check.dart`, run deliberately.
//
// Every fixture is invented. No real account, caption or photo appears here.
import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  avatarFromEmbeddedJson,
  captionFromJsonLd,
  captionFromOgDescription,
  creatorFromJsonLd,
  creatorFromOgTitle,
  decodeEntities,
  isBoilerplate,
  parseJsonLd,
  profileUrlFor,
  unescapeUrl,
  hashtagsFrom,
  isFetchable,
  looksLikeLoginWall,
  normaliseImageUrl,
  parseMetaTags,
  platformOf,
  readMetadata,
} from '../src/metadata.js';

/** A fetch that answers from a map of URL substring to response. */
function stubFetch(routes, { log } = {}) {
  return async (url) => {
    log?.push(url);
    for (const [fragment, make] of Object.entries(routes)) {
      if (url.includes(fragment)) return make(url);
    }
    return new Response('not found', { status: 404 });
  };
}

// Each returns a FRESH Response. A Response body can only be read once, so a
// shared instance is consumed by whichever test reaches it first and every
// later test sees an unparseable empty body — which looked exactly like the
// platform having answered with nothing.
const html = (body) => () =>
  new Response(body, { status: 200, headers: { 'content-type': 'text/html' } });
const jsonOk = (body) => () =>
  new Response(JSON.stringify(body), {
    status: 200,
    headers: { 'content-type': 'application/json' },
  });

// --- fixtures --------------------------------------------------------------

/** A TikTok with a caption, no title, and a place in the caption. */
const TIKTOK_PAGE = html(`<!doctype html><html><head>
<title>Mika on TikTok</title>
<meta property="og:type" content="video.other">
<meta property="og:url" content="https://www.tiktok.com/@mika.eats/video/7311223344556677889">
<meta property="og:title" content="Mika on TikTok">
<meta property="og:description" content="2.1M likes, 4300 comments. &quot;₱150 lang ang unlimited wings sa Good Taste Baguio! Open 24 hours, 2nd floor pa #baguio #baguiofood #foodtrip #fyp&quot;">
<meta property="og:image" content="https://p16.tiktokcdn.com/thumb/7311223344556677889.jpeg">
</head><body></body></html>`);

const TIKTOK_OEMBED = jsonOk({
  version: '1.0',
  type: 'video',
  title:
    '₱150 lang ang unlimited wings sa Good Taste Baguio! Open 24 hours, 2nd floor pa #baguio #baguiofood #foodtrip #fyp',
  author_name: 'Mika Eats',
  author_unique_id: 'mika.eats',
  author_url: 'https://www.tiktok.com/@mika.eats',
  thumbnail_url: 'https://p16.tiktokcdn.com/obj/7311223344556677889.jpeg',
});

/** The creator's own profile page, whose og:image is the avatar. */
const TIKTOK_PROFILE = html(`<!doctype html><html><head>
<title>Mika Eats (@mika.eats) | TikTok</title>
<meta property="og:title" content="Mika Eats (@mika.eats) | TikTok">
<meta property="og:image" content="https://p16.tiktokcdn.com/avatar/mika-eats-1080.jpeg">
</head><body></body></html>`);

/**
 * An Instagram Reel: creator and caption, no title.
 *
 * Deliberately carries NO `og:see_also`. The previous fixture did, the code
 * read the creator out of it, and both passed — but Instagram does not serve
 * that tag on a post page, so the fixture was testing an invention. What is
 * here instead is what Instagram actually publishes: the creator in
 * `og:title`, and a JSON-LD block with the author and their avatar.
 */
const INSTAGRAM_PAGE = html(`<!doctype html><html><head>
<title>Nina Reyes on Instagram</title>
<meta property="og:type" content="video">
<meta property="og:url" content="https://www.instagram.com/reel/CxYzAbCdEfG/">
<meta property="og:title" content="Nina Reyes (@nina.reyes) • Instagram reel">
<meta property="og:description" content="1,284 likes, 56 comments - nina.reyes on March 2, 2024: &quot;Three days in Kyoto and the best meal was a ¥900 set lunch at Kissa Master in Gion. Go before 11am 🍵 @kissamaster #kyoto #japantravel&quot;">
<meta property="og:image" content="//scontent.cdninstagram.com/v/reel-CxYzAbCdEfG.jpg">
<script type="application/ld+json">
{"@context":"https://schema.org","@type":"VideoObject",
 "author":{"@type":"Person","name":"Nina Reyes","alternateName":"@nina.reyes",
           "url":"https://www.instagram.com/nina.reyes/",
           "image":"https://scontent.cdninstagram.com/v/avatar-nina.jpg?a=1\\u0026b=2"}}
</script>
</head><body></body></html>`);

/**
 * A Facebook Reel reached through fb.watch, which redirects.
 *
 * Facebook's shape is NOT Instagram's or TikTok's, which is why it could not
 * be fixed by whatever made those two work:
 *
 * - No keyless oEmbed at all, so there is no `author_name` and no
 *   `author_url` — the field the old code depended on first.
 * - No `og:see_also`, the field it fell back to.
 * - No handle anywhere in the markup, and none in a `/reel/<id>` URL.
 *
 * What it does publish is the author's display name in `og:title`, on its
 * own and undecorated. That is the only creator source here, and reading it
 * is the whole Facebook fix.
 */
const FACEBOOK_PAGE = html(`<!doctype html><html><head>
<title>Alex Cruz</title>
<meta property="og:type" content="video.other">
<meta property="og:url" content="https://www.facebook.com/reel/1234567890">
<meta property="og:title" content="Alex Cruz">
<meta property="og:description" content="Sagada in two days: ₱800 for the cave tour, ₱2,500 a night at a homestay near the centre. The sunrise at Kiltepan is worth the 4am start 🌄">
<meta property="og:image" content="https://scontent.xx.fbcdn.net/v/reel-1234567890.jpg?a=1&amp;b=2">
</head><body></body></html>`);

const FACEBOOK_PROFILE = html(`<!doctype html><html><head>
<meta property="og:title" content="Alex Cruz">
<meta property="og:image" content="https://scontent.xx.fbcdn.net/v/avatar-alex-cruz.jpg">
</head><body></body></html>`);

/** YouTube, which has a real title and a description. */
const YOUTUBE_PAGE = html(`<!doctype html><html><head>
<title>5 Hidden Cafes in Kyoto - YouTube</title>
<meta property="og:type" content="video.other">
<meta property="og:url" content="https://www.youtube.com/watch?v=dQw4w9WgXcQ">
<meta property="og:title" content="5 Hidden Cafes in Kyoto">
<meta property="og:description" content="Five small coffee bars in Kyoto, all within a short walk of each other.">
<meta property="og:image" content="https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg">
</head><body></body></html>`);

const YOUTUBE_OEMBED = jsonOk({
  title: '5 Hidden Cafes in Kyoto',
  author_name: 'Wander With Mia',
  author_url: 'https://www.youtube.com/@wanderwithmia',
  type: 'video',
  thumbnail_url: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
});

/** What Instagram serves for a private or deleted post. */
const LOGIN_WALL = html(`<!doctype html><html><head>
<title>Login • Instagram</title>
<meta property="og:title" content="Log in or sign up to view">
<meta property="og:description" content="Log in to see photos and videos from friends.">
</head><body></body></html>`);

// --- the guard -------------------------------------------------------------

test('only the four platforms may be fetched', () => {
  for (const ok of [
    'https://www.tiktok.com/@a/video/1',
    'https://vt.tiktok.com/ZSAbCdEf/',
    'https://www.instagram.com/reel/abc/',
    'https://www.facebook.com/reel/1',
    'https://fb.watch/aBcDeFgHiJ/',
    'https://youtu.be/dQw4w9WgXcQ',
  ]) {
    assert.equal(isFetchable(ok), true, ok);
  }

  // This endpoint is public and takes a URL, so without an allowlist it is an
  // open proxy. The cloud metadata address is the one that matters most.
  for (const no of [
    'http://169.254.169.254/latest/meta-data/',
    'http://localhost:8787/health',
    'http://127.0.0.1/',
    'https://internal.corp/secrets',
    'file:///etc/passwd',
    'gopher://tiktok.com/',
    'https://user:pass@www.tiktok.com/@a/video/1',
    'https://tiktok.com.evil.test/@a/video/1',
    'not a url',
    '',
  ]) {
    assert.equal(isFetchable(no), false, no);
  }
});

test('a redirect off the allowlist is refused rather than followed', async () => {
  const fetchImpl = async (url) => {
    if (url.includes('fb.watch')) {
      return new Response(null, {
        status: 302,
        headers: { location: 'http://169.254.169.254/latest/meta-data/' },
      });
    }
    return html('<html></html>');
  };

  await assert.rejects(
    () => readMetadata('https://fb.watch/aBcDeFgHiJ/', { fetchImpl, withAvatar: false }),
    /Refusing to follow a redirect/,
  );
});

test('a URL that is not a supported post is refused with a reason', async () => {
  await assert.rejects(
    () => readMetadata('https://example.com/blog/post', { fetchImpl: stubFetch({}) }),
    /not a post on a platform this service reads/,
  );
  await assert.rejects(() => readMetadata('', { fetchImpl: stubFetch({}) }), /required/);
});

test('platforms are identified from the host', () => {
  assert.equal(platformOf('https://vt.tiktok.com/ZSAbCdEf/'), 'tiktok');
  assert.equal(platformOf('https://www.instagram.com/reel/a/'), 'instagram');
  assert.equal(platformOf('https://fb.watch/a/'), 'facebook');
  assert.equal(platformOf('https://youtu.be/a'), 'youtube');
  assert.equal(platformOf('https://example.com/'), 'other');
  assert.equal(platformOf('nonsense'), 'other');
});

// --- parsing ---------------------------------------------------------------

test('meta tags are read whatever order the attributes come in', () => {
  const tags = parseMetaTags(
    '<meta content="first" property="og:title">' +
      '<meta property="og:description" content="second"/>' +
      "<meta name='twitter:image' content='third'>" +
      '<title>fourth</title>',
  );
  assert.equal(tags['og:title'], 'first');
  assert.equal(tags['og:description'], 'second');
  assert.equal(tags['twitter:image'], 'third');
  assert.equal(tags['<title>'], 'fourth');
});

test('entities are decoded, so a caption is not full of &amp;', () => {
  assert.equal(decodeEntities('Tea &amp; cake &quot;here&quot;'), 'Tea & cake "here"');
  assert.equal(decodeEntities('&#8364;20 &#x20AC;20'), '€20 €20');
  assert.equal(decodeEntities('plain'), 'plain');
});

test('hashtags come out in order, de-duplicated, in any script', () => {
  assert.deepEqual(hashtagsFrom('#baguio #food #baguio #BAGUIO'), ['baguio', 'food']);
  assert.deepEqual(hashtagsFrom('#京都 #kyoto'), ['京都', 'kyoto']);
  assert.deepEqual(hashtagsFrom('no tags here'), []);
  assert.deepEqual(hashtagsFrom(null), []);
});

test('the engagement wrapper is stripped off a caption, and only that', () => {
  assert.equal(
    captionFromOgDescription('2.1M likes, 4300 comments. "Good Taste Baguio, open 24h"', 'tiktok'),
    'Good Taste Baguio, open 24h',
  );
  assert.equal(
    captionFromOgDescription(
      '1,284 likes, 56 comments - nina on March 2, 2024: "A ¥900 set lunch in Gion"',
      'instagram',
    ),
    'A ¥900 set lunch in Gion',
  );
  // No wrapper: the description IS the caption and must survive whole.
  assert.equal(
    captionFromOgDescription('Sagada in two days: ₱800 for the cave tour.', 'facebook'),
    'Sagada in two days: ₱800 for the cave tour.',
  );
  assert.equal(captionFromOgDescription('', 'tiktok'), null);
  assert.equal(captionFromOgDescription(null, 'tiktok'), null);
});

test('an image URL is made safe or dropped', () => {
  assert.equal(
    normaliseImageUrl('//cdn.example.com/a.jpg', 'https://www.instagram.com/reel/x/'),
    'https://cdn.example.com/a.jpg',
  );
  assert.equal(
    normaliseImageUrl('/static/a.jpg', 'https://www.facebook.com/reel/1'),
    'https://www.facebook.com/static/a.jpg',
  );
  assert.equal(normaliseImageUrl('https://cdn.example.com/a.jpg'), 'https://cdn.example.com/a.jpg');
  for (const bad of ['javascript:alert(1)', 'data:image/png;base64,AAA', '', '   ', null, 42]) {
    assert.equal(normaliseImageUrl(bad), null, String(bad));
  }
});

test('a sign-in page is recognised as one', () => {
  assert.equal(looksLikeLoginWall(parseMetaTags(''), '<title>Login • Instagram</title>'), true);
  assert.equal(
    looksLikeLoginWall({ 'og:title': 'Log in or sign up to view' }, ''),
    true,
  );
  assert.equal(looksLikeLoginWall({ 'og:title': '5 Hidden Cafes in Kyoto' }, ''), false);
});

// --- the four platforms, end to end ---------------------------------------

test('TikTok: a caption with a place, no title, and a real avatar', async () => {
  const result = await readMetadata('https://www.tiktok.com/@mika.eats/video/7311223344556677889', {
    fetchImpl: stubFetch({
      '/oembed': TIKTOK_OEMBED,
      '/@mika.eats/video/': TIKTOK_PAGE,
      '/@mika.eats': TIKTOK_PROFILE,
    }),
  });

  assert.equal(result.platform, 'tiktok');
  assert.equal(result.fetched, true);
  // The caption is the post. It must arrive whole, with the price in it.
  assert.match(result.caption, /Good Taste Baguio/);
  assert.match(result.caption, /₱150/);
  // And it must NOT have become the title.
  assert.equal(result.title, null, 'a caption is not a title');
  assert.equal(result.creator, 'Mika Eats');
  assert.equal(result.creatorHandle, '@mika.eats');
  assert.equal(result.creatorUrl, 'https://www.tiktok.com/@mika.eats');
  // The avatar is the profile page's og:image, never the post thumbnail.
  assert.equal(result.creatorAvatarUrl, 'https://p16.tiktokcdn.com/avatar/mika-eats-1080.jpeg');
  assert.notEqual(result.creatorAvatarUrl, result.thumbnailUrl);
  assert.deepEqual(result.hashtags, ['baguio', 'baguiofood', 'foodtrip', 'fyp']);
  assert.equal(result.mediaType, 'video');
});

test('Instagram: a Reel with creator and caption but no title', async () => {
  const log = [];
  const result = await readMetadata('https://www.instagram.com/reel/CxYzAbCdEfG/', {
    fetchImpl: stubFetch({ '/reel/CxYzAbCdEfG': INSTAGRAM_PAGE }, { log }),
  });

  assert.equal(result.fetched, true);
  assert.match(result.caption, /Kissa Master/);
  assert.match(result.caption, /¥900/);
  // Emoji, a mention and hashtags all survive the caption intact.
  assert.match(result.caption, /🍵/);
  assert.match(result.caption, /@kissamaster/);
  assert.deepEqual(result.hashtags, ['kyoto', 'japantravel']);

  // The byline Instagram puts in og:title must not become the title.
  assert.ok(
    result.title === null || !/on Instagram|Instagram reel/.test(result.title),
    `a byline is not a title: ${result.title}`,
  );

  // Creator from the sources Instagram really publishes.
  assert.equal(result.creator, 'Nina Reyes');
  assert.equal(result.creatorHandle, '@nina.reyes');
  assert.equal(result.creatorUrl, 'https://www.instagram.com/nina.reyes/');

  // The avatar comes out of JSON-LD, with its `\u0026` unescaped — handed over
  // escaped it 403s, because the query asked for is not the query signed.
  assert.equal(
    result.creatorAvatarUrl,
    'https://scontent.cdninstagram.com/v/avatar-nina.jpg?a=1&b=2',
  );
  assert.equal(result.sources.creatorAvatarUrl, 'ld+json');
  assert.notEqual(result.creatorAvatarUrl, result.thumbnailUrl);

  // Protocol-relative og:image resolved rather than handed over broken.
  assert.equal(result.thumbnailUrl, 'https://scontent.cdninstagram.com/v/reel-CxYzAbCdEfG.jpg');

  // And the page itself was enough: no second request for a profile page.
  assert.equal(
    log.filter((url) => url.endsWith('/nina.reyes/')).length,
    0,
    'the avatar was on the post page, so the extra fetch is skipped',
  );
});

test('Facebook: a short link is resolved, and the creator is read', async () => {
  const log = [];
  const fetchImpl = async (url) => {
    log.push(url);
    if (url.includes('fb.watch')) {
      return new Response(null, {
        status: 301,
        headers: { location: 'https://www.facebook.com/reel/1234567890' },
      });
    }
    if (url.includes('/alex.cruz.travels')) return FACEBOOK_PROFILE();
    if (url.includes('/reel/1234567890')) return FACEBOOK_PAGE();
    return new Response('nope', { status: 404 });
  };

  const result = await readMetadata('https://fb.watch/aBcDeFgHiJ/', { fetchImpl });

  assert.equal(result.platform, 'facebook');
  assert.equal(result.fetched, true, 'Facebook must read like the others, not worse');

  // THE reported bug. Facebook publishes no keyless oEmbed and no
  // `og:see_also`, which were the only two sources the old code had, so the
  // creator came back null on every Facebook post. `og:title` is where the
  // author's name actually is.
  assert.equal(result.creator, 'Alex Cruz');
  assert.equal(result.sources.creator, 'og:title');

  // There is genuinely no handle in Facebook's markup or in a /reel/<id> URL.
  // Null is the honest answer; inventing one from the share code is not.
  assert.equal(result.creatorHandle, null);

  assert.match(result.caption, /Sagada in two days/);
  assert.match(result.caption, /₱800/);
  assert.match(result.caption, /🌄/, 'an emoji in the caption survives');
  assert.equal(result.canonicalUrl, 'https://www.facebook.com/reel/1234567890');
  assert.equal(result.mediaType, 'video');

  // `&amp;` in the og:image unescaped, or the CDN rejects the query.
  assert.equal(
    result.thumbnailUrl,
    'https://scontent.xx.fbcdn.net/v/reel-1234567890.jpg?a=1&b=2',
  );

  assert.ok(
    log.some((url) => url.includes('/reel/1234567890')),
    'the redirect was followed to the real post',
  );
});

test('YouTube keeps working, with its real title under its description', async () => {
  const result = await readMetadata('https://www.youtube.com/watch?v=dQw4w9WgXcQ', {
    fetchImpl: stubFetch({
      '/oembed': YOUTUBE_OEMBED,
      'watch?v=dQw4w9WgXcQ': YOUTUBE_PAGE,
      '/@wanderwithmia': html('<meta property="og:image" content="https://cdn.test/mia.jpg">'),
    }),
  });

  assert.equal(result.platform, 'youtube');
  assert.equal(result.title, '5 Hidden Cafes in Kyoto', 'YouTube has real titles');
  assert.match(result.caption, /Five small coffee bars/);
  assert.equal(result.creator, 'Wander With Mia');
  assert.equal(result.creatorHandle, '@wanderwithmia');
  assert.equal(result.mediaType, 'video');
});

// --- the honest failures ---------------------------------------------------

test('a private post is reported as private, not as an empty post', async () => {
  const result = await readMetadata('https://www.instagram.com/p/PrivateAbc/', {
    fetchImpl: stubFetch({ instagram: LOGIN_WALL }),
  });

  assert.equal(result.fetched, false);
  assert.match(result.reason, /not public/);
  assert.equal(result.caption, null);
  assert.equal(result.title, null);
  assert.equal(result.creatorAvatarUrl, null);
});

test('a deleted post says so', async () => {
  const result = await readMetadata('https://www.tiktok.com/@gone/video/1', {
    fetchImpl: stubFetch({ '': () => new Response('gone', { status: 404 }) }),
  });

  assert.equal(result.fetched, false);
  assert.match(result.reason, /no longer exists|nothing readable/);
});

test('partial metadata is kept rather than discarded', async () => {
  // oEmbed answers, the page does not. Half an answer is still an answer.
  const result = await readMetadata('https://www.tiktok.com/@mika.eats/video/7311223344556677889', {
    fetchImpl: stubFetch({
      '/oembed': TIKTOK_OEMBED,
      '': () => new Response('error', { status: 500 }),
    }),
    withAvatar: false,
  });

  assert.equal(result.fetched, true);
  assert.equal(result.creator, 'Mika Eats');
  assert.match(result.caption, /Good Taste Baguio/);
  assert.equal(result.thumbnailUrl, 'https://p16.tiktokcdn.com/obj/7311223344556677889.jpeg');
});

test('a missing avatar leaves the field null rather than borrowing the thumbnail', async () => {
  const result = await readMetadata('https://www.tiktok.com/@mika.eats/video/7311223344556677889', {
    fetchImpl: stubFetch({
      '/oembed': TIKTOK_OEMBED,
      '/@mika.eats/video/': TIKTOK_PAGE,
      // The profile page refuses. The post still reads; the avatar does not.
      '/@mika.eats': () => new Response('denied', { status: 403 }),
    }),
  });

  assert.equal(result.fetched, true);
  assert.equal(result.creatorAvatarUrl, null, 'no face is better than the wrong face');
  assert.ok(result.thumbnailUrl, 'the post thumbnail is unaffected');
});

test('a malformed avatar URL is dropped, not passed through', async () => {
  const result = await readMetadata('https://www.tiktok.com/@mika.eats/video/1', {
    fetchImpl: stubFetch({
      '/oembed': TIKTOK_OEMBED,
      '/@mika.eats/video/': TIKTOK_PAGE,
      '/@mika.eats': () =>
        html('<meta property="og:image" content="javascript:alert(document.cookie)">'),
    }),
  });

  assert.equal(result.creatorAvatarUrl, null);
});

test('an avatar is not fetched when it was not asked for', async () => {
  const log = [];
  await readMetadata('https://www.tiktok.com/@mika.eats/video/1', {
    fetchImpl: stubFetch(
      { '/oembed': TIKTOK_OEMBED, '': TIKTOK_PAGE },
      { log },
    ),
    withAvatar: false,
  });

  assert.equal(
    log.filter((url) => url === 'https://www.tiktok.com/@mika.eats').length,
    0,
    'one request saved per save when the caller does not want the avatar',
  );
});

test('no credential of any kind is sent', async () => {
  const seen = [];
  const fetchImpl = async (url, init) => {
    seen.push(init?.headers ?? {});
    return TIKTOK_PAGE();
  };

  await readMetadata('https://www.tiktok.com/@a/video/1', { fetchImpl, withAvatar: false });

  assert.ok(seen.length > 0);
  for (const headers of seen) {
    const keys = Object.keys(headers).map((k) => k.toLowerCase());
    for (const forbidden of ['cookie', 'authorization', 'x-api-key', 'access_token']) {
      assert.ok(!keys.includes(forbidden), `${forbidden} must never be sent`);
    }
    // And it says who it is rather than pretending to be a browser.
    assert.match(headers['user-agent'], /NookBot/);
  }
});

// --- the sources each platform really publishes ---------------------------
//
// The previous round's fixtures carried `og:see_also` and the code read the
// creator out of it. Both passed. Neither Instagram nor Facebook serves that
// tag on a post page, so the fixtures were testing an invention and the live
// app got nothing — the same shape of mistake as the extraction tool name.
//
// These tests pin the sources that are actually there, one per platform,
// because the three are not interchangeable.

test('og:title is read per platform, and the patterns are not shared', () => {
  // Instagram and TikTok: `Name (@handle)`.
  assert.deepEqual(creatorFromOgTitle('Nina Reyes (@nina.reyes) • Instagram reel', 'instagram'), {
    name: 'Nina Reyes',
    handle: '@nina.reyes',
  });
  assert.deepEqual(creatorFromOgTitle('Mika Eats (@mika.eats) | TikTok', 'tiktok'), {
    name: 'Mika Eats',
    handle: '@mika.eats',
  });

  // `Name on <platform>` — no handle published.
  assert.deepEqual(creatorFromOgTitle('Nina Reyes on Instagram: "three days"', 'instagram'), {
    name: 'Nina Reyes',
  });

  // Facebook: the display name on its own. Nothing to strip, no handle.
  assert.deepEqual(creatorFromOgTitle('Alex Cruz', 'facebook'), { name: 'Alex Cruz' });
  assert.deepEqual(creatorFromOgTitle('Alex Cruz | Facebook', 'facebook'), {
    name: 'Alex Cruz',
  });

  // But Facebook also puts the post body there, and prose is not a name.
  assert.equal(
    creatorFromOgTitle('Sagada in two days: ₱800 for the cave tour, go early!', 'facebook'),
    null,
  );
  assert.equal(creatorFromOgTitle('Check out my trip #sagada', 'facebook'), null);

  // Boilerplate is never a creator.
  assert.equal(creatorFromOgTitle('Log in to Facebook', 'facebook'), null);
  assert.equal(creatorFromOgTitle('', 'facebook'), null);
  assert.equal(creatorFromOgTitle(null, 'facebook'), null);
});

test('JSON-LD is read for the creator and the avatar', () => {
  const nodes = parseJsonLd(`
    <script type="application/ld+json">
    {"@context":"https://schema.org","@graph":[
      {"@type":"VideoObject","caption":"A ¥900 set lunch in Gion",
       "author":{"@type":"Person","name":"Nina Reyes","alternateName":"@nina.reyes",
                 "url":"https://www.instagram.com/nina.reyes/",
                 "image":"https://cdn.test/avatar.jpg?a=1\\u0026b=2"}}]}
    </script>`);

  assert.equal(nodes.length, 2, '@graph is flattened, and its members kept');
  const creator = creatorFromJsonLd(nodes);
  assert.equal(creator.name, 'Nina Reyes');
  assert.equal(creator.handle, '@nina.reyes');
  assert.equal(creator.url, 'https://www.instagram.com/nina.reyes/');
  assert.equal(captionFromJsonLd(nodes), 'A ¥900 set lunch in Gion');
});

test('a malformed JSON-LD block does not lose the good ones', () => {
  const nodes = parseJsonLd(`
    <script type="application/ld+json">{ this is not json </script>
    <script type="application/ld+json">{"author":{"name":"Alex Cruz"}}</script>`);

  assert.equal(creatorFromJsonLd(nodes).name, 'Alex Cruz');
});

test('no structured data at all yields null, not a crash', () => {
  assert.deepEqual(parseJsonLd('<html><head></head></html>'), []);
  assert.equal(creatorFromJsonLd([]), null);
  assert.equal(captionFromJsonLd([]), null);
  assert.equal(avatarFromEmbeddedJson(''), null);
});

test('platform boilerplate is never mistaken for a caption', () => {
  for (const blurb of [
    'See posts, photos and more on Facebook.',
    'Log in to Facebook',
    'Join Facebook to connect with Alex Cruz',
    '1,284 followers, 318 following, 94 posts - See Instagram photos and videos from Nina',
    'See Instagram photos and videos from Nina Reyes',
    'TikTok - Make Your Day',
    'Discover videos related to Baguio on TikTok',
    '',
    null,
  ]) {
    assert.equal(isBoilerplate(blurb), true, String(blurb));
  }
  assert.equal(isBoilerplate('₱150 unlimited wings at Good Taste Baguio'), false);
});

test('an escaped or entity-encoded image URL is unescaped', () => {
  assert.equal(unescapeUrl('https://cdn/x.jpg?a=1\\u0026b=2'), 'https://cdn/x.jpg?a=1&b=2');
  assert.equal(unescapeUrl('https://cdn/x.jpg?a=1&amp;b=2'), 'https://cdn/x.jpg?a=1&b=2');
  assert.equal(unescapeUrl('https:\\/\\/cdn\\/x.jpg'), 'https://cdn/x.jpg');
  assert.equal(unescapeUrl(null), null);
});

test('an avatar is read out of the platform embedded state blob', () => {
  // TikTok ships the page state in a script tag; the avatar is in there under
  // a stable key even when the meta tags carry none.
  assert.equal(
    avatarFromEmbeddedJson('{"user":{"avatarLarger":"https://p16.test/a.jpg?x=1\\u0026y=2"}}'),
    'https://p16.test/a.jpg?x=1&y=2',
  );
  assert.equal(
    avatarFromEmbeddedJson('{"owner":{"profile_pic_url_hd":"https://scontent.test/p.jpg"}}'),
    'https://scontent.test/p.jpg',
  );
  // Not a URL: refused rather than handed to the UI.
  assert.equal(avatarFromEmbeddedJson('{"avatarLarger":"/relative/only.jpg"}'), null);
});

test('a profile URL is derived from a handle, per platform', () => {
  assert.equal(profileUrlFor('@mika.eats', 'tiktok'), 'https://www.tiktok.com/@mika.eats');
  assert.equal(profileUrlFor('nina.reyes', 'instagram'), 'https://www.instagram.com/nina.reyes/');
  assert.equal(profileUrlFor('@alex.cruz', 'facebook'), 'https://www.facebook.com/alex.cruz');
  // Nothing injectable becomes a URL.
  for (const bad of ['', '@', 'a/../b', 'a b', '@x?y=1', null]) {
    assert.equal(profileUrlFor(bad, 'tiktok'), null, String(bad));
  }
});

test('provenance says where every field came from', async () => {
  const result = await readMetadata('https://www.instagram.com/reel/CxYzAbCdEfG/', {
    fetchImpl: stubFetch({ '/reel/': INSTAGRAM_PAGE }),
  });

  // The point of this field: a null is otherwise indistinguishable from the
  // platform not publishing it, from a wall, and from a parser bug.
  // JSON-LD before og:title: it names the author explicitly, where og:title
  // has to be pattern-matched out of a decorated string.
  assert.equal(result.sources.creator, 'ld+json');
  assert.equal(result.sources.caption, 'og:description');
  assert.equal(result.sources.creatorAvatarUrl, 'ld+json');
  assert.equal(result.sources.thumbnailUrl, 'og:image');
  assert.equal(result.diagnostics.pageStatus, 200);
  assert.equal(result.diagnostics.jsonLdBlocks > 0, true);
  assert.equal(result.diagnostics.loginWall, false);
});

test('an avatar equal to the post thumbnail is rejected', async () => {
  // A page whose profile lookup returns the post's own cover. Showing that as
  // a face is worse than showing the initial.
  const page = html(
    '<meta property="og:title" content="Mika Eats (@mika.eats) | TikTok">' +
      '<meta property="og:description" content="wings in Baguio">' +
      '<meta property="og:image" content="https://cdn.test/same.jpg">',
  );
  const result = await readMetadata('https://www.tiktok.com/@mika.eats/video/1', {
    fetchImpl: stubFetch({
      '/oembed': () => new Response('no', { status: 404 }),
      '/@mika.eats/video/': page,
      '/@mika.eats': html('<meta property="og:image" content="https://cdn.test/same.jpg">'),
    }),
  });

  assert.equal(result.creatorAvatarUrl, null);
  assert.match(result.sources.creatorAvatarUrl, /rejected/);
  assert.equal(result.thumbnailUrl, 'https://cdn.test/same.jpg');
});

test('a generic title with a meaningful caption keeps both apart', async () => {
  const page = html(
    '<meta property="og:title" content="TikTok - Make Your Day">' +
      '<meta property="og:description" content="2 likes. &quot;Lunch at Good Taste in Baguio City, ₱150 unlimited 🍗 #baguio&quot;">',
  );
  const result = await readMetadata('https://www.tiktok.com/@mika.eats/video/1', {
    fetchImpl: stubFetch({
      '/oembed': () => new Response('no', { status: 404 }),
      '': page,
    }),
    withAvatar: false,
  });

  // The generic platform title is boilerplate and must not become the title.
  assert.equal(result.title, null);
  assert.match(result.caption, /Good Taste in Baguio City/);
  assert.match(result.caption, /₱150/);
  assert.deepEqual(result.hashtags, ['baguio']);
  assert.equal(result.fetched, true, 'a caption alone is a readable post');
});

test('partially available metadata keeps what there is', async () => {
  // og:description only: no title, no creator, no image, no oEmbed.
  const result = await readMetadata('https://www.facebook.com/reel/99', {
    fetchImpl: stubFetch({
      '': html('<meta property="og:description" content="Two days in Sagada, ₱800 cave tour">'),
    }),
  });

  assert.equal(result.fetched, true);
  assert.match(result.caption, /Sagada/);
  assert.equal(result.creator, null);
  assert.equal(result.creatorAvatarUrl, null);
  assert.equal(result.thumbnailUrl, null);
});

test('an empty or malformed response is not a crash', async () => {
  for (const body of ['', '<html>', 'not html at all', '<meta property="og:title">']) {
    const result = await readMetadata('https://www.tiktok.com/@a/video/1', {
      fetchImpl: stubFetch({ '': () => new Response(body, { status: 200 }) }),
      withAvatar: false,
    });
    assert.equal(typeof result.fetched, 'boolean', JSON.stringify(body));
  }
});

// --- the two posts that were tested against the live Worker ---------------
//
// Both failed the same way, and these fixtures are built from what the
// deployed service actually returned for them rather than from what these
// pages were assumed to look like. The caption and the thumbnail came back
// fine in both cases; only the creator fields were empty, and in both cases
// the account name was sitting in the URL the whole time.

/** instagram.com/forbestravelguide/reel/DMpu7-9ue06/ — name but no handle. */
const IG_REEL_WITH_USER_IN_PATH = html(`<!doctype html><html><head>
<meta property="og:type" content="video">
<meta property="og:title" content="Forbes Travel Guide on Instagram: &quot;Sunset over El Nido&quot;">
<meta property="og:description" content="412 likes, 18 comments - forbestravelguide on July 28, 2025: &quot;Golden hour in El Nido, Palawan 🌅 Island hopping from Corong-Corong beach, ₱1,800 per person for Tour A. #elnido #palawan #philippines&quot;">
<meta property="og:image" content="https://scontent.cdninstagram.com/v/reel-DMpu7.jpg">
<script type="application/ld+json">
{"@type":"VideoObject","author":{"@type":"Person","name":"Forbes Travel Guide",
 "image":"https://scontent.cdninstagram.com/v/avatar-ftg.jpg"}}
</script>
</head><body></body></html>`);

test('Instagram: the username in the path becomes the handle and the URL', async () => {
  // What the live service returned: creator "Forbes Travel Guide", caption and
  // avatar fine, and creatorHandle / creatorUrl / canonicalUrl all null —
  // while `forbestravelguide` sat in the URL that was passed in. JSON-LD here
  // carries the name and the avatar but no `alternateName` and no `url`, which
  // is why nothing downstream had a handle to work from.
  const asked = 'https://www.instagram.com/forbestravelguide/reel/DMpu7-9ue06/';
  const result = await readMetadata(asked, {
    fetchImpl: stubFetch({
      '/forbestravelguide/reel/': IG_REEL_WITH_USER_IN_PATH,
      '/forbestravelguide/': html(
        '<meta property="og:image" content="https://scontent.cdninstagram.com/v/avatar-ftg.jpg">',
      ),
    }),
  });

  assert.equal(result.creatorHandle, '@forbestravelguide');
  assert.equal(result.creatorUrl, 'https://www.instagram.com/forbestravelguide/');
  // This page publishes no `og:url`, so the canonical IS the pasted URL and
  // either label is the same string. The case where they differ is below.
  assert.ok(
    ['canonical url', 'url as pasted'].includes(result.sources.creatorHandle),
    result.sources.creatorHandle,
  );
  assert.equal(result.sources.creatorUrl, 'derived from handle');

  // The display name stays the published one. The handle must never be
  // promoted into it.
  assert.equal(result.creator, 'Forbes Travel Guide');
  assert.notEqual(result.creator, 'forbestravelguide');

  // And none of the fields that already worked are disturbed.
  assert.match(result.caption, /El Nido, Palawan/);
  assert.match(result.caption, /₱1,800/);
  assert.match(result.caption, /🌅/);
  assert.deepEqual(result.hashtags, ['elnido', 'palawan', 'philippines']);
  assert.equal(result.creatorAvatarUrl, 'https://scontent.cdninstagram.com/v/avatar-ftg.jpg');
  assert.equal(result.thumbnailUrl, 'https://scontent.cdninstagram.com/v/reel-DMpu7.jpg');
  assert.equal(result.title, null, 'a byline is not a title');
});

test('Instagram: an og:url that drops the username falls back to the pasted URL', async () => {
  // Instagram's own canonical for a reel is `/reel/<code>/` — the account is
  // not in it. Deriving the handle from the canonical alone therefore loses
  // the username that the URL the person pasted was carrying all along, which
  // is why both are tried.
  const page = html(`<!doctype html><html><head>
<meta property="og:url" content="https://www.instagram.com/reel/DMpu7-9ue06/">
<meta property="og:title" content="Forbes Travel Guide on Instagram">
<meta property="og:description" content="412 likes - forbestravelguide: &quot;Golden hour in El Nido&quot;">
</head><body></body></html>`);

  const result = await readMetadata(
    'https://www.instagram.com/forbestravelguide/reel/DMpu7-9ue06/',
    { fetchImpl: stubFetch({ '': page }), withAvatar: false },
  );

  assert.equal(result.creatorHandle, '@forbestravelguide');
  assert.equal(result.sources.creatorHandle, 'url as pasted');
  assert.equal(result.creatorUrl, 'https://www.instagram.com/forbestravelguide/');
});

test('Instagram: a reel URL without a username still yields no handle', async () => {
  // `/reel/<code>/` carries no account, and inventing one from the code would
  // be a fabricated creator.
  const result = await readMetadata('https://www.instagram.com/reel/DMpu7-9ue06/', {
    fetchImpl: stubFetch({ '': IG_REEL_WITH_USER_IN_PATH }),
    withAvatar: false,
  });

  assert.equal(result.creatorHandle, null);
  assert.equal(result.creatorUrl, null);
  // The name the page published is still there.
  assert.equal(result.creator, 'Forbes Travel Guide');
});

/**
 * facebook.com/share/r/14twxTeWCtK/ — the share link, which redirects to a
 * canonical video URL carrying the page's vanity name.
 *
 * The post's own `og:title` is the video's text, not a name, which is why no
 * display name can be read from the post page: `creatorFromOgTitle` refuses
 * prose, correctly. The page's name is on the page's own profile.
 */
const FB_VIDEO_PAGE = html(`<!doctype html><html><head>
<meta property="og:type" content="video.other">
<meta property="og:url" content="https://www.facebook.com/1Nesh.D/videos/el-nido-palawan-philippines-el-nido-on-the-island-of-palawan-in-the-philippines-/691651166719048/">
<meta property="og:title" content="El Nido Palawan Philippines. El Nido on the island of Palawan in the Philippines is one of the most beautiful places on earth.">
<meta property="og:description" content="El Nido Palawan Philippines 🏝️ El Nido on the island of Palawan in the Philippines is one of the most beautiful places on earth. Tour A is ₱1,400.">
<meta property="og:image" content="https://scontent.xx.fbcdn.net/v/t15/691651166719048.jpg?a=1&amp;b=2">
</head><body></body></html>`);

test('Facebook: the share link resolves and the page identifier is read', async () => {
  // What the live service returned for this exact post: caption and thumbnail
  // fine, canonicalUrl resolved to `/1Nesh.D/videos/...`, and creator,
  // creatorHandle, creatorUrl and creatorAvatarUrl all null — with `1Nesh.D`
  // sitting in that canonical URL.
  const log = [];
  const fetchImpl = async (url) => {
    log.push(url);
    if (url.includes('/share/r/')) {
      return new Response(null, {
        status: 302,
        headers: {
          location:
            'https://www.facebook.com/1Nesh.D/videos/el-nido-palawan-philippines-el-nido-on-the-island-of-palawan-in-the-philippines-/691651166719048/',
        },
      });
    }
    if (/facebook\.com\/1Nesh\.D\/?$/.test(url)) {
      return html(
        '<meta property="og:title" content="Nesh D">' +
          '<meta property="og:image" content="https://scontent.xx.fbcdn.net/v/avatar-nesh.jpg">',
      )();
    }
    if (url.includes('/videos/')) return FB_VIDEO_PAGE();
    return new Response('not found', { status: 404 });
  };

  const result = await readMetadata(
    'https://www.facebook.com/share/r/14twxTeWCtK/?mibextid=wwXIfr',
    { fetchImpl },
  );

  // The page identifier, from the canonical the share link redirected to.
  assert.equal(result.creatorHandle, '@1Nesh.D');
  assert.equal(result.creatorUrl, 'https://www.facebook.com/1Nesh.D');
  assert.equal(result.sources.creatorHandle, 'canonical url');

  // The display name comes from the page's own profile, which is the only
  // place Facebook publishes one for a video post — the post's og:title is
  // the video's text.
  assert.equal(result.creator, 'Nesh D');
  assert.equal(result.sources.creator, 'profile page og:title');
  assert.equal(result.creatorAvatarUrl, 'https://scontent.xx.fbcdn.net/v/avatar-nesh.jpg');

  // Caption and thumbnail were never dependent on any of that.
  assert.match(result.caption, /El Nido/);
  assert.match(result.caption, /Palawan/);
  assert.match(result.caption, /₱1,400/);
  assert.equal(
    result.thumbnailUrl,
    'https://scontent.xx.fbcdn.net/v/t15/691651166719048.jpg?a=1&b=2',
  );
  assert.equal(result.title, null, 'the post text is not a title');
  assert.ok(result.canonicalUrl.includes('/1Nesh.D/videos/'));
});

test('Facebook: a prose og:title never becomes a display name', async () => {
  // With no profile page to read, the name stays null rather than becoming the
  // first sentence of the video.
  const result = await readMetadata(
    'https://www.facebook.com/1Nesh.D/videos/el-nido/691651166719048/',
    {
      fetchImpl: stubFetch({
        '/videos/': FB_VIDEO_PAGE,
        '': () => new Response('denied', { status: 403 }),
      }),
    },
  );

  assert.equal(result.creator, null, 'a sentence is not a name');
  // But the identifier from the URL is real and is kept.
  assert.equal(result.creatorHandle, '@1Nesh.D');
  assert.match(result.caption, /El Nido/);
  assert.ok(
    result.fallbacks.some((line) => line.includes('profile page')),
    'the attempt and its outcome are recorded',
  );
});

test('Facebook: every link shape is handled', async () => {
  const shapes = {
    'https://www.facebook.com/1Nesh.D/videos/el-nido/691651166719048/': '@1Nesh.D',
    'https://www.facebook.com/1Nesh.D/posts/pfbid0abc123': '@1Nesh.D',
    'https://m.facebook.com/1Nesh.D/videos/691651166719048/': '@1Nesh.D',
    'https://www.facebook.com/reel/691651166719048': null,
    'https://www.facebook.com/watch/?v=691651166719048': null,
    'https://www.facebook.com/share/r/14twxTeWCtK/': null,
    'https://fb.watch/aBcDeFgHiJ/': null,
    'https://www.facebook.com/profile.php?id=100064': null,
  };

  for (const [url, expected] of Object.entries(shapes)) {
    const result = await readMetadata(url, {
      fetchImpl: stubFetch({ '': () => new Response('<html></html>', { status: 200 }) }),
      withAvatar: false,
    });
    assert.equal(result.creatorHandle, expected, url);
  }
});

test('a caption survives when every creator field fails', async () => {
  // The guarantee: creator extraction failing must never cost the caption,
  // which is where the destination is.
  const result = await readMetadata('https://www.facebook.com/share/r/abc/', {
    fetchImpl: stubFetch({
      '': html(
        '<meta property="og:description" content="El Nido Palawan Philippines 🏝️ Tour A is ₱1,400.">',
      ),
    }),
  });

  assert.equal(result.creator, null);
  assert.equal(result.creatorHandle, null);
  assert.equal(result.creatorAvatarUrl, null);
  assert.match(result.caption, /El Nido Palawan Philippines/);
  assert.equal(result.fetched, true, 'a caption alone is a readable post');
});

test('a malformed URL produces no profile information at all', async () => {
  for (const url of [
    'https://www.instagram.com//reel//',
    'https://www.facebook.com/',
    'https://www.instagram.com/%20/reel/abc/',
  ]) {
    const result = await readMetadata(url, {
      fetchImpl: stubFetch({ '': () => new Response('<html></html>', { status: 200 }) }),
      withAvatar: false,
    });
    assert.equal(result.creator, null, url);
    assert.equal(result.creatorAvatarUrl, null, url);
  }
});

// --- the Facebook display name and avatar --------------------------------
//
// After the handle fix the live service returned `@1Nesh.D` and the profile
// URL, with `creator` and `creatorAvatarUrl` still null and a fallback line
// reading `profile page (...): read`.
//
// Two things were wrong, and the diagnostic hid the second:
//
// 1. `read` was returned for any 200 that was not a detected login wall,
//    whether or not anything had been extracted. It meant "a page came back",
//    which in a log is indistinguishable from success.
// 2. `looksLikeProse` rejected any string containing a full stop, so every
//    name with one in it was discarded — including this page's own, `1Nesh.D`.

test('a name with a full stop in it is a name', () => {
  // The page this was reported against is called `1Nesh.D`. Its own name was
  // the first thing the prose test threw away.
  for (const [title, expected] of Object.entries({
    '1Nesh.D': '1Nesh.D',
    '1Nesh.D | Facebook': '1Nesh.D',
    'Nesh D.': 'Nesh D.',
    'St. Nesh Travels': 'St. Nesh Travels',
    'Nesh D - Home | Facebook': 'Nesh D',
    'Nesh D - Videos | Facebook': 'Nesh D',
    'Nesh Dumlao Travel & Food': 'Nesh Dumlao Travel & Food',
    'Nesh D (@1Nesh.D) | Facebook': 'Nesh D',
  })) {
    assert.equal(creatorFromOgTitle(title, 'facebook')?.name, expected, title);
  }
});

test('post prose is still refused as a name', () => {
  for (const title of [
    'El Nido Palawan Philippines. El Nido on the island of Palawan in the Philippines is one of the most beautiful places.',
    'El Nido Palawan Philippines.',
    'Check out my trip #sagada',
    'Sagada in two days: 800 pesos for the cave tour, and go early in the morning!',
    'https://example.com/post',
  ]) {
    assert.equal(creatorFromOgTitle(title, 'facebook'), null, title);
  }
});

test('the wall wording is never read as a creator', () => {
  // Six ordinary words with no punctuation: it passes every prose test, so it
  // has to be refused by name.
  for (const title of [
    'Log in or sign up to view',
    'Log In or Sign Up',
    'Log into Facebook',
    'Sign up for Facebook',
    'Sign in to continue',
    'You must log in to continue',
  ]) {
    assert.equal(creatorFromOgTitle(title, 'facebook'), null, title);
    assert.equal(isBoilerplate(title), true, title);
  }
  // And a business whose name merely starts with one of those words is fine.
  for (const title of ['Login Travel Co', 'Signature Travels', 'Sign Co Manila']) {
    assert.ok(creatorFromOgTitle(title, 'facebook')?.name, title);
  }
});

test('Facebook: the display name and avatar come off the profile page', async () => {
  const fetchImpl = async (url) => {
    if (url.includes('/share/r/')) {
      return new Response(null, {
        status: 302,
        headers: {
          location: 'https://www.facebook.com/1Nesh.D/videos/el-nido/691651166719048/',
        },
      });
    }
    if (/facebook\.com\/1Nesh\.D\/?$/.test(url)) {
      // A page whose og:title is the vanity name, full stop included.
      return new Response(
        '<meta property="og:title" content="1Nesh.D | Facebook">' +
          '<meta property="og:image" content="https://scontent.xx.fbcdn.net/v/avatar-nesh.jpg?a=1&amp;b=2">',
        { status: 200 },
      );
    }
    return FB_VIDEO_PAGE();
  };

  const result = await readMetadata(
    'https://www.facebook.com/share/r/14twxTeWCtK/?mibextid=wwXIfr',
    { fetchImpl },
  );

  assert.equal(result.creator, '1Nesh.D');
  assert.equal(result.sources.creator, 'profile page og:title');
  assert.equal(
    result.creatorAvatarUrl,
    'https://scontent.xx.fbcdn.net/v/avatar-nesh.jpg?a=1&b=2',
  );
  assert.equal(result.sources.creatorAvatarUrl, 'profile page og:image');
  // The status says what it found, not merely that a page came back.
  assert.ok(
    result.fallbacks.some((line) => line.includes('read: name and avatar')),
    result.fallbacks.join(' | '),
  );

  // And the fields that were already working are untouched.
  assert.equal(result.creatorHandle, '@1Nesh.D');
  assert.equal(result.creatorUrl, 'https://www.facebook.com/1Nesh.D');
  assert.match(result.caption, /El Nido/);
  assert.ok(result.thumbnailUrl);
});

test('a profile page with only an avatar reports exactly that', async () => {
  const result = await readMetadata(
    'https://www.facebook.com/1Nesh.D/videos/el-nido/691651166719048/',
    {
      fetchImpl: stubFetch({
        '/videos/': FB_VIDEO_PAGE,
        '': () =>
          new Response(
            '<meta property="og:image" content="https://scontent.xx.fbcdn.net/v/a.jpg">',
            { status: 200 },
          ),
      }),
    },
  );

  assert.equal(result.creator, null, 'no name published, so none reported');
  assert.equal(result.creatorAvatarUrl, 'https://scontent.xx.fbcdn.net/v/a.jpg');
  assert.ok(
    result.fallbacks.some((line) => line.includes('read: avatar only')),
    result.fallbacks.join(' | '),
  );
});

test('a profile page that yields nothing says so, with what it did carry', async () => {
  // THE case the old `read` status hid. A 200 that is not a login wall and
  // carries nothing usable: the status now names the shortfall and quotes the
  // og:title it did find, which is what makes the next step obvious.
  const result = await readMetadata(
    'https://www.facebook.com/1Nesh.D/videos/el-nido/691651166719048/',
    {
      fetchImpl: stubFetch({
        '/videos/': FB_VIDEO_PAGE,
        '': () =>
          new Response(
            '<meta property="og:site_name" content="Facebook">' +
              '<meta property="og:title" content="Facebook">',
            { status: 200 },
          ),
      }),
    },
  );

  assert.equal(result.creator, null);
  assert.equal(result.creatorAvatarUrl, null);
  // Not reported as read.
  assert.ok(
    result.fallbacks.some((line) => line.includes('read: no name, no avatar')),
    result.fallbacks.join(' | '),
  );
  assert.ok(
    result.fallbacks.some((line) => line.includes('og:title')),
    'the title it did carry is quoted, so the shortfall can be seen',
  );
  // Nothing fabricated, and nothing that worked is lost.
  assert.equal(result.creatorHandle, '@1Nesh.D');
  assert.match(result.caption, /El Nido/);
  assert.ok(result.thumbnailUrl);
});

test('a walled profile page is reported as walled, not as empty', async () => {
  const result = await readMetadata(
    'https://www.facebook.com/1Nesh.D/videos/el-nido/691651166719048/',
    {
      fetchImpl: stubFetch({
        '/videos/': FB_VIDEO_PAGE,
        '': () =>
          new Response(
            '<meta property="og:title" content="Log in or sign up to view">',
            { status: 200 },
          ),
      }),
    },
  );

  assert.equal(result.creator, null, 'the wall text is never a name');
  assert.equal(result.creatorAvatarUrl, null);
  assert.ok(
    result.fallbacks.some((line) => line.includes('login wall')),
    result.fallbacks.join(' | '),
  );
});

test('a profile page that refuses the request says which way it refused', async () => {
  for (const [status, expected] of [
    [403, 'HTTP 403'],
    [404, 'HTTP 404'],
    [429, 'HTTP 429'],
  ]) {
    const result = await readMetadata(
      'https://www.facebook.com/1Nesh.D/videos/el-nido/691651166719048/',
      {
        fetchImpl: stubFetch({
          '/videos/': FB_VIDEO_PAGE,
          '': () => new Response('no', { status }),
        }),
      },
    );
    assert.equal(result.creator, null);
    assert.ok(
      result.fallbacks.some((line) => line.includes(expected)),
      `${status}: ${result.fallbacks.join(' | ')}`,
    );
  }
});

test('the profile page is read for a name even when an avatar was already found', async () => {
  // The post page carried an avatar in its JSON-LD but no name. The profile
  // fetch still has to run, or the name is lost for the sake of one request.
  const post = () =>
    new Response(
      '<meta property="og:url" content="https://www.facebook.com/1Nesh.D/videos/x/1/">' +
        '<meta property="og:title" content="El Nido Palawan Philippines. One of the most beautiful places on earth.">' +
        '<meta property="og:description" content="Tour A is 1400 pesos.">' +
        '<script type="application/ld+json">{"author":{"image":"https://cdn.test/ld-avatar.jpg"}}</script>',
      { status: 200 },
    );

  const result = await readMetadata('https://www.facebook.com/1Nesh.D/videos/x/1/', {
    fetchImpl: stubFetch({
      '/videos/': post,
      '': () => new Response('<meta property="og:title" content="Nesh D">', { status: 200 }),
    }),
  });

  assert.equal(result.creatorAvatarUrl, 'https://cdn.test/ld-avatar.jpg');
  assert.equal(result.sources.creatorAvatarUrl, 'ld+json');
  assert.equal(result.creator, 'Nesh D');
  assert.equal(result.sources.creator, 'profile page og:title');
});

// --- the name has to belong to the account -------------------------------
//
// The deployed service returned `creator: "Priyasad Wattegedara"` for the
// `@1Nesh.D` post, with `read: name and avatar`. The name may well be right —
// a vanity URL legitimately bears no resemblance to a person's name, so
// "it looks unrelated" is not evidence of anything. What was wrong is that
// nothing established the association, and three paths could attribute a name
// that did not belong to the account. All three reported the same
// `read: name and avatar` as a correct read, so the diagnostic could not tell
// them apart either.

test('a profile URL that redirects to a different account yields nothing', async () => {
  // The name and the avatar were read off whatever page the redirect landed
  // on, with no check that it was still the right account.
  const fetchImpl = async (url) => {
    if (url.includes('/videos/')) {
      return new Response(
        '<meta property="og:url" content="https://www.facebook.com/1Nesh.D/videos/x/1/">' +
          '<meta property="og:description" content="El Nido Palawan Philippines. Tour A is 1400 pesos.">' +
          '<meta property="og:image" content="https://scontent.xx.fbcdn.net/post.jpg">',
        { status: 200 },
      );
    }
    if (/facebook\.com\/1Nesh\.D$/.test(url)) {
      return new Response(null, {
        status: 302,
        headers: { location: 'https://www.facebook.com/SomeoneElse.Page' },
      });
    }
    return new Response(
      '<meta property="og:title" content="Priyasad Wattegedara">' +
        '<meta property="og:image" content="https://cdn.test/other-avatar.jpg">',
      { status: 200 },
    );
  };

  const result = await readMetadata(
    'https://www.facebook.com/1Nesh.D/videos/x/1/',
    { fetchImpl },
  );

  assert.equal(result.creator, null, 'a name off another account is not this one');
  assert.equal(result.creatorAvatarUrl, null);
  assert.ok(
    result.fallbacks.some((line) => line.includes('redirected to a different account')),
    result.fallbacks.join(' | '),
  );
  // And the status names both accounts, so the mismatch is auditable.
  assert.ok(result.fallbacks.some((line) => line.includes('1Nesh.D')));
  assert.ok(result.fallbacks.some((line) => line.includes('SomeoneElse.Page')));

  // Everything that did not depend on the profile page survives.
  assert.equal(result.creatorHandle, '@1Nesh.D');
  assert.equal(result.creatorUrl, 'https://www.facebook.com/1Nesh.D');
  assert.match(result.caption, /El Nido/);
  assert.ok(result.thumbnailUrl);
});

test('a redirect to the same account is still read', async () => {
  // A trailing slash, http to https, or a `?locale=` are all the same account
  // and must not be refused.
  for (const landing of [
    'https://www.facebook.com/1Nesh.D/',
    'https://www.facebook.com/1Nesh.D?locale=en_GB',
  ]) {
    const fetchImpl = async (url) => {
      if (url.includes('/videos/')) {
        return new Response(
          '<meta property="og:url" content="https://www.facebook.com/1Nesh.D/videos/x/1/">' +
            '<meta property="og:description" content="El Nido.">',
          { status: 200 },
        );
      }
      if (/facebook\.com\/1Nesh\.D$/.test(url)) {
        return new Response(null, { status: 302, headers: { location: landing } });
      }
      return new Response('<meta property="og:title" content="Nesh D">', { status: 200 });
    };

    const result = await readMetadata('https://www.facebook.com/1Nesh.D/videos/x/1/', {
      fetchImpl,
    });
    assert.equal(result.creator, 'Nesh D', landing);
  }
});

test('a JSON-LD publisher is not read as the creator', () => {
  // `publisher` names who distributed the content. On a reshared video that is
  // a different entity from the account whose page it is, and reading it as
  // the creator attributed an unrelated name.
  const nodes = parseJsonLd(`
    <script type="application/ld+json">
    {"@type":"VideoObject","name":"El Nido",
     "publisher":{"@type":"Organization","name":"Some Other Page",
                  "logo":"https://cdn.test/publisher-logo.jpg"}}
    </script>`);

  assert.equal(creatorFromJsonLd(nodes), null);

  // `author` and `creator` still are read — they name who made the thing.
  for (const key of ['author', 'creator']) {
    const withAuthor = parseJsonLd(
      `<script type="application/ld+json">{"${key}":{"name":"Nesh D"}}</script>`,
    );
    assert.equal(creatorFromJsonLd(withAuthor).name, 'Nesh D', key);
  }
});

test('a bystander avatar in a profile page is not taken as the creator', async () => {
  // The page-state scan takes the first `profile_pic_url`-shaped key in the
  // whole document, and a profile page embeds commenters and suggestions. On a
  // profile page `og:image` is the subject; a key scan is not.
  const fetchImpl = async (url) => {
    if (url.includes('/videos/')) {
      return new Response(
        '<meta property="og:url" content="https://www.facebook.com/1Nesh.D/videos/x/1/">' +
          '<meta property="og:description" content="El Nido.">',
        { status: 200 },
      );
    }
    return new Response(
      '<meta property="og:title" content="1Nesh.D">' +
        '<script>{"comments":[{"author":{"name":"Someone Else",' +
        '"profile_pic_url":"https://cdn.test/bystander.jpg"}}]}</script>',
      { status: 200 },
    );
  };

  const result = await readMetadata('https://www.facebook.com/1Nesh.D/videos/x/1/', {
    fetchImpl,
  });

  assert.equal(result.creator, '1Nesh.D', 'the page states its own name');
  assert.equal(
    result.creatorAvatarUrl,
    null,
    'no avatar is better than a stranger-s face',
  );
});

test('a post page state blob is still a valid avatar source', async () => {
  // The narrowing above is for profile pages only. TikTok publishes the video
  // author-s avatar in the post page-s own state, and that must keep working.
  const result = await readMetadata('https://www.tiktok.com/@mika.eats/video/1', {
    fetchImpl: stubFetch({
      '/oembed': () => new Response('no', { status: 404 }),
      '': () =>
        new Response(
          '<meta property="og:title" content="Mika Eats (@mika.eats) | TikTok">' +
            '<meta property="og:description" content="wings in Baguio">' +
            '<script>{"user":{"avatarLarger":"https://p16.test/mika.jpg"}}</script>',
          { status: 200 },
        ),
    }),
    withAvatar: false,
  });

  assert.equal(result.creatorAvatarUrl, 'https://p16.test/mika.jpg');
  assert.equal(result.sources.creatorAvatarUrl, 'embedded json');
});

test('the source of the display name is always stated', async () => {
  // The question "where did this name come from" has to be answerable from the
  // response alone, which is what `sources.creator` is for.
  const fetchImpl = async (url) => {
    if (url.includes('/videos/')) {
      return new Response(
        '<meta property="og:url" content="https://www.facebook.com/1Nesh.D/videos/x/1/">' +
          '<meta property="og:description" content="El Nido.">',
        { status: 200 },
      );
    }
    return new Response('<meta property="og:title" content="Nesh D">', { status: 200 });
  };

  const result = await readMetadata('https://www.facebook.com/1Nesh.D/videos/x/1/', {
    fetchImpl,
  });

  assert.equal(result.creator, 'Nesh D');
  assert.equal(result.sources.creator, 'profile page og:title');
});
