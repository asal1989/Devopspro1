/**
 * Backend proxy for Scanova's AI features.
 *
 * The Flutter app (lib/features/ai/data/ai_service.dart) never talks
 * to Anthropic directly and never carries an API key — a key embedded
 * in a mobile app binary can always be extracted. This Cloud Function
 * holds the real key as a Firebase secret and forwards requests to the
 * Claude Messages API on the app's behalf.
 *
 * Deploy: from this `functions/` directory, `npm install`, then from
 * the project root `firebase deploy --only functions` (after
 * `firebase functions:secrets:set ANTHROPIC_API_KEY`). See the
 * README's Phase 7 section for the full one-time setup.
 *
 * Routes (POST, JSON body, matching AiService's calls):
 *   /summarize  { text }                       -> { summary, keyPoints }
 *   /classify   { text }                       -> { category }
 *   /extract    { text, kind }                 -> { fields }
 *   /ask        { text, question, history }    -> { answer }
 *   /search     { query, documents }           -> { matchingIds }
 */

const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");

const CLAUDE_MODEL = "claude-opus-5";
const ANTHROPIC_VERSION = "2023-06-01";

/** Calls the Claude Messages API and returns the parsed JSON object
 * Claude was instructed to reply with. Every prompt below asks for
 * "ONLY valid JSON" specifically so this parse step is reliable
 * without needing the structured-outputs beta. */
async function callClaudeForJson({ apiKey, system, messages }) {
  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": ANTHROPIC_VERSION,
    },
    body: JSON.stringify({
      model: CLAUDE_MODEL,
      max_tokens: 1024,
      system,
      messages,
    }),
  });

  if (!response.ok) {
    const bodyText = await response.text().catch(() => "");
    throw new Error(`Anthropic API error ${response.status}: ${bodyText.slice(0, 500)}`);
  }

  const data = await response.json();
  const textBlock = (data.content || []).find((block) => block.type === "text");
  if (!textBlock) {
    throw new Error("Claude response had no text content.");
  }

  return parseJsonLoosely(textBlock.text);
}

/** Claude is instructed to return only JSON, but strips defensively in
 * case it wraps the answer in a markdown code fence anyway. */
function parseJsonLoosely(text) {
  const trimmed = text.trim();
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const candidate = fenced ? fenced[1] : trimmed;
  return JSON.parse(candidate);
}

const EXTRACTION_GUIDANCE = {
  invoice: "vendor name, invoice number, total amount, and invoice date",
  receipt: "merchant name, total amount, date of purchase, and payment method if present",
  general: "any names, dates, and monetary amounts mentioned in the document",
};

const ROUTES = {
  async summarize({ text }, apiKey) {
    return callClaudeForJson({
      apiKey,
      system:
        "You summarize scanned documents for a mobile document scanner app. " +
        'Respond with ONLY valid JSON of the exact shape {"summary": string, "keyPoints": string[]} ' +
        "— no markdown, no code fences, no extra commentary. Keep the summary to 2-3 sentences and " +
        "keyPoints to at most 5 short bullet-style strings.",
      messages: [{ role: "user", content: String(text || "").slice(0, 20000) }],
    });
  },

  async classify({ text }, apiKey) {
    return callClaudeForJson({
      apiKey,
      system:
        "Classify a scanned document into exactly one category. Respond with ONLY valid JSON of the " +
        'exact shape {"category": string} where category is exactly one of: ' +
        "general, receipt, idCard, businessCard, certificate, form, invoice.",
      messages: [{ role: "user", content: String(text || "").slice(0, 20000) }],
    });
  },

  async extract({ text, kind }, apiKey) {
    const guidance = EXTRACTION_GUIDANCE[kind] || EXTRACTION_GUIDANCE.general;
    return callClaudeForJson({
      apiKey,
      system:
        `Extract ${guidance} from this document. Respond with ONLY valid JSON of the exact shape ` +
        '{"fields": {"<Human Readable Label>": "<value>", ...}} using clear, human-readable labels as ' +
        'keys (e.g. "Vendor", "Amount", "Date"). Omit any field you cannot find — do not guess or ' +
        "invent values.",
      messages: [{ role: "user", content: String(text || "").slice(0, 20000) }],
    });
  },

  async ask({ text, question, history }, apiKey) {
    const priorTurns = Array.isArray(history)
      ? history.map((turn) => ({ role: turn.role === "assistant" ? "assistant" : "user", content: String(turn.content || "") }))
      : [];
    return callClaudeForJson({
      apiKey,
      system:
        "Answer the user's question using ONLY the document text provided in the first message. If the " +
        "answer isn't in the document, say so plainly instead of guessing. Respond with ONLY valid JSON " +
        'of the exact shape {"answer": string}.',
      messages: [
        { role: "user", content: `Document text:\n\n${String(text || "").slice(0, 20000)}` },
        ...priorTurns,
        { role: "user", content: String(question || "") },
      ],
    });
  },

  async search({ query, documents }, apiKey) {
    const safeDocuments = Array.isArray(documents)
      ? documents.map((d) => ({ id: String(d.id || ""), name: String(d.name || ""), snippet: String(d.snippet || "").slice(0, 500) }))
      : [];
    return callClaudeForJson({
      apiKey,
      system:
        "You search a personal document library. Given a natural-language query and a list of documents " +
        "(id, name, short text snippet), return the ids of the documents that match the query, ranked most " +
        'relevant first. Respond with ONLY valid JSON of the exact shape {"matchingIds": string[]}. Return ' +
        "an empty array if nothing matches — never invent an id that wasn't provided.",
      messages: [
        {
          role: "user",
          content: JSON.stringify({ query: String(query || ""), documents: safeDocuments }),
        },
      ],
    });
  },
};

exports.aiProxy = onRequest({ secrets: [anthropicApiKey], cors: true, timeoutSeconds: 60 }, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Use POST." });
    return;
  }

  const task = req.path.replace(/^\/+/, "").split("/")[0];
  const handler = ROUTES[task];
  if (!handler) {
    res.status(404).json({ error: `Unknown AI task "${task}".` });
    return;
  }

  try {
    const result = await handler(req.body || {}, anthropicApiKey.value());
    res.status(200).json(result);
  } catch (error) {
    console.error(`AI task "${task}" failed:`, error);
    res.status(502).json({ error: "AI request failed. Please try again." });
  }
});
