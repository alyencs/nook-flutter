import Anthropic from '@anthropic-ai/sdk';

import { SlidingWindow } from './rate_limit.js';
import { LIMITS, ValidationError, parseList, validateMessageRequest } from './validate.js';

/**
 * Nook's AI endpoint.
 *
 * The app is a static site: everything it ships is readable by anyone who
 * opens it, so a billable key cannot live there. The key lives here instead,
 * in the platform's encrypted environment, and the browser asks this service
 * rather than the model.
 *
 * The browser sends the same request body it used to send directly. This
 * service checks it against `validate.js`, attaches the key, and passes the
 * answer back unchanged — so the app's prompts, schemas and parsing are
 * untouched by the move, and nothing here needs editing when they change.
 */

const DEFAULTS = {
  model: 'claude-haiku-4-5-20251001',
  tools: ['record_extraction', 'record_itinerary'],
  // The largest answer Nook asks for. Extraction asks for 4096 and an
  // itinerary for 6144 (ClaudeItineraryGenerator.maxOutputTokens), so a
  // ceiling below this refuses the app's own traffic rather than bounding an
  // abuser's. Raise it only alongside the app; it is what bounds one call's
  // cost.
  maxOutputTokens: 6144,
  rateLimit: 30,
  rateWindowSeconds: 60,
  upstreamTimeoutMs: 30000,
};

/** One per instance, so the counts survive between requests. */
let limiter = null;

function limiterFor(env) {
  const limit = Number(env.RATE_LIMIT ?? DEFAULTS.rateLimit);
  const windowMs = Number(env.RATE_WINDOW_SECONDS ?? DEFAULTS.rateWindowSeconds) * 1000;
  if (!limiter || limiter.limit !== limit || limiter.windowMs !== windowMs) {
    limiter = new SlidingWindow({ limit, windowMs });
  }
  return limiter;
}

function configFrom(env) {
  const defaultModel = env.CLAUDE_MODEL?.trim() || DEFAULTS.model;
  return {
    defaultModel,
    allowedModels: parseList(env.ALLOWED_MODELS, [defaultModel]),
    allowedTools: parseList(env.ALLOWED_TOOLS, DEFAULTS.tools),
    maxOutputTokens: Number(env.MAX_OUTPUT_TOKENS ?? DEFAULTS.maxOutputTokens),
    allowedOrigins: parseList(env.ALLOWED_ORIGINS),
    upstreamTimeoutMs: Number(env.UPSTREAM_TIMEOUT_MS ?? DEFAULTS.upstreamTimeoutMs),
  };
}

/**
 * Which origin, if any, this answer may be read by.
 *
 * With nothing configured the service answers anybody — convenient while
 * setting up, and worth narrowing to the live site afterwards. CORS is not a
 * security boundary in any case (a script that is not a browser ignores it);
 * the rate limit and the tool allowlist are what actually hold.
 */
function corsOrigin(request, config) {
  const origin = request.headers.get('Origin');
  if (config.allowedOrigins.length === 0) return '*';
  if (origin && config.allowedOrigins.includes(origin)) return origin;
  return null;
}

function corsHeaders(origin) {
  if (!origin) return {};
  return {
    'access-control-allow-origin': origin,
    'access-control-allow-methods': 'POST, OPTIONS',
    'access-control-allow-headers': 'content-type',
    'access-control-max-age': '86400',
    vary: 'Origin',
  };
}

function json(body, { status = 200, origin = null, headers = {} } = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      ...corsHeaders(origin),
      ...headers,
    },
  });
}

/**
 * The shape the app already knows how to read.
 *
 * Its client parses `error.message` out of a failure, so errors are reported
 * the way the Messages API reports them rather than in a format of this
 * service's own invention.
 */
function errorBody(type, message) {
  return { type: 'error', error: { type, message } };
}

export default {
  async fetch(request, env) {
    const config = configFrom(env);
    const origin = corsOrigin(request, config);
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }

    // Somewhere to point a browser at to see that the service is up, without
    // spending anything. It never reports whether a key is configured.
    if (url.pathname === '/health') {
      return json({ status: 'ok', service: 'nook-ai' }, { origin });
    }

    if (url.pathname !== '/v1/messages') {
      return json(errorBody('not_found_error', 'Unknown endpoint.'), {
        status: 404,
        origin,
      });
    }
    if (request.method !== 'POST') {
      return json(errorBody('invalid_request_error', 'Use POST.'), {
        status: 405,
        origin,
        headers: { allow: 'POST, OPTIONS' },
      });
    }
    if (origin === null) {
      return json(
        errorBody('permission_error', 'This origin is not allowed to use this service.'),
        { status: 403 },
      );
    }

    if (!env.ANTHROPIC_API_KEY) {
      // Deployed without the secret. Say so plainly rather than returning an
      // authentication failure that reads as the key being wrong.
      return json(
        errorBody(
          'api_error',
          'This service has no API key configured. Set ANTHROPIC_API_KEY on the deployment.',
        ),
        { status: 503, origin },
      );
    }

    const caller = request.headers.get('CF-Connecting-IP') ?? 'unknown';
    const quota = limiterFor(env).take(caller);
    if (!quota.allowed) {
      return json(
        errorBody('rate_limit_error', 'Too many requests. Try again shortly.'),
        {
          status: 429,
          origin,
          headers: { 'retry-after': String(quota.retryAfterSeconds) },
        },
      );
    }

    // Read as text first: a body larger than the cap is refused before it is
    // parsed, so a huge payload costs nothing but the read.
    let text;
    try {
      text = await request.text();
    } catch {
      return json(errorBody('invalid_request_error', 'The request body could not be read.'), {
        status: 400,
        origin,
      });
    }
    if (text.length > LIMITS.maxBodyBytes) {
      return json(
        errorBody('invalid_request_error', 'The request body is too large.'),
        { status: 413, origin },
      );
    }

    let raw;
    try {
      raw = JSON.parse(text);
    } catch {
      return json(errorBody('invalid_request_error', 'The request body is not valid JSON.'), {
        status: 400,
        origin,
      });
    }

    let body;
    try {
      body = validateMessageRequest(raw, config);
    } catch (error) {
      if (error instanceof ValidationError) {
        return json(errorBody('invalid_request_error', error.message), {
          status: error.status,
          origin,
        });
      }
      throw error;
    }

    const client =
      env.__client ??
      new Anthropic({
        apiKey: env.ANTHROPIC_API_KEY,
        timeout: config.upstreamTimeoutMs,
        // The app in front of this runs its own backoff and shows the person
        // what it is waiting for; a second, invisible one underneath only
        // makes the wait longer.
        maxRetries: 0,
      });

    try {
      const message = await client.messages.create(body);
      return json(message, { origin });
    } catch (error) {
      return json(...failure(error, origin));
    }
  },
};

/**
 * Turns an SDK failure into an answer, without telling the caller anything
 * about the key or this service's internals.
 */
function failure(error, origin) {
  if (error instanceof Anthropic.AuthenticationError) {
    // The caller cannot fix this and must not be told which key failed.
    return [
      errorBody('api_error', 'The AI service rejected this deployment’s credentials.'),
      { status: 502, origin },
    ];
  }
  if (error instanceof Anthropic.RateLimitError) {
    return [
      errorBody('rate_limit_error', 'The AI service is rate limiting this deployment.'),
      { status: 429, origin, headers: retryAfter(error) },
    ];
  }
  if (error instanceof Anthropic.BadRequestError) {
    return [
      errorBody('invalid_request_error', error.message),
      { status: 400, origin },
    ];
  }
  if (error instanceof Anthropic.APIError) {
    const status = typeof error.status === 'number' && error.status >= 500 ? 502 : 400;
    return [errorBody('api_error', error.message), { status, origin }];
  }
  return [
    errorBody('api_error', 'The AI service could not be reached.'),
    { status: 504, origin },
  ];
}

function retryAfter(error) {
  const header = error?.headers?.get?.('retry-after');
  return header ? { 'retry-after': header } : {};
}
