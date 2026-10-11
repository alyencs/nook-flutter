// Runs the Worker over plain HTTP for a manual poke, with the upstream call
// stubbed so nothing is spent. Not part of `npm test`; see server/README.md.
import { createServer } from 'node:http';
import worker from '../src/index.js';

const env = {
  ANTHROPIC_API_KEY: 'stub',
  ALLOWED_TOOLS: 'record_extraction,record_itinerary',
  ALLOWED_MODELS: 'claude-haiku-4-5-20251001',
  RATE_LIMIT: process.env.RATE_LIMIT ?? '30',
  __client: {
    messages: {
      create: async (body) => ({
        id: 'msg_stub',
        type: 'message',
        role: 'assistant',
        model: body.model,
        stop_reason: 'tool_use',
        content: [
          { type: 'tool_use', id: 'tu_1', name: body.tools[0].name, input: { ok: true } },
        ],
      }),
    },
  },
};

createServer(async (req, res) => {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  const request = new Request(`http://127.0.0.1:8787${req.url}`, {
    method: req.method,
    headers: Object.entries(req.headers).filter(([, v]) => typeof v === 'string'),
    body: ['GET', 'HEAD'].includes(req.method) ? undefined : Buffer.concat(chunks),
  });
  const out = await worker.fetch(request, env);
  res.writeHead(out.status, Object.fromEntries(out.headers));
  res.end(Buffer.from(await out.arrayBuffer()));
}).listen(8787, '127.0.0.1', () => console.log('listening on 8787'));
