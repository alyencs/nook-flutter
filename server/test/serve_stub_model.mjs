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

const env = {
  ANTHROPIC_API_KEY: 'stub-no-key-needed',
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
