import Anthropic from '@anthropic-ai/sdk';

import { MetadataError, readMetadata } from './metadata.js';
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

/**
 * The routes this service serves, and the only ones.
 *
 * `/v1/messages` mirrors Anthropic's own path on purpose: the app points at
 * either this service or the API itself and the request is identical, so
 * nothing above the HTTP client knows or cares which is in use. The same two
 * values are pinned in `server/api-contract.json` and asserted against the
 * Flutter client, so a change on one side fails a test on the other.
 */
const MESSAGES_PATH = '/v1/messages';
const METADATA_PATH = '/v1/metadata';
const HEALTH_PATH = '/health';

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
    if (url.pathname === HEALTH_PATH) {
      return json({ status: 'ok', service: 'nook-ai' }, { origin });
    }

    // Reading a post's public metadata. Separate from the model call because
    // it costs nothing and needs no key: it is a plain GET of a public page,
    // done here rather than in the browser because a static site has an origin
    // and this does not. See src/metadata.js for what it will and will not do.
    if (url.pathname === METADATA_PATH) {
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

      // Rate limited on the same budget as the model call. It spends no tokens,
      // but it does make this service fetch a URL on a stranger's behalf, which
      // is worth bounding for its own sake.
      const metaCaller = request.headers.get('CF-Connecting-IP') ?? 'unknown';
      const metaQuota = limiterFor(env).take(metaCaller);
      if (!metaQuota.allowed) {
        return json(errorBody('rate_limit_error', 'Too many requests. Try again shortly.'), {
          status: 429,
          origin,
          headers: { 'retry-after': String(metaQuota.retryAfterSeconds) },
        });
      }

      let asked;
      try {
        const text = await request.text();
        if (text.length > LIMITS.maxBodyBytes) {
          return json(errorBody('invalid_request_error', 'The request body is too large.'), {
            status: 413,
            origin,
          });
        }
        asked = JSON.parse(text);
      } catch {
        return json(errorBody('invalid_request_error', 'The request body is not valid JSON.'), {
          status: 400,
          origin,
        });
      }

      if (asked === null || typeof asked !== 'object' || Array.isArray(asked)) {
        return json(errorBody('invalid_request_error', 'Send {"url": "..."}.'), {
          status: 400,
          origin,
        });
      }

      try {
        const metadata = await readMetadata(asked.url, {
          fetchImpl: env.__fetch ?? fetch,
          // One extra request per save. Off by default for a caller that does
          // not want it, on for the app, which does.
          withAvatar: asked.avatar !== false,
        });
        return json(metadata, { origin });
      } catch (error) {
        if (error instanceof MetadataError) {
          return json(errorBody('invalid_request_error', error.message), {
            status: error.status,
            origin,
          });
        }
        // A platform that times out or answers nonsense is not the caller's
        // fault and is not fatal: the app continues on the URL alone.
        return json(
          errorBody('api_error', 'The post could not be read from its platform.'),
          { status: 502, origin },
        );
      }
    }

    if (url.pathname !== MESSAGES_PATH) {
      // Names both paths. "Unknown endpoint." on its own sent someone looking
      // at their model configuration when the client was simply asking for
      // `/messages` — the `/v1` had been left in the client's base URL instead
      // of its request path, so the two never met. An error that says what was
      // asked for and what exists would have ended that in one request.
      return json(
        errorBody(
          'not_found_error',
          `Unknown endpoint: ${request.method} ${url.pathname}. ` +
            `This service serves POST ${MESSAGES_PATH}, POST ${METADATA_PATH} ` +
            `and GET ${HEALTH_PATH}.`,
        ),
        { status: 404, origin },
      );
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
