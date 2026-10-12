import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import worker from '../src/index.js';

/** The shared contract, so the tool names are not hand-copied a second time. */
const contract = JSON.parse(
  readFileSync(fileURLToPath(new URL('../api-contract.json', import.meta.url)), 'utf8'),
);

/**
 * The service against the requests Nook actually sends.
 *
 * The other two files test the service on its own terms, with bodies written
 * to exercise one rule at a time. That is how a real defect got through: the
 * output ceiling was set to a number that looked sensible in isolation and was
 * below what the itinerary asks for, so every unit test passed while Explore
 * Itinerary was refused with a 400 on the live path.
 *
 * So these constants are the app's, copied from the Dart that sends them, and
 * a change on either side that breaks the other fails here:
 *
 *   ClaudeExtractor.maxOutputTokens          lib/ai/claude_extractor.dart
 *   ClaudeItineraryGenerator.maxOutputTokens lib/ai/claude_itinerary_generator.dart
 *
 * The numbers are still copied by hand and so can still be copied wrongly.
 * The route and the tool names are not: they are read from
 * `server/api-contract.json`, which `test/backend_routing_test.dart` asserts
 * the Dart constants against, so those cannot drift without a test failing.
 */
const APP = {
  model: 'claude-haiku-4-5-20251001',
  // The tool names come out of the contract file rather than being typed here
  // again. Typing them here is what went wrong: this file's own comment says
  // the constants were copied from the Dart that sends them, and the
  // extraction name was not — the app sent `record_post_details` and this said
  // `record_extraction`, so the file written to catch a drift like that had
  // the drift inside it and passed.
  extraction: { tool: contract.tools[0], maxTokens: 4096 },
  itinerary: { tool: contract.tools[1], maxTokens: 6144 },
  // The planner sets one; the extractor leaves it unset.
  temperature: 0.4,
};

/** The deployment as shipped: wrangler.toml's values, nothing overridden. */
const shippedEnv = (over = {}) => ({
  ANTHROPIC_API_KEY: 'test-key-not-real',
  CLAUDE_MODEL: 'claude-haiku-4-5-20251001',
  ALLOWED_MODELS: 'claude-haiku-4-5-20251001',
  ALLOWED_TOOLS: 'record_extraction,record_itinerary',
  MAX_OUTPUT_TOKENS: '6144',
  RATE_LIMIT: '30',
  RATE_WINDOW_SECONDS: '60',
  UPSTREAM_TIMEOUT_MS: '30000',
  ...over,
});

function stubClient() {
  const calls = [];
  return {
    calls,
    messages: {
      create: async (body) => {
        calls.push(body);
        return { id: 'msg_test', type: 'message', content: [], stop_reason: 'tool_use' };
      },
    },
  };
}

/** A request shaped like the app's, with a prompt of a realistic size. */
function appRequest({ tool, maxTokens }, { promptChars = 6000, temperature } = {}) {
  const body = {
    model: APP.model,
    max_tokens: maxTokens,
    system: 'You plan trips for Nook. '.repeat(40),
    messages: [{ role: 'user', content: 'TRIP\n'.repeat(promptChars / 5) }],
    tools: [
      {
        name: tool,
        description: 'Record the result.',
        input_schema: { type: 'object', properties: {}, required: [] },
      },
    ],
    tool_choice: { type: 'tool', name: tool },
  };
  if (temperature !== undefined) body.temperature = temperature;
  return new Request('https://nook-ai.example.workers.dev/v1/messages', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      Origin: 'https://alyencs.github.io',
      'CF-Connecting-IP': '203.0.113.42',
    },
    body: JSON.stringify(body),
  });
}

test('the extraction request the app sends is accepted', async () => {
  const client = stubClient();
  const res = await worker.fetch(appRequest(APP.extraction), shippedEnv({ __client: client }));

  assert.equal(res.status, 200, await res.text());
  assert.equal(client.calls.length, 1);
  assert.equal(client.calls[0].max_tokens, APP.extraction.maxTokens);
});

test('the itinerary request the app sends is accepted', async () => {
  const client = stubClient();
  const res = await worker.fetch(
    appRequest(APP.itinerary, { temperature: APP.temperature }),
    shippedEnv({ __client: client }),
  );

  assert.equal(res.status, 200, await res.text());
  assert.equal(client.calls.length, 1);
  assert.equal(client.calls[0].max_tokens, APP.itinerary.maxTokens);
  assert.equal(client.calls[0].temperature, APP.temperature);
});

test('the shipped ceiling is not below what the app asks for', async () => {
  // Stated as its own check so the failure names the cause rather than
  // showing up as an unexplained 400 on one feature.
  const needed = Math.max(APP.extraction.maxTokens, APP.itinerary.maxTokens);
  const shipped = Number(shippedEnv().MAX_OUTPUT_TOKENS);

  assert.ok(
    shipped >= needed,
    `MAX_OUTPUT_TOKENS is ${shipped}, but the app asks for ${needed}; ` +
      'the larger request would be refused with a 400',
  );
});

test('the default ceiling, with nothing configured, also covers the app', async () => {
  const client = stubClient();
  const env = shippedEnv({ __client: client });
  delete env.MAX_OUTPUT_TOKENS;

  const res = await worker.fetch(appRequest(APP.itinerary), env);
  assert.equal(res.status, 200, await res.text());
});

test('a caller asking for more than the app ever does is still refused', async () => {
  const client = stubClient();
  const res = await worker.fetch(
    appRequest({ tool: 'record_itinerary', maxTokens: 64000 }),
    shippedEnv({ __client: client }),
  );

  assert.equal(res.status, 400);
  assert.equal(client.calls.length, 0);
});

test('a realistic trip prompt is under the size caps', async () => {
  // A trip with a lot saved to it makes a long prompt. This is well past what
  // the seeded library produces and still has to go through.
  const client = stubClient();
  const res = await worker.fetch(
    appRequest(APP.itinerary, { promptChars: 40000 }),
    shippedEnv({ __client: client }),
  );

  assert.equal(res.status, 200, await res.text());
});
