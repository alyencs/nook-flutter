import test from 'node:test';
import assert from 'node:assert/strict';

import worker from '../src/index.js';
import { SlidingWindow } from '../src/rate_limit.js';

/**
 * The upstream call is stubbed throughout. Nothing here reaches the network
 * or spends anything, so the whole file runs without a key.
 */
function stubClient(impl) {
  const calls = [];
  return {
    calls,
    messages: {
      create: async (body) => {
        calls.push(body);
        if (typeof impl === 'function') return impl(body);
        return { id: 'msg_test', type: 'message', content: [], stop_reason: 'tool_use' };
      },
    },
  };
}

const baseEnv = (over = {}) => ({
  ANTHROPIC_API_KEY: 'test-key-not-real',
  CLAUDE_MODEL: 'claude-haiku-4-5-20251001',
  ALLOWED_MODELS: 'claude-haiku-4-5-20251001',
  ALLOWED_TOOLS: 'record_extraction,record_itinerary',
  MAX_OUTPUT_TOKENS: '4096',
  RATE_LIMIT: '30',
  RATE_WINDOW_SECONDS: '60',
  ...over,
});

const body = () => ({
  model: 'claude-haiku-4-5-20251001',
  max_tokens: 1024,
  messages: [{ role: 'user', content: 'Five cafes in Kyoto' }],
  tools: [{ name: 'record_extraction', input_schema: { type: 'object' } }],
  tool_choice: { type: 'tool', name: 'record_extraction' },
});

function post(payload, { origin = 'https://alyencs.github.io', ip = '203.0.113.1' } = {}) {
  return new Request('https://nook-ai.example.workers.dev/v1/messages', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      Origin: origin,
      'CF-Connecting-IP': ip,
    },
    body: typeof payload === 'string' ? payload : JSON.stringify(payload),
  });
}

test('a valid request reaches the model and the answer comes straight back', async () => {
  const client = stubClient(() => ({ id: 'msg_1', content: [{ type: 'tool_use' }] }));
  const res = await worker.fetch(post(body()), baseEnv({ __client: client }));

  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { id: 'msg_1', content: [{ type: 'tool_use' }] });
  assert.equal(client.calls.length, 1);
  assert.equal(client.calls[0].model, 'claude-haiku-4-5-20251001');
});

test('the caller never supplies the key, and never sees it', async () => {
  const client = stubClient();
  const res = await worker.fetch(post(body()), baseEnv({ __client: client }));
  const text = JSON.stringify(await res.json());

  assert.ok(!text.includes('test-key-not-real'));
  // The key is not something the request carries, so it cannot be forwarded.
  assert.ok(!('api_key' in client.calls[0]));
  assert.ok(!('x-api-key' in client.calls[0]));
});

test('a rejected request never reaches the model', async () => {
  const client = stubClient();
  const res = await worker.fetch(
    post({ ...body(), tools: [{ name: 'anything', input_schema: {} }] }),
    baseEnv({ __client: client }),
  );

  assert.equal(res.status, 400);
  assert.equal(client.calls.length, 0, 'nothing was spent on an invalid request');
});

test('a body over the size cap is refused without parsing', async () => {
  const client = stubClient();
  const huge = JSON.stringify({ ...body(), system: 'x'.repeat(200 * 1024) });
  const res = await worker.fetch(post(huge), baseEnv({ __client: client }));

  assert.equal(res.status, 413);
  assert.equal(client.calls.length, 0);
});

test('malformed JSON is a 400, not a crash', async () => {
  const res = await worker.fetch(post('{not json'), baseEnv({ __client: stubClient() }));
  assert.equal(res.status, 400);
  assert.equal((await res.json()).error.type, 'invalid_request_error');
});

test('the rate limit closes after the configured number of requests', async () => {
  const client = stubClient();
  const env = baseEnv({ __client: client, RATE_LIMIT: '3', RATE_WINDOW_SECONDS: '60' });

  const codes = [];
  for (let i = 0; i < 5; i++) {
    const res = await worker.fetch(post(body(), { ip: '198.51.100.7' }), env);
    codes.push(res.status);
  }

  assert.deepEqual(codes, [200, 200, 200, 429, 429]);
  assert.equal(client.calls.length, 3, 'blocked requests cost nothing');
});

test('a rate-limited answer says how long to wait', async () => {
  const env = baseEnv({ __client: stubClient(), RATE_LIMIT: '1', RATE_WINDOW_SECONDS: '60' });
  await worker.fetch(post(body(), { ip: '198.51.100.8' }), env);
  const res = await worker.fetch(post(body(), { ip: '198.51.100.8' }), env);

  assert.equal(res.status, 429);
  assert.ok(Number(res.headers.get('retry-after')) > 0);
});

test('one caller hitting the limit does not block another', async () => {
  const env = baseEnv({ __client: stubClient(), RATE_LIMIT: '1', RATE_WINDOW_SECONDS: '60' });
  await worker.fetch(post(body(), { ip: '198.51.100.9' }), env);

  const blocked = await worker.fetch(post(body(), { ip: '198.51.100.9' }), env);
  const other = await worker.fetch(post(body(), { ip: '198.51.100.10' }), env);

  assert.equal(blocked.status, 429);
  assert.equal(other.status, 200);
});

test('an unlisted origin is refused when a list is configured', async () => {
  const env = baseEnv({
    __client: stubClient(),
    ALLOWED_ORIGINS: 'https://alyencs.github.io',
  });

  const allowed = await worker.fetch(post(body(), { origin: 'https://alyencs.github.io' }), env);
  const refused = await worker.fetch(post(body(), { origin: 'https://not-nook.example' }), env);

  assert.equal(allowed.status, 200);
  assert.equal(allowed.headers.get('access-control-allow-origin'), 'https://alyencs.github.io');
  assert.equal(refused.status, 403);
  assert.equal(refused.headers.get('access-control-allow-origin'), null);
});

test('preflight is answered without touching the model', async () => {
  const client = stubClient();
  const res = await worker.fetch(
    new Request('https://nook-ai.example.workers.dev/v1/messages', {
      method: 'OPTIONS',
      headers: { Origin: 'https://alyencs.github.io' },
    }),
    baseEnv({ __client: client }),
  );

  assert.equal(res.status, 204);
  assert.match(res.headers.get('access-control-allow-methods'), /POST/);
  assert.equal(client.calls.length, 0);
});

test('health answers without a key and without spending', async () => {
  const client = stubClient();
  const res = await worker.fetch(
    new Request('https://nook-ai.example.workers.dev/health'),
    baseEnv({ __client: client, ANTHROPIC_API_KEY: '' }),
  );

  assert.equal(res.status, 200);
  assert.equal((await res.json()).status, 'ok');
  assert.equal(client.calls.length, 0);
});

test('a deployment with no key says so, rather than failing as a bad key', async () => {
  const res = await worker.fetch(post(body()), baseEnv({ ANTHROPIC_API_KEY: '' }));
  assert.equal(res.status, 503);
  assert.match((await res.json()).error.message, /no API key configured/);
});

test('an unknown path is a 404 and a GET is a 405', async () => {
  const env = baseEnv({ __client: stubClient() });
  const wrongPath = await worker.fetch(
    new Request('https://nook-ai.example.workers.dev/v1/anything'),
    env,
  );
  const wrongMethod = await worker.fetch(
    new Request('https://nook-ai.example.workers.dev/v1/messages'),
    env,
  );

  assert.equal(wrongPath.status, 404);
  assert.equal(wrongMethod.status, 405);
});

test('an upstream failure is reported without leaking the deployment’s state', async () => {
  const client = stubClient(() => {
    throw new Error('connect ECONNREFUSED 1.2.3.4:443 using key test-key-not-real');
  });
  const res = await worker.fetch(post(body()), baseEnv({ __client: client }));
  const text = JSON.stringify(await res.json());

  assert.equal(res.status, 504);
  assert.ok(!text.includes('test-key-not-real'));
  assert.ok(!text.includes('ECONNREFUSED'));
});

test('the sliding window reopens once the window has passed', () => {
  let clock = 1_000_000;
  const window = new SlidingWindow({ limit: 2, windowMs: 1000, now: () => clock });

  assert.equal(window.take('a').allowed, true);
  assert.equal(window.take('a').allowed, true);
  assert.equal(window.take('a').allowed, false);

  clock += 1001;
  assert.equal(window.take('a').allowed, true);
});
