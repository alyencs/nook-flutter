// The Worker over plain HTTP with a stubbed model that answers in the shape
// Nook's two tools expect, so the whole chain — browser, service, parsing,
// screens — can be exercised without a key and without spending anything.
//
// Not part of `npm test`. See server/README.md.
import { createServer } from 'node:http';
import worker from '../src/index.js';

const answers = {
  record_extraction: {
    title: 'Five quiet cafes in Kyoto',
    caption: 'Mornings in Gion before the crowds arrive.',
    creator: 'Mia',
    creator_handle: '@wanderwithmia',
    place_name: '% Arabica Higashiyama',
    address: '87-5 Hoshinocho, Higashiyama Ward',
    neighbourhood: 'Higashiyama',
    city: 'Kyoto',
    region: 'Kansai',
    country: 'Japan',
    category: 'Food',
    summary: 'A row of small coffee bars worth an early start.',
    best_time: 'Early morning, before nine',
    budget_note: 'Around 600 yen a cup',
    latitude: 34.9971,
    longitude: 135.7788,
    places: [],
  },
  record_itinerary: {
    overview: 'Three unhurried days built around the cafes and temples saved.',
    days: [
      {
        day: 1,
        title: 'Higashiyama on foot',
        activities: [
          { title: 'Coffee in Gion', description: 'Open the day at a quiet counter before the lanes fill.' },
          { title: 'Kiyomizu-dera', description: 'Walk up through the old streets while the light is still low.' },
        ],
      },
      {
        day: 2,
        title: 'North to Arashiyama',
        activities: [
          { title: 'Bamboo grove early', description: 'Arrive before the coaches to have the path to yourself.' },
          { title: 'Lunch by the river', description: 'A long sit-down between the two halves of the day.' },
        ],
      },
      {
        day: 3,
        title: 'Markets and a last cup',
        activities: [
          { title: 'Nishiki Market', description: 'Graze rather than plan; it is the best meal of the trip.' },
          { title: 'A final cafe', description: 'Somewhere to write the trip down before the train.' },
        ],
      },
    ],
  },
};

/**
 * Canned post pages, so the metadata route works with no network at all.
 *
 * The point of this server is the whole chain offline. Reading a post spends
 * nothing, so letting it reach the real platforms would be defensible — but
 * then the chain only runs where those hosts are reachable, and the captions
 * change under the test. Set `STUB_REAL_FETCH=1` to use the network instead.
 */
const pages = {
  tiktok:
    '<meta property="og:type" content="video.other">' +
    '<meta property="og:title" content="Mika on TikTok">' +
    '<meta property="og:description" content="2.1M likes, 4300 comments. &quot;₱150 lang ang unlimited wings sa Good Taste Baguio! Open 24 hours, 2nd floor pa #baguio #baguiofood #fyp&quot;">' +
    '<meta property="og:image" content="https://placehold.co/600x800?text=TikTok+post">',
  // No `og:see_also` on either: neither platform serves it, and having it here
  // is what let the parser depend on a tag that is never there in the wild.
  instagram:
    '<meta property="og:type" content="video">' +
    '<meta property="og:title" content="Nina Reyes (@nina.reyes) • Instagram reel">' +
    '<meta property="og:description" content="1,284 likes, 56 comments - nina.reyes on March 2, 2024: &quot;Three days in Kyoto and the best meal was a ¥900 set lunch at Kissa Master in Gion. Go before 11am 🍵 #kyoto #japantravel&quot;">' +
    '<meta property="og:image" content="https://placehold.co/600x800?text=Reel">' +
    '<script type="application/ld+json">' +
    '{"@type":"VideoObject","author":{"@type":"Person","name":"Nina Reyes",' +
    '"alternateName":"@nina.reyes","url":"https://www.instagram.com/nina.reyes/",' +
    '"image":"https://placehold.co/200x200?text=Nina"}}</script>',
  // Facebook's own shape: a display name in og:title and nothing else. No
  // oEmbed, no handle, no structured data.
  facebook:
    '<meta property="og:type" content="video.other">' +
    '<meta property="og:title" content="Alex Cruz">' +
    '<meta property="og:description" content="Sagada in two days: ₱800 for the cave tour, ₱2,500 a night at a homestay near the centre. The sunrise at Kiltepan is worth the 4am start 🌄">' +
    '<meta property="og:image" content="https://placehold.co/600x800?text=Facebook+reel">',
  youtube:
    '<meta property="og:type" content="video.other">' +
    '<meta property="og:title" content="5 Hidden Cafes in Kyoto">' +
    '<meta property="og:description" content="Five small coffee bars in Kyoto, all within a short walk of each other. Addresses and prices in order.">' +
    '<meta property="og:image" content="https://placehold.co/600x400?text=YouTube">',
  profile: '<meta property="og:image" content="https://placehold.co/200x200?text=Avatar">',
};

/** oEmbed, for the two providers that publish it. */
const oembeds = {
  tiktok: {
    type: 'video',
    title:
      '₱150 lang ang unlimited wings sa Good Taste Baguio! Open 24 hours, 2nd floor pa #baguio #baguiofood #fyp',
    author_name: 'Mika Eats',
    author_unique_id: 'mika.eats',
    author_url: 'https://www.tiktok.com/@mika.eats',
    thumbnail_url: 'https://placehold.co/600x800?text=TikTok+post',
  },
  youtube: {
    type: 'video',
    title: '5 Hidden Cafes in Kyoto',
    author_name: 'Wander With Mia',
    author_url: 'https://www.youtube.com/@wanderwithmia',
    thumbnail_url: 'https://placehold.co/600x400?text=YouTube',
  },
};

const stubFetch = async (url) => {
  const text = (body) => new Response(body, { status: 200 });
  const json = (body) =>
    new Response(JSON.stringify(body), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });

  if (url.includes('/oembed')) {
    if (url.includes('tiktok')) return json(oembeds.tiktok);
    if (url.includes('youtube')) return json(oembeds.youtube);
    return new Response('no oembed', { status: 404 });
  }
  // A profile page: one path segment, or an @handle with nothing after it.
  if (/^https:\/\/[^/]+\/(@?[\w.]+)\/?$/.test(url)) return text(pages.profile);
  if (url.includes('tiktok')) return text(pages.tiktok);
  if (url.includes('instagram')) return text(pages.instagram);
  if (url.includes('facebook') || url.includes('fb.watch')) return text(pages.facebook);
  if (url.includes('youtu')) return text(pages.youtube);
  return new Response('not found', { status: 404 });
};

const env = {
  ANTHROPIC_API_KEY: 'stub-no-key-needed',
  __fetch: process.env.STUB_REAL_FETCH === '1' ? fetch : stubFetch,
  ALLOWED_TOOLS: 'record_extraction,record_itinerary',
  ALLOWED_MODELS: 'claude-haiku-4-5-20251001',
  RATE_LIMIT: process.env.RATE_LIMIT ?? '200',
  __client: {
    messages: {
      create: async (body) => {
        const name = body.tools[0].name;
        let input = answers[name] ?? {};

        // The app checks that it got back the number of days it asked for, so
        // a fixed answer fails that check rather than exercising the screen.
        // Read the count out of the instructions and match it.
        if (name === 'record_itinerary') {
          const want = Number((body.system ?? '').match(/exactly (\d+) days/)?.[1] ?? 3);
          const base = answers.record_itinerary.days;
          input = {
            ...answers.record_itinerary,
            days: Array.from({ length: want }, (_, i) => ({
              ...base[i % base.length],
              day: i + 1,
            })),
          };
          console.log(`  model asked for ${name}, ${want} days`);
        } else {
          console.log(`  model asked for ${name}`);
        }

        return {
          id: 'msg_stub',
          type: 'message',
          role: 'assistant',
          model: body.model,
          stop_reason: 'tool_use',
          content: [{ type: 'tool_use', id: 'tu_1', name, input }],
        };
      },
    },
  },
};

const port = Number(process.env.PORT ?? 8787);

createServer(async (req, res) => {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  const request = new Request(`http://127.0.0.1:${port}${req.url}`, {
    method: req.method,
    headers: Object.entries(req.headers).filter(([, v]) => typeof v === 'string'),
    body: ['GET', 'HEAD'].includes(req.method) ? undefined : Buffer.concat(chunks),
  });
  const out = await worker.fetch(request, env);
  const bytes = Buffer.from(await out.arrayBuffer());
  console.log(`${req.method} ${req.url} -> ${out.status}`);
  if (out.status >= 400) {
    console.log('  refused:', bytes.toString().slice(0, 400));
    console.log('  body was:', Buffer.concat(chunks).toString().slice(0, 1500));
  }
  res.writeHead(out.status, Object.fromEntries(out.headers));
  res.end(bytes);
}).listen(port, '127.0.0.1', () => console.log(`stub service on ${port}`));
