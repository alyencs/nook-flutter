/**
 * What the backend will accept, and nothing else.
 *
 * The service holds a billable key, so the safe way to think about this file
 * is that anything it lets through is something a stranger can spend money on.
 * It is therefore an allowlist from top to bottom: an unknown top-level field
 * is a rejection, not something to ignore. That also keeps the whole surface
 * of the Messages API out of reach — server tools, containers, MCP servers,
 * beta flags and anything added to the API later can only arrive as a field
 * this file has never heard of.
 *
 * The strongest control is the tool allowlist. Nook only ever asks for two
 * things, and both come back through a forced tool call with a schema the app
 * defines. A request that does not name one of those tools is not Nook's, so
 * the service is no use as a general chat endpoint even to someone who knows
 * the URL.
 */

/** Everything a request may carry. Anything else is refused by name. */
const ALLOWED_KEYS = new Set([
  'model',
  'max_tokens',
  'system',
  'messages',
  'tools',
  'tool_choice',
  'temperature',
]);

/** Roles a message may take. No `system` role: that is the `system` field. */
const ALLOWED_ROLES = new Set(['user', 'assistant']);

export const LIMITS = {
  /** Bytes of JSON. A post is a title, a caption and some metadata. */
  maxBodyBytes: 128 * 1024,
  /** Turns. Both of Nook's calls are single-shot. */
  maxMessages: 8,
  /** Characters of prompt across every message and the system field. */
  maxPromptChars: 60000,
  /** Tool definitions. Nook sends exactly one. */
  maxTools: 2,
};

export class ValidationError extends Error {
  constructor(message, { status = 400, field } = {}) {
    super(message);
    this.name = 'ValidationError';
    this.status = status;
    this.field = field;
  }
}

const fail = (message, field) => {
  throw new ValidationError(message, { field });
};

/** Comma-separated configuration, trimmed, with blanks dropped. */
export function parseList(value, fallback = []) {
  if (typeof value !== 'string' || value.trim() === '') return fallback;
  return value
    .split(',')
    .map((entry) => entry.trim())
    .filter((entry) => entry !== '');
}

/**
 * Checks one request and returns the exact object to pass on.
 *
 * The returned object is rebuilt field by field rather than handed back as it
 * arrived, so a key that slipped past the check above still cannot reach the
 * model.
 */
export function validateMessageRequest(raw, config) {
  if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) {
    fail('The request body must be a JSON object.');
  }

  for (const key of Object.keys(raw)) {
    if (!ALLOWED_KEYS.has(key)) {
      fail(`The field "${key}" is not accepted by this service.`, key);
    }
  }

  // --- model ---------------------------------------------------------------
  const model = raw.model ?? config.defaultModel;
  if (typeof model !== 'string') fail('"model" must be a string.', 'model');
  if (!config.allowedModels.includes(model)) {
    fail(`The model "${model}" is not enabled on this service.`, 'model');
  }

  // --- max_tokens ----------------------------------------------------------
  const maxTokens = raw.max_tokens ?? config.maxOutputTokens;
  if (!Number.isInteger(maxTokens) || maxTokens < 1) {
    fail('"max_tokens" must be a positive whole number.', 'max_tokens');
  }
  if (maxTokens > config.maxOutputTokens) {
    fail(
      `"max_tokens" may not exceed ${config.maxOutputTokens} on this service.`,
      'max_tokens',
    );
  }

  // --- messages ------------------------------------------------------------
  const messages = raw.messages;
  if (!Array.isArray(messages) || messages.length === 0) {
    fail('"messages" must be a non-empty array.', 'messages');
  }
  if (messages.length > LIMITS.maxMessages) {
    fail(
      `"messages" may not hold more than ${LIMITS.maxMessages} entries.`,
      'messages',
    );
  }
  for (const [index, message] of messages.entries()) {
    if (message === null || typeof message !== 'object' || Array.isArray(message)) {
      fail(`messages[${index}] must be an object.`, 'messages');
    }
    if (!ALLOWED_ROLES.has(message.role)) {
      fail(`messages[${index}].role must be "user" or "assistant".`, 'messages');
    }
    if (!isTextLike(message.content)) {
      fail(`messages[${index}].content must be text.`, 'messages');
    }
  }

  // --- system --------------------------------------------------------------
  if (raw.system !== undefined && !isTextLike(raw.system)) {
    fail('"system" must be text.', 'system');
  }

  // Counted together, because the limit is about how much is being sent to be
  // read, not about which field it arrived in.
  const promptChars =
    textLength(raw.system) +
    messages.reduce((total, message) => total + textLength(message.content), 0);
  if (promptChars > LIMITS.maxPromptChars) {
    fail(
      `The prompt is longer than this service accepts (${LIMITS.maxPromptChars} characters).`,
      'messages',
    );
  }

  // --- tools ---------------------------------------------------------------
  // The anti-relay control. Nook's two calls both name a tool; a request that
  // names none is asking for free-form text, which this service does not sell.
  const tools = raw.tools;
  if (!Array.isArray(tools) || tools.length === 0) {
    fail('"tools" must name one of this service’s tasks.', 'tools');
  }
  if (tools.length > LIMITS.maxTools) {
    fail(`"tools" may not hold more than ${LIMITS.maxTools} entries.`, 'tools');
  }
  for (const [index, tool] of tools.entries()) {
    if (tool === null || typeof tool !== 'object' || Array.isArray(tool)) {
      fail(`tools[${index}] must be an object.`, 'tools');
    }
    if (typeof tool.type === 'string') {
      // Server-side tools arrive this way — web search, code execution, and
      // anything Anthropic adds later. None of them is Nook's.
      fail(`tools[${index}] must be a plain tool definition.`, 'tools');
    }
    if (!config.allowedTools.includes(tool.name)) {
      fail(`The tool "${tool.name}" is not offered by this service.`, 'tools');
    }
    if (tool.input_schema === null || typeof tool.input_schema !== 'object') {
      fail(`tools[${index}].input_schema is missing.`, 'tools');
    }
  }

  // --- tool_choice ---------------------------------------------------------
  const toolChoice = raw.tool_choice;
  if (toolChoice !== undefined) {
    if (toolChoice === null || typeof toolChoice !== 'object') {
      fail('"tool_choice" must be an object.', 'tool_choice');
    }
    if (toolChoice.type !== 'tool' && toolChoice.type !== 'auto') {
      fail('"tool_choice" must be of type "tool" or "auto".', 'tool_choice');
    }
    if (toolChoice.type === 'tool' && !config.allowedTools.includes(toolChoice.name)) {
      fail(`The tool "${toolChoice.name}" is not offered by this service.`, 'tool_choice');
    }
  }

  // --- temperature ---------------------------------------------------------
  if (raw.temperature !== undefined) {
    if (typeof raw.temperature !== 'number' || raw.temperature < 0 || raw.temperature > 1) {
      fail('"temperature" must be between 0 and 1.', 'temperature');
    }
  }

  return {
    model,
    max_tokens: maxTokens,
    messages: messages.map((message) => ({
      role: message.role,
      content: message.content,
    })),
    ...(raw.system === undefined ? {} : { system: raw.system }),
    tools,
    ...(toolChoice === undefined ? {} : { tool_choice: toolChoice }),
    ...(raw.temperature === undefined ? {} : { temperature: raw.temperature }),
  };
}

/** A string, or the text-block array form the API also accepts. */
function isTextLike(value) {
  if (typeof value === 'string') return true;
  if (!Array.isArray(value)) return false;
  return value.every(
    (block) =>
      block !== null &&
      typeof block === 'object' &&
      block.type === 'text' &&
      typeof block.text === 'string',
  );
}

function textLength(value) {
  if (typeof value === 'string') return value.length;
  if (!Array.isArray(value)) return 0;
  return value.reduce(
    (total, block) => total + (typeof block?.text === 'string' ? block.text.length : 0),
    0,
  );
}
