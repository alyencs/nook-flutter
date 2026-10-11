# Nook's AI service

A small service that holds the Anthropic API key so the web app never has to.

## Why it exists

GitHub Pages serves static files. Everything the app ships — every string in
`main.dart.js`, every bundled asset — is downloadable by anyone who opens the
page. A key compiled into that build is a published key, and no amount of
obfuscation changes it. GitHub Actions secrets do not help either: a secret
used at build time is baked into the output, and the output is the thing being
served.

So the key does not go into the build at all. It lives here, in the hosting
platform's encrypted environment, and the browser asks this service instead:

```
browser (github.io, static)  ──POST /v1/messages──▶  this service  ──key──▶  api.anthropic.com
         carries no key                              holds the key
```

The app sends the same request body it used to send directly, and gets the
same answer back, so its prompts, schemas and parsing did not change when it
moved behind this.

## What it will and will not do

The key is billable, so the endpoint is written as an allowlist. Anything not
explicitly permitted is refused before a request reaches the model:

| Control | Rule |
|---|---|
| Fields | Only `model`, `max_tokens`, `system`, `messages`, `tools`, `tool_choice`, `temperature`. An unknown field is refused by name, which keeps server tools, containers, MCP servers and beta flags out of reach. |
| Tools | A request must name `record_extraction` or `record_itinerary`. This is the main anti-abuse control: the service cannot answer a free-form question, so it is no use as a chat endpoint to someone who finds the URL. |
| Model | Must be in `ALLOWED_MODELS`. |
| Output | `max_tokens` may not exceed `MAX_OUTPUT_TOKENS`. A request over it is refused, not quietly clamped — a half-written itinerary looks like a bad model rather than a limit, and is far harder to diagnose than an error saying so. |
| Size | 128 KB of body, 8 messages, 60,000 characters of prompt. Checked before parsing. |
| Rate | `RATE_LIMIT` requests per `RATE_WINDOW_SECONDS` per caller IP. |
| Origin | With `ALLOWED_ORIGINS` set, only those origins may read the answers. |
| Timeout | `UPSTREAM_TIMEOUT_MS` on the call to the model. |
| Errors | Reported in the Messages API's own shape. Credential failures are never passed through as such — the caller is told the service is misconfigured, not that a key was rejected. |

Two limits worth being honest about:

- **The rate limit is per instance, in memory.** For a low-traffic demo this
  stops a script hammering the endpoint, which is what it is for. It is not a
  distributed counter, so a caller spread across regions sees a looser limit.
  To make it strict, move the counts into a Durable Object or KV.
- **CORS is not a security boundary.** A browser honours it; a script does
  not. The rate limit and the tool allowlist are the controls that hold.

## Deploying it

Cloudflare Workers. Free tier, no card, and the deploy is one command. Any
host that runs JavaScript works — the service is a standard `fetch` handler —
but these instructions are for Workers.

You need [Node.js](https://nodejs.org) installed.

### 1. A Cloudflare account

Sign up at <https://dash.cloudflare.com/sign-up>. Nothing to configure; the
free Workers plan is enough.

### 2. Install and log in

In a terminal, from this `server` folder:

```bash
npm install
npx wrangler login
```

`wrangler login` opens a browser to authorise the machine.

### 3. Give it the key

```bash
npx wrangler secret put ANTHROPIC_API_KEY
```

Paste the key from <https://console.anthropic.com/settings/keys> when it asks.
It is stored encrypted on the account. It is not written to any file here, it
is not printed by any later command, and it cannot be read back — only
replaced by running the command again.

### 4. Deploy

```bash
npx wrangler deploy
```

It prints the address, something like
`https://nook-ai.your-subdomain.workers.dev`. Check it:

```bash
curl https://nook-ai.your-subdomain.workers.dev/health
```

`{"status":"ok","service":"nook-ai"}` means it is up.

### 5. Point the app at it

Two places, because local and deployed builds are configured separately.

**Deployed:** in the repository, *Settings → Secrets and variables → Actions →
Variables → New repository variable*. Name `NOOK_AI_BACKEND`, value the
address from step 4. Push, and the build picks it up.

It is a *variable*, not a secret, and that is correct: the address is public
by necessity — the browser has to know where to knock — and marking it secret
would only hide it from the build log while still publishing it in the bundle.

**Locally:** put it in `nook.env` at the project root:

```
AI_BACKEND_URL=https://nook-ai.your-subdomain.workers.dev
```

### 6. Lock the origin down

Once the live site works, edit `wrangler.toml`:

```toml
ALLOWED_ORIGINS = "https://your-username.github.io"
```

and `npx wrangler deploy` again.

## Settings

All in `wrangler.toml` under `[vars]`, all public. The key is the only secret
and is never one of these.

| Variable | Default | What it does |
|---|---|---|
| `CLAUDE_MODEL` | `claude-haiku-4-5-20251001` | Used when a request names no model. Changing it here changes the model without rebuilding the app. |
| `ALLOWED_MODELS` | the above | Comma-separated list the service will accept. |
| `ALLOWED_TOOLS` | `record_extraction,record_itinerary` | The tasks on offer. |
| `MAX_OUTPUT_TOKENS` | `6144` | Ceiling on one answer. Not arbitrary: it is the largest the app itself asks for. Lower it and Explore Itinerary stops working — see the note below. |
| `RATE_LIMIT` | `30` | Requests per window, per caller. |
| `RATE_WINDOW_SECONDS` | `60` | Length of that window. |
| `UPSTREAM_TIMEOUT_MS` | `30000` | How long to wait for the model. |
| `ALLOWED_ORIGINS` | unset (any) | Comma-separated origins allowed to read answers. |

## Working on it

```bash
npm test          # 37 tests, no key needed, nothing spent
npm run dev       # wrangler dev, reads .dev.vars
```

`npm test` stubs the upstream call throughout, so the whole suite runs offline
and never reaches the model.

`test/app_contract.test.mjs` is worth knowing about. The other two files test
this service on its own terms, one rule per body, and that is how a real
defect got through: the output ceiling was first set to 4096, which reads as a
sensible number and is below the 6144 an itinerary asks for. Every unit test
passed while Explore Itinerary was refused with a 400 on the live path. That
file now holds the app's own request shapes and sizes, so a change on either
side that breaks the other fails there instead of in a browser.

Two ways to run it locally without a key:

```bash
node test/serve_local.mjs       # the handler on :8787, model stubbed
curl http://127.0.0.1:8787/health
```

```bash
PORT=8791 node test/serve_stub_model.mjs
```

The second answers in the shape Nook's two tools expect — a filled-in
extraction, and an itinerary with however many days the request asked for — so
the whole chain can be exercised from the browser without a key and without
spending anything:

```bash
flutter build web --release --dart-define=NOOK_AI_BACKEND=http://127.0.0.1:8791/v1
(cd build/web && python3 -m http.server 8080)
```

For `npm run dev` against the real model, copy `.dev.vars.example` to
`.dev.vars` and put a key in it. That file is git-ignored and is never
uploaded by `wrangler deploy`.

## Costs

Workers' free tier covers 100,000 requests a day, which a demo will not
approach. The model calls are billed by Anthropic against the key, per token.
`MAX_OUTPUT_TOKENS` and the rate limit are what bound that; lower them if the
address ever gets attention you did not expect.
