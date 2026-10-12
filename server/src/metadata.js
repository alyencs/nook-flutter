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

/**
 * Platform boilerplate that must never become a caption.
 *
 * Facebook and Instagram answer an unauthenticated request for a page they
 * will not show with a generic marketing blurb in `og:description`. It is a
 * well-formed sentence, so nothing downstream can tell it from a real caption
 * — the model reads "See posts, photos and more on Facebook" and dutifully
 * extracts no destination from it, which looks like the caption being useless
 * rather than absent.
 */
const BOILERPLATE = [
  /^see posts, photos and more on facebook/i,
  /^log ?in(to| to)? facebook/i,
  // The wall's own wording. Without this it passes the prose test — six
  // ordinary words, no punctuation — and becomes the creator's name.
  /^log ?in or sign ?up/i,
  // Anchored to the wall's actual wording. A looser pattern ate real names:
  // a page called "Login Travel Co" is not a sign-in page.
  /^(log ?in|sign ?up|sign ?in)( or (sign ?up|log ?in))?( (to|for) (view|see|continue|facebook|instagram))?[.!]?$/i,
  /^you must log in to continue/i,
  // The platform's own name, which is what `og:title` falls back to on a page
  // that will not show its contents. Read as a creator it produced
  // `creator: "Facebook"` — a fabricated name that looks entirely plausible.
  /^(facebook|instagram|tiktok|youtube|meta)$/i,
  /^(facebook|instagram|tiktok|youtube)\s*[|\-–—]\s*(log ?in|sign ?up|home)?$/i,
  /^watch\s*[|\-–—]\s*facebook$/i,
  /^this content is(n.t| not) available/i,
  /^join facebook to connect/i,
  /^facebook is a social (utility|network)/i,
  /^create an account or log in/i,
  // Counts carry thousands separators, so `\d+` alone misses `1,284 followers`.
  /^[\d,.]+\s*(k|m|b)?\s*followers?.{0,80}see instagram photos/i,
  /^see instagram photos and videos from/i,
  /^discover videos related to/i,
  /^tiktok - (make your day|trends start here)/i,
  /^watch the latest videos? from/i,
  /^upload, livestream, and create your own videos/i,
];

/** Whether this text is the platform talking rather than the poster. */
export function isBoilerplate(text) {
  if (typeof text !== 'string') return true;
  const trimmed = text.trim();
  if (trimmed === '') return true;
  return BOILERPLATE.some((pattern) => pattern.test(trimmed));
}

/**
 * Unescapes a URL as platforms embed them in JSON and HTML.
 *
 * Inside a `<script>` JSON blob a CDN URL arrives as
 * `https://cdn/x.jpg?a=1\u0026b=2`, and in an attribute as `?a=1&amp;b=2`.
 * Handed to `Image.network` either way it 403s, because the query it asks for
 * is not the query that was signed.
 */
export function unescapeUrl(value) {
  if (typeof value !== 'string') return value;
  return value
    .replace(/\\u0026/gi, '&')
    .replace(/\\u002F/gi, '/')
    .replace(/\\\//g, '/')
    .replace(/&amp;/gi, '&')
    .replace(/&#0?38;/g, '&');
}

/**
 * Every `application/ld+json` block on the page, flattened.
 *
 * This is the structured data the platforms publish about themselves, and it
 * is the only unauthenticated place some of them name the creator at all. It
 * was not being read: creator identity came from `og:see_also`, a tag none of
 * these three actually serves on a post page, so Facebook — which publishes no
 * keyless oEmbed either — had no source for a creator whatsoever.
 *
 * `@graph` and bare arrays are flattened, because all three shapes turn up.
 */
export function parseJsonLd(html) {
  const found = [];
  const pattern =
    /<script[^>]*type\s*=\s*["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;

  for (const match of html.matchAll(pattern)) {
    let parsed;
    try {
      parsed = JSON.parse(match[1].trim());
    } catch {
      // A truncated or templated block. The others may still be good.
      continue;
    }
    const queue = Array.isArray(parsed) ? [...parsed] : [parsed];
    while (queue.length > 0) {
      const node = queue.shift();
      if (node === null || typeof node !== 'object') continue;
      if (Array.isArray(node)) {
        queue.push(...node);
        continue;
      }
      if (Array.isArray(node['@graph'])) queue.push(...node['@graph']);
      found.push(node);
    }
  }
  return found;
}

/** The first non-empty string among several possible shapes. */
function firstString(...values) {
  for (const value of values) {
    if (typeof value === 'string' && value.trim() !== '') return value.trim();
    if (Array.isArray(value)) {
      const inner = firstString(...value);
      if (inner) return inner;
    }
    if (value !== null && typeof value === 'object') {
      const inner = firstString(value.name, value.url, value['@id'], value.contentUrl);
      if (inner) return inner;
    }
  }
  return null;
}

/**
 * Creator identity out of JSON-LD, where the platform published any.
 *
 * `author` is the usual home; Instagram has also used `creator`, and video
 * pages sometimes nest it under `publisher`. `alternateName` is where a handle
 * lives when there is one.
 */
export function creatorFromJsonLd(nodes) {
  for (const node of nodes) {
    // `author` and `creator` name who made the thing. `publisher` names who
    // distributed it, which on a reshared video is a different entity
    // entirely — and reading it as the creator attributed a name that had
    // nothing to do with the account whose page it was.
    const author = node.author ?? node.creator;
    if (author === null || author === undefined) continue;

    const candidates = Array.isArray(author) ? author : [author];
    for (const one of candidates) {
      if (typeof one === 'string') {
        if (one.trim() !== '') return { name: one.trim() };
      } else if (typeof one === 'object') {
        const name = firstString(one.name);
        const handle = firstString(one.alternateName, one.identifier);
        const url = firstString(one.url, one['@id'], one.mainEntityOfPage);
        const image = firstString(one.image, one.thumbnailUrl, one.logo, one.photo);
        if (name || handle || url || image) {
          return {
            name: name ?? undefined,
            handle: handle ?? undefined,
            url: url ?? undefined,
            image: image ?? undefined,
          };
        }
      }
    }
  }
  return null;
}

/** A caption out of JSON-LD, where one is published. */
export function captionFromJsonLd(nodes) {
  for (const node of nodes) {
    const text = firstString(
      node.articleBody,
      node.caption,
      node.description,
      node.text,
    );
    if (text && !isBoilerplate(text)) return text;
  }
  return null;
}

/**
 * Creator identity out of `og:title`, which each platform writes differently.
 *
 * This is the source that is actually there on an Instagram or Facebook post,
 * and the patterns are not interchangeable — which is the whole reason
 * Facebook could not be fixed by whatever made TikTok work.
 *
 *   Instagram  `Nina Reyes (@nina.reyes) • Instagram photo`
 *              `Nina Reyes on Instagram: "three days in Kyoto…"`
 *   TikTok     `Mika Eats (@mika.eats) | TikTok`
 *              `Mika on TikTok`
 *   Facebook   `Alex Cruz` — the page or person, and nothing else. A Facebook
 *              post page puts the author's display name here on its own, with
 *              no handle and no decoration, so there is nothing to strip and
 *              nothing to pattern-match: the whole string is the name.
 */
export function creatorFromOgTitle(ogTitle, platform) {
  if (typeof ogTitle !== 'string') return null;
  const text = ogTitle.trim();
  if (text === '' || isBoilerplate(text)) return null;

  // `Name (@handle)` — Instagram and TikTok profile-style titles.
  const withHandle = /^(.+?)\s*\(@([A-Za-z0-9._]+)\)/.exec(text);
  if (withHandle) {
    return { name: withHandle[1].trim(), handle: `@${withHandle[2]}` };
  }

  // `Name on Instagram: "caption"` / `Name on TikTok`
  const onPlatform = /^(.+?)\s+on\s+(instagram|tiktok|facebook)\b/i.exec(text);
  if (onPlatform) {
    const name = onPlatform[1].trim();
    if (name !== '') {
      // An `@`-prefixed name is a handle rather than a display name.
      return name.startsWith('@')
        ? { handle: name }
        : { name };
    }
  }

  if (platform === 'facebook') {
    const name = text
      // `| Facebook`, and the section name Facebook appends to a profile.
      .replace(/\s*[|\-–—]\s*facebook\s*$/i, '')
      .replace(/\s*[-–—]\s*(home|about|photos|videos|reels|posts|live)\s*$/i, '')
      .trim();

    if (name !== '' && !looksLikeProse(name)) return { name };
  }

  return null;
}

/**
 * Whether a string is post text rather than somebody's name.
 *
 * Facebook puts the post's own words in a video page's `og:title`, so this has
 * to tell the two apart — and the first version of it rejected anything
 * containing a full stop, which threw away every name that has one. A period
 * inside a short name is ordinary: initials, abbreviations, and account-style
 * names. The page this was reported against is called `1Nesh.D`, so its own
 * name was the first thing the test discarded.
 *
 * Length and word count do the work instead. A sentence-ending stop only
 * counts against a string long enough to be a sentence, which keeps
 * "Nesh D." and "St. Nesh Travels" while still refusing
 * "El Nido Palawan Philippines."
 */
function looksLikeProse(text) {
  const words = text.split(/\s+/).filter(Boolean);
  if (text.length > 60) return true;
  if (words.length > 8) return true;
  // A hashtag or a link is never part of a name.
  if (/[#]/.test(text) || /https?:\/\//i.test(text)) return true;
  // A terminal stop, but only where there is a clause in front of it.
  if (/[.!?]$/.test(text) && words.length > 3) return true;
  // More than one sentence-ending stop is prose however short it is.
  if ((text.match(/[.!?](\s|$)/g) ?? []).length > 1) return true;
  return false;
}

/** A profile URL for a handle, so an avatar can still be looked up. */
export function profileUrlFor(handle, platform) {
  if (typeof handle !== 'string') return null;
  const bare = handle.replace(/^@/, '').trim();
  if (bare === '' || !/^[A-Za-z0-9._-]+$/.test(bare)) return null;

  return switchPlatform(platform, bare);
}

function switchPlatform(platform, bare) {
  switch (platform) {
    case 'tiktok':
      return `https://www.tiktok.com/@${bare}`;
    case 'instagram':
      return `https://www.instagram.com/${bare}/`;
    case 'facebook':
      return `https://www.facebook.com/${bare}`;
    case 'youtube':
      return `https://www.youtube.com/@${bare}`;
    default:
      return null;
  }
}

/**
 * An avatar out of the platform's own embedded JSON.
 *
 * TikTok ships the whole page state in `__UNIVERSAL_DATA_FOR_REHYDRATION__`
 * and Instagram has used `profile_pic_url`; both carry an avatar that the
 * meta tags do not. Read by key name rather than by walking a documented
 * shape, because these blobs are internal and their nesting changes — the key
 * names have been stable far longer than the paths to them.
 */
export function avatarFromEmbeddedJson(html) {
  const keys = [
    'avatarLarger',
    'avatarMedium',
    'avatarThumb',
    'profile_pic_url_hd',
    'profile_pic_url',
    'profilePicUrl',
  ];
  for (const key of keys) {
    const pattern = new RegExp(`"${key}"\\s*:\\s*"([^"]{8,2000})"`, 'i');
    const match = pattern.exec(html);
    if (match) {
      const url = unescapeUrl(match[1]);
      if (/^https?:\/\//i.test(url)) return url;
    }
  }
  return null;
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
    return { tags: {}, html: '', finalUrl, status: response.status, wall: false };
  }
  const html = await readCapped(response);
  const tags = parseMetaTags(html);
  // The HTML is kept, not just its meta tags: JSON-LD and the platforms' own
  // embedded state blobs are where the creator and the avatar actually live on
  // the two that publish no oEmbed.
  return { tags, html, finalUrl, status: 200, wall: looksLikeLoginWall(tags, html) };
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
async function readCreatorProfile(creatorUrl, fetchImpl) {
  if (!creatorUrl || !isFetchable(creatorUrl)) {
    return { avatar: null, name: null, status: 'not fetchable' };
  }
  const asked = handleFromUrl(creatorUrl);
  try {
    const { response, finalUrl } = await get(creatorUrl, { fetchImpl });
    if (response.status !== 200) {
      return { avatar: null, name: null, status: `HTTP ${response.status}` };
    }
    const html = await readCapped(response);
    const tags = parseMetaTags(html);
    if (looksLikeLoginWall(tags, html)) {
      return { avatar: null, name: null, status: 'login wall' };
    }

    // Is this still the account that was asked for?
    //
    // `get` follows redirects, and the name and the avatar were being read off
    // whatever page it landed on with no check that the page was still the
    // right account. A vanity URL that redirects to a different account
    // therefore produced a confident display name belonging to somebody else —
    // reported with the same `read: name and avatar` as a correct read, so
    // nothing downstream or in the diagnostics could tell the two apart.
    const landed = handleFromUrl(finalUrl);
    const sameAccount =
      asked === null ||
      landed === null ||
      landed.toLowerCase().replace(/^@/, '') === asked.toLowerCase().replace(/^@/, '');

    if (!sameAccount) {
      // Facebook does canonicalise a vanity path to `/people/<Name>/<id>` for
      // the same account, which is why this is not simply fatal — but that
      // form has no handle in it, so `landed` is null and it takes the branch
      // above. A redirect to a DIFFERENT handle is a different account.
      return {
        avatar: null,
        name: null,
        status: `redirected to a different account (asked ${asked}, landed ${landed})`,
      };
    }

    const platform = platformOf(finalUrl);
    const jsonLd = parseJsonLd(html);
    const ldAuthor = creatorFromJsonLd(jsonLd) ?? {};

    // The name, from each place a profile page may state it. `og:title` is the
    // usual one; a profile's JSON-LD and `<title>` are the fallbacks, and
    // `og:site_name` never is — it says "Facebook".
    const name =
      creatorFromOgTitle(tags['og:title'], platform)?.name ??
      ldAuthor.name ??
      creatorFromOgTitle(tags['<title>'], platform)?.name ??
      null;

    // The avatar. `og:image` first, then the page's own state blob, then
    // JSON-LD's author image, then `twitter:image`, which some profile pages
    // carry when `og:image` is absent.
    // `og:image`, JSON-LD's author image, then `twitter:image`. All three are
    // statements the page makes about its own subject.
    //
    // `avatarFromEmbeddedJson` is deliberately NOT used here. It scans the
    // whole document for the first `profile_pic_url`-shaped key, and a profile
    // page embeds other people — commenters, suggestions — so the first match
    // need not be the subject at all. On a post page that scan is the author's
    // own state and is kept; on a profile page it is a coin toss.
    const avatar =
      normaliseImageUrl(unescapeUrl(tags['og:image']), finalUrl) ??
      normaliseImageUrl(unescapeUrl(ldAuthor.image), finalUrl) ??
      normaliseImageUrl(unescapeUrl(tags['twitter:image']), finalUrl);

    // What was actually found, not merely that a page came back. `read` on its
    // own said "I fetched something" and was reported for a page that yielded
    // neither field — which is indistinguishable from success in a log, and is
    // exactly the diagnostic that sent this round looking in the wrong place.
    const found = [name ? 'name' : null, avatar ? 'avatar' : null].filter(Boolean);
    const status =
      found.length === 2
        ? 'read: name and avatar'
        : found.length === 1
          ? `read: ${found[0]} only`
          : `read: no name, no avatar (${Object.keys(tags).length} meta tags` +
            `${tags['og:title'] ? `, og:title ${JSON.stringify(tags['og:title'].slice(0, 60))}` : ', no og:title'})`;

    // The address actually read, when it is not the one asked for. A name is
    // only as trustworthy as the page it came off.
    const landedNote = finalUrl === creatorUrl ? '' : ` [read ${finalUrl}]`;
    return { avatar, name, status: `${status}${landedNote}` };
  } catch {
    return { avatar: null, name: null, status: 'unreachable' };
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
 * Hosts whose whole path is an opaque redirect code.
 *
 * `fb.watch/aBcDeFgHiJ` has the shape of a profile path and is not one. Read
 * as an account it produces a creator handle that never existed — worse than
 * the blank it replaces, because it looks like a fact. Resolve the redirect
 * and read the address it lands on instead.
 */
const SHORT_LINK_HOSTS = new Set([
  'fb.watch',
  'fb.me',
  'vt.tiktok.com',
  'vm.tiktok.com',
  'instagr.am',
  'youtu.be',
]);

/**
 * The account named in a post URL, as `@handle` or a bare vanity name.
 *
 * TikTok and YouTube mark it with an `@`. Instagram and Facebook put it in the
 * first path segment instead, and that is where it usually is — which is the
 * whole point of this function: for both of those platforms the URL is a more
 * reliable source of the account than anything in the markup.
 */
export function handleFromUrl(url) {
  let segments;
  let host;
  try {
    const parsed = new URL(url);
    host = parsed.hostname.toLowerCase().replace(/^www\./, '');
    segments = parsed.pathname.split('/').filter(Boolean);
  } catch {
    return null;
  }
  if (SHORT_LINK_HOSTS.has(host)) return null;

  // TikTok and YouTube mark the account with an `@`, wherever it sits.
  for (const segment of segments) {
    if (segment.startsWith('@') && segment.length > 1) return segment;
  }

  // Instagram and Facebook do not. There the account is the FIRST path
  // segment, whatever follows it:
  //
  //   instagram.com/forbestravelguide/reel/DMpu7-9ue06/   → forbestravelguide
  //   facebook.com/1Nesh.D/videos/el-nido-.../6916511.../ → 1Nesh.D
  //
  // and it is absent when that first segment is one of the platform's own
  // route words instead:
  //
  //   instagram.com/reel/DMpu7-9ue06/   → none
  //   facebook.com/share/r/14twxTeWCtK/ → none (resolve the share link first)
  //
  // This used to require the path be a single segment, which is the rare case
  // — a bare profile link. Every real post URL has the account followed by
  // `/reel/`, `/p/`, `/videos/` or `/posts/`, so the guard rejected exactly
  // the URLs it was meant to read, and both Instagram and Facebook came back
  // with no handle and, because the profile URL is derived from it, no avatar.
  const [first] = segments;
  if (
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
  let page = { tags: {}, html: '', finalUrl: target, status: 0, wall: false };
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
  if (wall) page = { ...page, tags: {}, html: '' };

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

  // Where each field came from. Returned to the caller, because without it a
  // field arriving null is indistinguishable from the platform not publishing
  // it, from the page being walled, and from a parser bug — and the three need
  // completely different fixes.
  const sources = {};
  // What was tried when a field did not come from its first source. A field
  // can be missing because the platform does not publish it or because a
  // fallback was never reached, and those need different fixes.
  const fallbacks = [];
  const from = (field, source, value) => {
    if (value !== null && value !== undefined && value !== '') {
      sources[field] = source;
      return value;
    }
    return null;
  };

  const jsonLd = parseJsonLd(page.html ?? '');

  // Boilerplate is dropped before anything reads it. `og:description` on a
  // page the platform will not show is a marketing sentence, and taken as a
  // caption it reads downstream as a caption with no destination in it.
  const ogCaption = isBoilerplate(ogDescription)
    ? null
    : captionFromOgDescription(ogDescription, platform);

  const caption =
    from('caption', 'og:description', ogCaption) ??
    from(
      'caption',
      'oembed.title',
      platform === 'tiktok' || platform === 'instagram'
        ? (isBoilerplate(oembedTitle) ? null : oembedTitle)
        : null,
    ) ??
    from('caption', 'ld+json', captionFromJsonLd(jsonLd)) ??
    from(
      'caption',
      'meta[description]',
      isBoilerplate(page.tags['description']) ? null : str(page.tags['description']),
    );

  // On YouTube the title is a real title. On the caption-first platforms there
  // usually is none, and `og:title` is a truncated echo of the caption dressed
  // up with the creator's name — passing that off as a title is how a post
  // ends up called `wanderwithmia on Instagram: "we found the best…"`.
  const title =
    platform === 'youtube'
      ? (oembedTitle ?? ogTitle)
      : (oembedTitle && caption && oembedTitle === caption ? null : oembedTitle) ?? null;

  // --- the creator ---------------------------------------------------------
  //
  // Four independent sources, consulted in order of how much each platform can
  // be trusted to publish. This used to be one source — `oembed.author_url`
  // falling back to `og:see_also` — and neither exists on an Instagram or a
  // Facebook post page, so Facebook (which publishes no keyless oEmbed at all)
  // had nothing whatever to read a creator from.
  const ldCreator = creatorFromJsonLd(jsonLd) ?? {};
  const titleCreator = creatorFromOgTitle(ogTitle, platform) ?? {};

  const creator =
    from('creator', 'oembed.author_name', str(oembed.author_name)) ??
    from('creator', 'ld+json', str(ldCreator.name)) ??
    from('creator', 'og:title', str(titleCreator.name)) ??
    from('creator', 'meta[author]', str(page.tags['author']));

  // A handle from a lookup is something only the lookup knew. One read off the
  // URL is something the app already had, so it is tracked separately and is
  // not evidence the post itself was readable.
  const lookedUpHandle =
    from('creatorHandle', 'oembed.author_unique_id', str(oembed.author_unique_id)) ??
    from('creatorHandle', 'ld+json', str(ldCreator.handle)) ??
    from('creatorHandle', 'og:title', str(titleCreator.handle)) ??
    from(
      'creatorHandle',
      'oembed.author_url',
      str(oembed.author_url) ? handleFromUrl(oembed.author_url) : null,
    ) ??
    from('creatorHandle', 'ld+json.url', str(ldCreator.url) ? handleFromUrl(ldCreator.url) : null);

  // Both URLs are tried, because either can be the one carrying the account.
  // Instagram's `og:url` is `/reel/<code>/` with the username dropped, while
  // the URL as pasted is `/forbestravelguide/reel/<code>/` — so the canonical
  // alone loses it. A Facebook share link is the other way round: `/share/r/
  // <code>/` says nothing and the canonical it redirects to carries the page.
  const handle =
    lookedUpHandle ??
    from('creatorHandle', 'canonical url', handleFromUrl(canonical)) ??
    from('creatorHandle', 'url as pasted', handleFromUrl(target));

  // The profile page is the avatar's only unauthenticated home on three of the
  // four, so a creator URL is worth deriving from a handle rather than giving
  // up when the platform published no explicit link.
  const creatorUrl =
    from('creatorUrl', 'oembed.author_url', str(oembed.author_url)) ??
    from('creatorUrl', 'ld+json', str(ldCreator.url)) ??
    from('creatorUrl', 'derived from handle', profileUrlFor(handle, platform));

  // The post's cover image. Kept strictly apart from the avatar below: they
  // are different pictures and showing one for the other is worse than showing
  // neither.
  const thumbnail =
    from(
      'thumbnailUrl',
      'oembed.thumbnail_url',
      normaliseImageUrl(unescapeUrl(oembed.thumbnail_url), canonical),
    ) ??
    from(
      'thumbnailUrl',
      'og:image',
      normaliseImageUrl(unescapeUrl(page.tags['og:image']), page.finalUrl),
    );

  // --- the avatar ----------------------------------------------------------
  //
  // Three sources, cheapest first. The profile fetch is one extra request, so
  // it only runs when the page itself gave nothing — which is what made this
  // unreliable before: the profile page was the ONLY source, and TikTok and
  // Instagram both answer one with a sign-in wall often enough to matter.
  let avatar =
    from('creatorAvatarUrl', 'ld+json', normaliseImageUrl(unescapeUrl(ldCreator.image), page.finalUrl)) ??
    from(
      'creatorAvatarUrl',
      'embedded json',
      normaliseImageUrl(avatarFromEmbeddedJson(page.html ?? ''), page.finalUrl),
    );

  let creatorName = creator;
  if (withAvatar && creatorUrl && (avatar === null || creatorName === null)) {
    const profile = await readCreatorProfile(creatorUrl, fetchImpl);
    fallbacks.push(`profile page (${creatorUrl}): ${profile.status}`);

    if (avatar === null) {
      avatar = from('creatorAvatarUrl', 'profile page og:image', profile.avatar);
    }
    // Only ever a name the profile page stated. Never the handle dressed up as
    // a display name, and never derived from the URL.
    if (creatorName === null) {
      creatorName = from('creator', 'profile page og:title', profile.name);
    }
  }

  // Never the post's own cover image. If the two ever come out equal, the
  // avatar source was really the post image and must be dropped.
  if (avatar !== null && thumbnail !== null && avatar === thumbnail) {
    avatar = null;
    sources.creatorAvatarUrl = 'rejected: same image as the post thumbnail';
  }

  const readAnything = Boolean(title || caption || creator || lookedUpHandle);

  return {
    platform,
    url: target,
    canonicalUrl: canonical === target ? null : canonical,
    title,
    caption,
    hashtags: hashtagsFrom(caption ?? ''),
    creator: creatorName,
    creatorHandle: handle ? (handle.startsWith('@') ? handle : `@${handle}`) : null,
    creatorUrl,
    // Never the post thumbnail. A face that is not the creator's is worse than
    // the initial the UI draws when there is none.
    creatorAvatarUrl: avatar,
    thumbnailUrl: thumbnail,
    mediaType: mediaTypeFrom(page.tags, oembed, canonical, platform),
    // Which source each field came from, or why one was rejected. This is the
    // difference between "the platform does not publish it" and "the parser
    // missed it", which is otherwise indistinguishable from a null.
    sources,
    fallbacks,
    diagnostics: {
      pageStatus: page.status,
      pageBytes: (page.html ?? '').length,
      finalUrl: page.finalUrl,
      oembedAnswered: Object.keys(oembed).length > 0,
      jsonLdBlocks: jsonLd.length,
      loginWall: wall,
      metaTagCount: Object.keys(page.tags).length,
    },
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
