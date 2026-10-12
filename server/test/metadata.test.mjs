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
  captionFromOgDescription,
  decodeEntities,
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

/** An Instagram Reel: creator and caption, no title. */
const INSTAGRAM_PAGE = html(`<!doctype html><html><head>
<title>Nina Reyes on Instagram</title>
<meta property="og:type" content="video">
<meta property="og:url" content="https://www.instagram.com/reel/CxYzAbCdEfG/">
<meta property="og:title" content="Nina Reyes on Instagram: &quot;Three days in Kyoto&quot;">
<meta property="og:description" content="1,284 likes, 56 comments - nina.reyes on March 2, 2024: &quot;Three days in Kyoto and the best meal was a ¥900 set lunch at Kissa Master in Gion. Go before 11am. #kyoto #japantravel&quot;">
<meta property="og:image" content="//scontent.cdninstagram.com/v/reel-CxYzAbCdEfG.jpg">
<meta property="og:see_also" content="https://www.instagram.com/nina.reyes/">
</head><body></body></html>`);

/** A Facebook Reel reached through fb.watch, which redirects. */
const FACEBOOK_PAGE = html(`<!doctype html><html><head>
<title>Alex Cruz</title>
<meta property="og:type" content="video.other">
<meta property="og:url" content="https://www.facebook.com/reel/1234567890">
<meta property="og:title" content="Alex Cruz">
<meta property="og:description" content="Sagada in two days: ₱800 for the cave tour, ₱2,500 a night at a homestay near the centre. The sunrise at Kiltepan is worth the 4am start.">
<meta property="og:image" content="https://scontent.xx.fbcdn.net/v/reel-1234567890.jpg">
<meta property="og:see_also" content="https://www.facebook.com/alex.cruz.travels">
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
  const result = await readMetadata('https://www.instagram.com/reel/CxYzAbCdEfG/', {
    fetchImpl: stubFetch({
      '/reel/CxYzAbCdEfG': INSTAGRAM_PAGE,
      '/nina.reyes/': html('<meta property="og:image" content="https://cdn.test/nina.jpg">'),
    }),
  });

  assert.equal(result.fetched, true);
  assert.match(result.caption, /Kissa Master/);
  assert.match(result.caption, /¥900/);
  // The byline wrapper Instagram puts in og:title must not become the title.
  assert.ok(
    result.title === null || !result.title.includes('on Instagram:'),
    `a byline is not a title: ${result.title}`,
  );
  assert.equal(result.creatorHandle, '@nina.reyes');
  assert.equal(result.creatorAvatarUrl, 'https://cdn.test/nina.jpg');
  // Protocol-relative og:image resolved rather than handed over broken.
  assert.equal(result.thumbnailUrl, 'https://scontent.cdninstagram.com/v/reel-CxYzAbCdEfG.jpg');
  assert.deepEqual(result.hashtags, ['kyoto', 'japantravel']);
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
  assert.equal(result.creator, null, 'Facebook publishes no oEmbed author_name');
  // Facebook profile URLs carry no `@`, so a handle only appears once the
  // vanity path is read as one. Before that, Facebook posts had no creator at
  // all — the symptom that started this.
  assert.equal(result.creatorHandle, '@alex.cruz.travels');
  assert.equal(result.creatorUrl, 'https://www.facebook.com/alex.cruz.travels');
  assert.equal(result.creatorAvatarUrl, 'https://scontent.xx.fbcdn.net/v/avatar-alex-cruz.jpg');
  assert.match(result.caption, /Sagada in two days/);
  assert.match(result.caption, /₱800/);
  assert.equal(result.canonicalUrl, 'https://www.facebook.com/reel/1234567890');
  assert.equal(result.mediaType, 'video');
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
