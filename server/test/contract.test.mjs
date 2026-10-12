// The contract between the app, this service and the local stub.
//
// Everything in `worker.test.mjs` and `app_contract.test.mjs` already builds
// its own `Request` against a hardcoded `/v1/messages`, so the service was
// always tested at the path it serves — and the app was separately tested at
// the path it asked for, which was `/messages`. Both suites passed, both sides
// were self-consistent, and every deployed call returned
// `404 not_found_error: Unknown endpoint.`
//
// Nothing crossed the boundary. These tests do: the path comes out of
// `api-contract.json`, the same file `test/backend_routing_test.dart` reads on
// the Flutter side, so the app and the service cannot drift apart again
// without one of the two suites going red.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

import Anthropic from '@anthropic-ai/sdk';

import worker from '../src/index.js';

const contract = JSON.parse(
  readFileSync(fileURLToPath(new URL('../api-contract.json', import.meta.url)), 'utf8'),
);

const ORIGIN = 'https://alyencs.github.io';

/** A deployment that looks like the real one, with the model call stubbed. */
function env(overrides = {}) {
  return {
    ANTHROPIC_API_KEY: 'test-key',
    ALLOWED_TOOLS: contract.tools.join(','),
    ALLOWED_MODELS: 'claude-haiku-4-5-20251001',
    RATE_LIMIT: '1000',
    __client: {
      messages: {
        create: async (body) => ({
          id: 'msg_contract',
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
    ...overrides,
  };
}

/** The body the app actually sends, with the tool name swapped in. */
function appBody(tool = contract.tools[0]) {
  return {
    model: 'claude-haiku-4-5-20251001',
    max_tokens: 1024,
    messages: [{ role: 'user', content: 'Extract this post.' }],
    tools: [{ name: tool, input_schema: { type: 'object' } }],
    tool_choice: { type: 'tool', name: tool },
  };
}

function request(path, { method = contract.method, body = appBody(), origin = ORIGIN } = {}) {
  return new Request(`https://nook-ai.example.workers.dev${path}`, {
    method,
    headers: { 'content-type': 'application/json', origin },
    body: method === 'GET' || method === 'OPTIONS' ? undefined : JSON.stringify(body),
  });
}

test('the service serves exactly the path the contract names', async () => {
  const res = await worker.fetch(request(contract.messagesPath), env());

  assert.equal(res.status, 200, 'the contract path must be the one that works');
  const json = await res.json();
  assert.equal(json.type, 'message');
  assert.equal(json.content[0].name, contract.tools[0]);
});

test('the path the app used to ask for is refused, and the error says why', async () => {
  // This is the exact request the deployed build was making. It has to keep
  // failing — the fix is the app asking for the right path, not this service
  // quietly answering both.
  const res = await worker.fetch(request('/messages'), env());

  assert.equal(res.status, 404);
  const json = await res.json();
  assert.equal(json.error.type, 'not_found_error');
  assert.match(
    json.error.message,
    new RegExp(contract.messagesPath),
    'the 404 has to name the path that does exist, or the next person debugs blind',
  );
  assert.match(json.error.message, /\/messages/);
});

test('other unsupported routes are refused the same way', async () => {
  for (const path of ['/', '/v1', '/v1/messages/extra', '/v2/messages', '/api/messages']) {
    const res = await worker.fetch(request(path), env());
    assert.equal(res.status, 404, `${path} should not be served`);
    assert.equal((await res.json()).error.type, 'not_found_error');
  }
});

test('health is a GET and never reports whether a key is set', async () => {
  const withKey = await worker.fetch(request(contract.healthPath, { method: 'GET' }), env());
  const without = await worker.fetch(
    request(contract.healthPath, { method: 'GET' }),
    env({ ANTHROPIC_API_KEY: undefined }),
  );

  assert.equal(withKey.status, 200);
  assert.equal(without.status, 200);
  assert.deepEqual(await withKey.json(), await without.json());
});

test('the wrong method on the right path is a 405, not a 404', async () => {
  const res = await worker.fetch(
    request(contract.messagesPath, { method: 'GET' }),
    env(),
  );

  assert.equal(res.status, 405, 'a 404 here would send someone hunting the path again');
  assert.equal(res.headers.get('allow'), 'POST, OPTIONS');
});

test('a preflight on the contract path answers with what the app sends', async () => {
  const res = await worker.fetch(
    request(contract.messagesPath, { method: 'OPTIONS' }),
    env(),
  );

  assert.equal(res.status, contract.corsPreflight.status);
  assert.equal(
    res.headers.get('access-control-allow-headers'),
    contract.corsPreflight.allowHeaders,
  );
  assert.equal(
    res.headers.get('access-control-allow-methods'),
    contract.corsPreflight.allowMethods,
  );
});

test('an operation outside the allowlist is refused', async () => {
  const res = await worker.fetch(
    request(contract.messagesPath, { body: appBody('summarise_anything') }),
    env(),
  );

  assert.equal(res.status, 400, 'the tool allowlist is what stops this being a chat endpoint');
  assert.equal((await res.json()).error.type, 'invalid_request_error');
});

test('both contracted operations are accepted', async () => {
  for (const tool of contract.tools) {
    const res = await worker.fetch(
      request(contract.messagesPath, { body: appBody(tool) }),
      env(),
    );
    assert.equal(res.status, 200, `${tool} is a supported operation`);
    assert.equal((await res.json()).content[0].name, tool);
  }
});

test('an upstream failure comes back in the shape the app parses', async () => {
  const res = await worker.fetch(
    request(contract.messagesPath),
    env({
      __client: {
        messages: {
          create: async () => {
            // A real SDK error, not a plain one with a `status` bolted on:
            // `failure()` branches on `instanceof`, so a hand-rolled object
            // takes the unreachable-upstream path and the mapping this test
            // exists to check never runs. `worker.test.mjs` covers the plain
            // network failure (504); this covers a 5xx answer from upstream.
            throw new Anthropic.APIError(
              529,
              { type: 'error', error: { type: 'overloaded_error', message: 'Overloaded' } },
              'Overloaded',
              undefined,
            );
          },
        },
      },
    }),
  );

  assert.equal(res.status, 502, 'a 5xx upstream is the service failing, not the caller');
  const json = await res.json();
  assert.equal(json.type, contract.errorShape.type);
  assert.ok(typeof json.error.message === 'string' && json.error.message.length > 0);
});

test('a deployment with no key says so instead of looking like a bad key', async () => {
  const res = await worker.fetch(
    request(contract.messagesPath),
    env({ ANTHROPIC_API_KEY: undefined }),
  );

  assert.equal(res.status, 503);
  assert.equal((await res.json()).error.type, 'api_error');
});

// --- the metadata route ----------------------------------------------------
//
// The second half of the same contract. The app asks this service to read a
// post because it cannot read one itself: a static site making a cross-origin
// request to instagram.com is refused, which is why three of the four
// platforms reached the model as a bare URL however public the post was.

/** A deployment with the page fetch stubbed, so no platform is touched. */
function metaEnv(fetchImpl, overrides = {}) {
  return { ...env(), __fetch: fetchImpl, ...overrides };
}

const postPage = () =>
  new Response(
    '<meta property="og:title" content="Mika on TikTok">' +
      '<meta property="og:description" content="2.1M likes, 40 comments. &quot;Unlimited wings at Good Taste Baguio, ₱150 #baguio&quot;">' +
      '<meta property="og:image" content="https://cdn.test/thumb.jpg">',
    { status: 200 },
  );

test('the metadata route is the one the contract names', async () => {
  const res = await worker.fetch(
    request(contract.metadataPath, { body: { url: 'https://www.tiktok.com/@mika/video/1' } }),
    metaEnv(postPage),
  );

  assert.equal(res.status, 200);
  const json = await res.json();
  assert.equal(json.platform, 'tiktok');
  assert.equal(json.fetched, true);
  assert.match(json.caption, /Good Taste Baguio/);
});

test('reading a post needs no API key, because it spends nothing', async () => {
  const res = await worker.fetch(
    request(contract.metadataPath, { body: { url: 'https://www.tiktok.com/@mika/video/1' } }),
    metaEnv(postPage, { ANTHROPIC_API_KEY: undefined }),
  );

  assert.equal(res.status, 200, 'a deployment with no model key can still read a post');
});

test('the metadata route refuses a URL off the platform allowlist', async () => {
  // This endpoint is public and takes a URL, so this is the control that keeps
  // it from being an open proxy pointed at an internal address.
  for (const url of [
    'http://169.254.169.254/latest/meta-data/',
    'http://127.0.0.1:8787/health',
    'https://example.com/post',
    'file:///etc/passwd',
  ]) {
    const res = await worker.fetch(
      request(contract.metadataPath, { body: { url } }),
      metaEnv(() => {
        throw new Error('must never be fetched');
      }),
    );
    assert.equal(res.status, 400, url);
    assert.equal((await res.json()).error.type, 'invalid_request_error');
  }
});

test('the metadata route answers a preflight and refuses a GET', async () => {
  const preflight = await worker.fetch(
    request(contract.metadataPath, { method: 'OPTIONS' }),
    metaEnv(postPage),
  );
  assert.equal(preflight.status, contract.corsPreflight.status);

  const wrongMethod = await worker.fetch(
    request(contract.metadataPath, { method: 'GET' }),
    metaEnv(postPage),
  );
  assert.equal(wrongMethod.status, 405);
  assert.equal(wrongMethod.headers.get('allow'), 'POST, OPTIONS');
});

test('a body with no url, or no body at all, is a 400 and not a crash', async () => {
  for (const body of [{}, { url: '' }, { url: 42 }, []]) {
    const res = await worker.fetch(
      request(contract.metadataPath, { body }),
      metaEnv(postPage),
    );
    assert.equal(res.status, 400, JSON.stringify(body));
  }
});

test('a private post comes back as a reason, not as an error', async () => {
  const wall = () =>
    new Response('<title>Login • Instagram</title>', { status: 200 });

  const res = await worker.fetch(
    request(contract.metadataPath, { body: { url: 'https://www.instagram.com/p/Abc/' } }),
    metaEnv(wall),
  );

  // 200, because nothing went wrong: the post is simply not public. The app
  // shows the reason and offers manual entry.
  assert.equal(res.status, 200);
  const json = await res.json();
  assert.equal(json.fetched, false);
  assert.match(json.reason, /not public/);
});
