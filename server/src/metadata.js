/**
 * Reading a post's public metadata, from the server rather than the browser.
 *
 * Nook is a static site, so every lookup it made itself was a cross-origin
 * request from a page on github.io. That is the whole reason three of the four
 * platforms arrived at the model as a bare URL:
 *
 * - YouTube and TikTok publish keyless oEmbed with
 *   `Access-Control-Allow-Origin: *`, so those worked — sometimes. TikTok
 *   rate-limits by IP and answers a browser inconsistently.
 * - Instagram and Facebook withdrew public oEmbed in 2020. The app's only
 *   remaining route was a Meta app token, and the deploy workflow passes no
 *   `--dart-define`s beyond the backend address, so a published build never
 *   had one. `endpointFor` returned null and the post reached the model with
 *   no caption at all.
 *
 * None of that is a limit on what the platforms publish. It is a limit on who
 * is asking. A server has no origin, so the same page that a browser cannot
 * read is an ordinary GET from here — which is exactly what every link
 * unfurler in every chat app does, and reads the same Open Graph tags.
 *
 * What this does NOT do, deliberately:
 *
 * - No credentials. No cookies, no tokens, no logged-in session. A post behind
 *   a login wall stays behind it and is reported as unreadable.
 * - No evasion. One plain GET with an honest bot user agent, one redirect
 *   chain, no retry storm, no header spoofing to look like a signed-in person.
 * - No arbitrary fetching. The host allowlist below is the whole point: this
 *   endpoint is public, so without it the service would be an open proxy
 *   someone could aim at a cloud metadata address or an internal host.
 */

/**
 * The only hosts this will fetch, by exact match or registrable suffix.
 *
 * An allowlist rather than a denylist, because the failure modes are not
 * symmetrical: a missed denial turns a public endpoint into an SSRF tool,
 * while a missed allowance just means one platform reads worse.
 */
const ALLOWED_HOSTS = [
  // YouTube
  'youtube.com',
  'youtu.be',
  'youtube-nocookie.com',
  // TikTok, including the share-sheet short domains
  'tiktok.com',
  'vt.tiktok.com',
  'vm.tiktok.com',
  // Instagram
  'instagram.com',
  'instagr.am',
  // Facebook
  'facebook.com',
  'fb.watch',
  'fb.me',
  'm.facebook.com',
];

/** oEmbed providers that answer without a key. */
const OEMBED = {
  youtube: (url) => `https://www.youtube.com/oembed?format=json&url=${encodeURIComponent(url)}`,
  tiktok: (url) => `https://www.tiktok.com/oembed?url=${encodeURIComponent(url)}`,
};

/**
 * An honest identity. Naming the bot is what makes this a polite crawl rather
 * than an impersonation: a platform that would rather not answer Nook can say
 * so, and `robots.txt`-style courtesy is possible at all.
 */
const USER_AGENT =
  'NookBot/1.0 (+https://github.com/alyencs/nook-flutter; link preview for a saved post)';

const FETCH_TIMEOUT_MS = 8000;
const MAX_HTML_BYTES = 512 * 1024;
const MAX_REDIRECTS = 5;

export class MetadataError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

/** Which platform a URL belongs to. Mirrors `lib/ai/platform_from_url.dart`. */
export function platformOf(url) {
  let host;
  try {
    host = new URL(url).hostname.toLowerCase().replace(/^www\./, '');
  } catch {
    return 'other';
  }
  if (host === 'youtu.be' || host.endsWith('youtube.com') || host.endsWith('youtube-nocookie.com')) {
    return 'youtube';
  }
  if (host.endsWith('tiktok.com')) return 'tiktok';
  if (host.endsWith('instagram.com') || host === 'instagr.am') return 'instagram';
  if (host.endsWith('facebook.com') || host === 'fb.watch' || host === 'fb.me') return 'facebook';
  return 'other';
}

/**
 * Whether this URL may be fetched at all.
 *
 * Rejects anything that is not an http(s) URL on an allowlisted host. Checked
 * again after every redirect, because a redirect to somewhere else is the
 * obvious way around a check made only once.
 */
export function isFetchable(url) {
  let parsed;
  try {
    parsed = new URL(url);
  } catch {
    return false;
  }
  if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') return false;
  // Credentials in a URL are never part of a public post link, and are a way
  // to smuggle a different target past a hostname check.
  if (parsed.username || parsed.password) return false;

  const host = parsed.hostname.toLowerCase();
  return ALLOWED_HOSTS.some((allowed) => host === allowed || host.endsWith(`.${allowed}`));
}

/** One GET, with a timeout, a byte cap, and the redirect chain re-checked. */
async function get(url, { fetchImpl = fetch, accept = 'text/html' } = {}) {
  let current = url;

  for (let hop = 0; hop <= MAX_REDIRECTS; hop++) {
    if (!isFetchable(current)) {
      throw new MetadataError(`Refusing to follow a redirect to ${current}.`, 400);
    }

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
    let response;
    try {
      response = await fetchImpl(current, {
        method: 'GET',
        redirect: 'manual',
        signal: controller.signal,
        headers: {
          accept,
          'accept-language': 'en;q=0.9,*;q=0.5',
          'user-agent': USER_AGENT,
        },
      });
    } finally {
      clearTimeout(timer);
    }

    const location = response.headers?.get?.('location');
    if (response.status >= 300 && response.status < 400 && location) {
      current = new URL(location, current).toString();
      continue;
    }

    return { response, finalUrl: current };
  }

  throw new MetadataError('Too many redirects.', 400);
}

/** Reads a capped amount of text, so one enormous page cannot eat the worker. */
async function readCapped(response) {
  const text = await response.text();
  return text.length > MAX_HTML_BYTES ? text.slice(0, MAX_HTML_BYTES) : text;
}

const ENTITIES = {
  amp: '&',
  lt: '<',
  gt: '>',
  quot: '"',
  apos: "'",
  '#39': "'",
  nbsp: ' ',
};

/** Meta tag content arrives HTML-escaped; a caption full of `&amp;` is wrong. */
export function decodeEntities(value) {
  return value
    .replace(/&#(\d+);/g, (_, code) => String.fromCodePoint(Number(code)))
    .replace(/&#x([0-9a-f]+);/gi, (_, code) => String.fromCodePoint(parseInt(code, 16)))
    .replace(/&([a-z]+|#39);/gi, (match, name) => ENTITIES[name.toLowerCase()] ?? match);
}

/**
 * Every `<meta>` whose property or name we care about, plus `<title>`.
 *
 * A regex rather than a DOM parse: Workers have no DOM, the input is capped,
 * and the shape being read is four attributes on a self-closing tag. Attribute
 * order varies between platforms, so both orders are matched.
 */
export function parseMetaTags(html) {
  const tags = {};

  const metaPattern = /<meta\s+([^>]*?)\/?>/gi;
  for (const match of html.matchAll(metaPattern)) {
    const attrs = match[1];
    const key =
      /(?:property|name|itemprop)\s*=\s*["']([^"']+)["']/i.exec(attrs)?.[1]?.toLowerCase();
    const content = /content\s*=\s*["']([^"']*)["']/i.exec(attrs)?.[1];
    if (key && content !== undefined && tags[key] === undefined) {
      tags[key] = decodeEntities(content).trim();
    }
  }

  const title = /<title[^>]*>([\s\S]{0,2000}?)<\/title>/i.exec(html)?.[1];
  if (title) tags['<title>'] = decodeEntities(title).trim();

  return tags;
}

/**
 * Whether what came back is a login wall rather than the post.
 *
 * Instagram and Facebook answer an unauthenticated request for a private,
 * deleted or region-restricted post with a 200 and a sign-in page. Treating
 * that as a successful read is how a post ends up described as "Log in to
 * Facebook", so it is detected and reported as unreadable instead.
 */
export function looksLikeLoginWall(tags, html) {
  const title = `${tags['og:title'] ?? ''} ${tags['<title>'] ?? ''}`.toLowerCase();
  if (
    /^\s*(log in|login|sign up|sign in)\b/.test(title) ||
    title.includes('log into facebook') ||
    title.includes('log in to facebook') ||
    title.includes('log in or sign up') ||
    title.includes('content isn') ||
    title.includes('page not found') ||
    title.includes('video unavailable')
  ) {
    return true;
  }
  // Instagram's wall carries no og:description at all and says this instead.
  const description = (tags['og:description'] ?? '').toLowerCase();
  if (description.startsWith('log in to see') || description.includes('this content isn')) {
    return true;
  }
  return /<title[^>]*>\s*(login|log in)\b/i.test(html);
}

/**
 * An image URL that is safe to hand the UI, or null.
 *
 * Protocol-relative (`//cdn/x.jpg`) and root-relative (`/x.jpg`) both turn up
 * in meta tags, and `Image.network` is given whatever it is handed — so they
 * are resolved here rather than failing in the widget. Anything that is not
 * http(s) after that is dropped: a `data:` or `javascript:` URL in an avatar
 * field has no legitimate source.
 */
export function normaliseImageUrl(value, base) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (trimmed === '') return null;

  let resolved;
  try {
    resolved = base ? new URL(trimmed, base) : new URL(trimmed);
  } catch {
    return null;
  }
  if (resolved.protocol !== 'https:' && resolved.protocol !== 'http:') return null;
  return resolved.toString();
}

/** `#tags` in a caption, lowercased and de-duplicated, order kept. */
export function hashtagsFrom(text) {
  if (typeof text !== 'string' || text === '') return [];
  const found = [];
  const seen = new Set();
  // Unicode-aware: Japanese and Filipino captions tag in their own scripts.
  for (const match of text.matchAll(/#([\p{L}\p{N}_]{1,60})/gu)) {
    const tag = match[1].toLowerCase();
    if (!seen.has(tag)) {
      seen.add(tag);
      found.push(match[1]);
    }
  }
  return found;
}

/**
 * TikTok and Instagram write the caption into `og:description`, wrapped in
 * engagement counts and the creator's name. The wrapper is noise that reads to
 * a model as content, so it is stripped.
 *
 * TikTok:   `1.2M likes, 3400 comments. "<caption>"`
 * Instagram: `1,234 likes, 56 comments - handle on January 1, 2024: "<caption>"`
 */
export function captionFromOgDescription(description, platform) {
  if (typeof description !== 'string') return null;
  let text = description.trim();
  if (text === '') return null;

  if (platform === 'tiktok' || platform === 'instagram') {
    // Drop a leading counts-and-byline clause, but only when the quoted
    // caption that follows is actually there — otherwise the description IS
    // the caption and must survive intact.
    const quoted = /[:.]\s*[“"'](.+)[”"']\s*$/s.exec(text);
    if (quoted) {
      text = quoted[1].trim();
    } else {
      const stripped = text.replace(
        /^[\d.,KMB]+\s+likes?,\s*[\d.,KMB]+\s+comments?\.?\s*[-–—]?\s*/i,
        '',
      );
      if (stripped !== '') text = stripped.trim();
    }
  }

  return text === '' ? null : text;
}

/** oEmbed, for the two providers that still publish it keylessly. */
async function readOEmbed(url, platform, fetchImpl) {
  const endpoint = OEMBED[platform]?.(url);
  if (!endpoint) return null;

  try {
    const { response } = await get(endpoint, { fetchImpl, accept: 'application/json' });
    if (response.status !== 200) return null;
    const json = JSON.parse(await readCapped(response));
    return json && typeof json === 'object' ? json : null;
  } catch {
    // oEmbed is one of two sources, not the only one. A failure here falls
    // through to the page's own meta tags.
    return null;
  }
}

/** The post page's Open Graph tags. */
async function readOpenGraph(url, fetchImpl) {
  const { response, finalUrl } = await get(url, { fetchImpl });
  if (response.status !== 200) {
    return { tags: {}, finalUrl, status: response.status, wall: false };
  }
  const html = await readCapped(response);
  const tags = parseMetaTags(html);
  return { tags, finalUrl, status: 200, wall: looksLikeLoginWall(tags, html) };
}

/**
 * The creator's profile picture, from their own public profile page.
 *
 * `og:image` on a profile page is the avatar — that is what the platform puts
 * there for a link to a person. It is a second request, so it only runs when a
 * creator page is actually known, and a failure is silent: an avatar is the
 * least important field in an extraction and the UI draws an initial instead.
 *
 * This is the only route any of the four offers without authentication, and it
 * does not always work. It is never substituted with the post's thumbnail.
 */
async function readCreatorAvatar(creatorUrl, fetchImpl) {
  if (!creatorUrl || !isFetchable(creatorUrl)) return null;
  try {
    const { response, finalUrl } = await get(creatorUrl, { fetchImpl });
    if (response.status !== 200) return null;
    const html = await readCapped(response);
    const tags = parseMetaTags(html);
    if (looksLikeLoginWall(tags, html)) return null;
    return normaliseImageUrl(tags['og:image'], finalUrl);
  } catch {
    return null;
  }
}

/** Path segments that are never an account name. */
const RESERVED_SEGMENTS = new Set([
  'p', 'reel', 'reels', 'tv', 'stories', 'explore', 'watch', 'share', 'video',
  'videos', 'posts', 'groups', 'pages', 'shorts', 'embed', 'channel', 'c',
  'permalink.php', 'photo.php', 'profile.php', 'story.php', 'oembed',
]);

/** All digits, or a Facebook `pfbid` blob. An id, not a name. */
const looksLikeId = (segment) => /^\d+$/.test(segment) || segment.startsWith('pfbid');

/**
 * `@handle` from a profile URL.
 *
 * TikTok and YouTube put an `@` in the path. Instagram and Facebook do not —
 * a profile is `instagram.com/nina.reyes`, so looking only for an `@` found
 * nothing and the creator came back anonymous on exactly the two platforms
 * this was supposed to fix.
 */
function handleFromUrl(url) {
  let segments;
  try {
    segments = new URL(url).pathname.split('/').filter(Boolean);
  } catch {
    return null;
  }
  for (const segment of segments) {
    if (segment.startsWith('@') && segment.length > 1) return segment;
  }
  // A bare vanity path, but only when it is the whole path: the first segment
  // of a POST url is a username, while the first segment of `/reel/<id>` is
  // not, and `/<user>/video/<id>` is handled by the `@` case above.
  const [first] = segments;
  if (
    segments.length === 1 &&
    first &&
    first.length > 1 &&
    !RESERVED_SEGMENTS.has(first.toLowerCase()) &&
    !looksLikeId(first) &&
    !first.includes('.php')
  ) {
    return first;
  }
  return null;
}

/**
 * Reads everything publicly available about one post URL.
 *
 * Both sources are consulted and then merged, rather than one being preferred
 * wholesale: oEmbed has the creator's display name, which Open Graph often
 * lacks, and Open Graph has the caption, which oEmbed lacks on three of the
 * four. Taking either alone is how the caption went missing.
 *
 * `fetched: false` with a `reason` is a real answer, not an error: the app says
 * so on screen and offers manual entry, which is the honest outcome for a
 * private or deleted post.
 */
export async function readMetadata(url, { fetchImpl = fetch, withAvatar = true } = {}) {
  if (typeof url !== 'string' || url.trim() === '') {
    throw new MetadataError('A "url" is required.');
  }
  const target = url.trim();
  if (!isFetchable(target)) {
    throw new MetadataError(
      'That URL is not a post on a platform this service reads. ' +
        'It reads YouTube, TikTok, Instagram and Facebook links only.',
      400,
    );
  }

  const platform = platformOf(target);

  // Open Graph first, because it resolves the short link and gives the
  // canonical URL that oEmbed then needs: TikTok's oEmbed does not answer a
  // vt.tiktok.com address, which is exactly what the mobile share sheet copies.
  let page = { tags: {}, finalUrl: target, status: 0, wall: false };
  let pageError = null;
  try {
    page = await readOpenGraph(target, fetchImpl);
  } catch (error) {
    // A refusal by the host guard is a real answer and must be loud: it means
    // someone aimed this endpoint somewhere it will not go. A timeout or a
    // reset is not, and falls through to whatever oEmbed can tell us.
    if (error instanceof MetadataError) throw error;
    pageError = error;
  }

  // A sign-in page is not the post. Reading its tags as content is how a
  // private post came back titled "Log in or sign up to view", so everything
  // the wall served is dropped rather than merged.
  const wall = page.wall;
  if (wall) page = { ...page, tags: {} };

  const canonical = normaliseImageUrl(page.tags['og:url'], page.finalUrl) ?? page.finalUrl;
  const oembed = (await readOEmbed(canonical, platform, fetchImpl)) ?? {};

  const str = (value) => {
    if (typeof value !== 'string') return null;
    const trimmed = value.trim();
    return trimmed === '' ? null : trimmed;
  };

  // oEmbed's title is the caption on TikTok and the video title on YouTube.
  const oembedTitle = str(oembed.title);
  const ogTitle = str(page.tags['og:title']);
  const ogDescription = str(page.tags['og:description']);

  const caption =
    captionFromOgDescription(ogDescription, platform) ??
    (platform === 'tiktok' || platform === 'instagram' ? oembedTitle : null) ??
    str(page.tags['description']);

  // On YouTube the title is a real title. On the caption-first platforms there
  // usually is none, and `og:title` is a truncated echo of the caption dressed
  // up with the creator's name — passing that off as a title is how a post
  // ends up called `wanderwithmia on Instagram: "we found the best…"`.
  const title =
    platform === 'youtube'
      ? (oembedTitle ?? ogTitle)
      : (oembedTitle && caption && oembedTitle === caption ? null : oembedTitle) ?? null;

  const creatorUrl = str(oembed.author_url) ?? str(page.tags['og:see_also']);
  const creator = str(oembed.author_name);

  // Split deliberately. A handle that came from a lookup is something only the
  // lookup knew; a handle read off the URL is something the app already had and
  // is no evidence the post itself was readable — counting it as such reported
  // a deleted post as successfully read.
  const lookedUpHandle =
    str(oembed.author_unique_id) ?? (creatorUrl ? handleFromUrl(creatorUrl) : null);
  const handle = lookedUpHandle ?? handleFromUrl(canonical);

  const thumbnail =
    normaliseImageUrl(oembed.thumbnail_url, canonical) ??
    normaliseImageUrl(page.tags['og:image'], page.finalUrl) ??
    null;

  const avatar =
    withAvatar && creatorUrl ? await readCreatorAvatar(creatorUrl, fetchImpl) : null;

  const readAnything = Boolean(title || caption || creator || lookedUpHandle);

  return {
    platform,
    url: target,
    canonicalUrl: canonical === target ? null : canonical,
    title,
    caption,
    hashtags: hashtagsFrom(caption ?? ''),
    creator,
    creatorHandle: handle ? (handle.startsWith('@') ? handle : `@${handle}`) : null,
    creatorUrl,
    // Never the post thumbnail. A face that is not the creator's is worse than
    // the initial the UI draws when there is none.
    creatorAvatarUrl: avatar,
    thumbnailUrl: thumbnail,
    mediaType: mediaTypeFrom(page.tags, oembed, canonical, platform),
    fetched: readAnything,
    reason: readAnything
      ? null
      : wall
        ? 'This post is not public — the platform served a sign-in page instead ' +
          'of the post. Nook reads public posts only.'
        : pageError
          ? 'The post could not be read from its platform.'
          : page.status === 404
            ? 'That post no longer exists, or the link is wrong.'
            : 'The platform returned nothing readable for this link.',
  };
}

/** What kind of media, from whatever says so most reliably. */
function mediaTypeFrom(tags, oembed, url, platform) {
  const ogType = (tags['og:type'] ?? '').toLowerCase();
  if (ogType.includes('video')) return 'video';
  if (tags['og:video'] || tags['og:video:url'] || tags['og:video:secure_url']) return 'video';
  if (platform === 'youtube') return 'video';

  const path = (() => {
    try {
      return new URL(url).pathname.toLowerCase();
    } catch {
      return '';
    }
  })();
  if (/\/(reel|reels|video|videos|shorts|watch)(\/|$)/.test(path)) return 'video';
  if (platform === 'instagram' && path.includes('/p/')) return 'image';
  if (platform === 'facebook' && path.includes('/photo')) return 'image';
  if (ogType.includes('photo') || ogType.includes('image')) return 'image';
  if (typeof oembed.type === 'string' && oembed.type.trim() !== '') {
    const type = oembed.type.trim().toLowerCase();
    if (type === 'video' || type === 'photo') return type === 'photo' ? 'image' : 'video';
  }
  return 'unknown';
}
