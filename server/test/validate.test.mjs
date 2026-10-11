import test from 'node:test';
import assert from 'node:assert/strict';

import { LIMITS, ValidationError, parseList, validateMessageRequest } from '../src/validate.js';

const config = {
  defaultModel: 'claude-haiku-4-5-20251001',
  allowedModels: ['claude-haiku-4-5-20251001'],
  allowedTools: ['record_extraction', 'record_itinerary'],
  maxOutputTokens: 4096,
  allowedOrigins: [],
  upstreamTimeoutMs: 30000,
};

/** What the app sends: one turn, one tool, forced. */
const good = () => ({
  model: 'claude-haiku-4-5-20251001',
  max_tokens: 1024,
  system: 'Extract the destination.',
  messages: [{ role: 'user', content: 'Five cafes in Kyoto' }],
  tools: [
    {
      name: 'record_extraction',
      description: 'Record what the post is about.',
      input_schema: { type: 'object', properties: {} },
    },
  ],
  tool_choice: { type: 'tool', name: 'record_extraction' },
});

const refuses = (body, fragment) => {
  let caught;
  try {
    validateMessageRequest(body, config);
  } catch (error) {
    caught = error;
  }
  assert.ok(caught instanceof ValidationError, 'expected the request to be refused');
  if (fragment) assert.match(caught.message, fragment);
  return caught;
};

test('the request the app actually sends is accepted', () => {
  const out = validateMessageRequest(good(), config);
  assert.equal(out.model, 'claude-haiku-4-5-20251001');
  assert.equal(out.max_tokens, 1024);
  assert.equal(out.messages.length, 1);
  assert.deepEqual(out.tool_choice, { type: 'tool', name: 'record_extraction' });
});

test('what comes out is rebuilt, not the object that came in', () => {
  const body = { ...good(), messages: [{ role: 'user', content: 'hi', smuggled: 1 }] };
  const out = validateMessageRequest(body, config);
  assert.deepEqual(Object.keys(out.messages[0]), ['role', 'content']);
});

test('an unknown top-level field is refused by name', () => {
  refuses({ ...good(), betas: ['anything'] }, /"betas"/);
  refuses({ ...good(), container: {} }, /"container"/);
  refuses({ ...good(), mcp_servers: [] }, /"mcp_servers"/);
  refuses({ ...good(), stream: true }, /"stream"/);
});

test('only the models this deployment enables', () => {
  refuses({ ...good(), model: 'claude-opus-5-5' }, /not enabled/);
});

test('max_tokens is capped whatever the caller asks for', () => {
  refuses({ ...good(), max_tokens: 100000 }, /may not exceed/);
  refuses({ ...good(), max_tokens: 0 }, /positive whole number/);
  refuses({ ...good(), max_tokens: 12.5 }, /positive whole number/);
});

test('a request with no tool is not this service’s business', () => {
  const body = good();
  delete body.tools;
  refuses(body, /must name one of this service/);
  refuses({ ...good(), tools: [] }, /must name one of this service/);
});

test('an unknown tool is refused', () => {
  const body = good();
  body.tools = [{ name: 'run_anything', input_schema: { type: 'object' } }];
  refuses(body, /not offered/);
});

test('server-side tools cannot be smuggled in as tools', () => {
  const body = good();
  body.tools = [{ type: 'web_search_20260209', name: 'web_search' }];
  refuses(body, /plain tool definition/);
});

test('tool_choice may not name a tool the service does not offer', () => {
  refuses(
    { ...good(), tool_choice: { type: 'tool', name: 'something_else' } },
    /not offered/,
  );
  refuses({ ...good(), tool_choice: { type: 'any' } }, /type "tool" or "auto"/);
});

test('messages must be well formed', () => {
  refuses({ ...good(), messages: [] }, /non-empty/);
  refuses({ ...good(), messages: [{ role: 'system', content: 'x' }] }, /role/);
  refuses({ ...good(), messages: [{ role: 'user', content: { any: 'shape' } }] }, /text/);
  refuses(
    { ...good(), messages: Array.from({ length: 9 }, () => ({ role: 'user', content: 'x' })) },
    /more than/,
  );
});

test('an image block is not text and is refused', () => {
  const body = good();
  body.messages = [
    { role: 'user', content: [{ type: 'image', source: { type: 'url', url: 'http://x/y.png' } }] },
  ];
  refuses(body, /must be text/);
});

test('a very long prompt is refused before it is paid for', () => {
  const body = good();
  body.messages = [{ role: 'user', content: 'x'.repeat(LIMITS.maxPromptChars + 1) }];
  refuses(body, /longer than/);
});

test('the text-block array form is accepted', () => {
  const body = good();
  body.messages = [{ role: 'user', content: [{ type: 'text', text: 'Five cafes in Kyoto' }] }];
  assert.ok(validateMessageRequest(body, config));
});

test('temperature is bounded', () => {
  assert.ok(validateMessageRequest({ ...good(), temperature: 0.4 }, config));
  refuses({ ...good(), temperature: 7 }, /between 0 and 1/);
});

test('a missing model falls back to the deployment default', () => {
  const body = good();
  delete body.model;
  assert.equal(validateMessageRequest(body, config).model, config.defaultModel);
});

test('parseList trims, drops blanks and keeps the fallback', () => {
  assert.deepEqual(parseList(' a , b ,,c '), ['a', 'b', 'c']);
  assert.deepEqual(parseList('', ['d']), ['d']);
  assert.deepEqual(parseList(undefined, ['d']), ['d']);
});
