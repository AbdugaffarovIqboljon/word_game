import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

type LetterResult = "correct" | "present" | "absent";

// U+02BB — the modifier letter the corpus uses for oʻ / gʻ.
const MOD = "ʻ";

/**
 * Split an Uzbek Latin word into LOGICAL letters, where oʻ, gʻ, sh, ch, ng
 * each count as ONE letter — identical to the app's WordTokenizer and the
 * corpus build (tool/corpus/uz_letters.py), greedy left-to-right.
 *
 * Scoring MUST happen in logical-letter space: the board has 5 tiles for
 * every word, but raw char length varies (MITING = 6 chars / 5 letters), so
 * char-level comparison rejects legitimate guesses and returns result arrays
 * the client cannot map to tiles.
 */
function logicalLetters(word: string): string[] {
  // fold apostrophe variants a client keyboard might produce into U+02BB
  const s = word.trim().toUpperCase().replace(/[‘’'`ʼ]/g, MOD);
  const tokens: string[] = [];
  let i = 0;
  while (i < s.length) {
    const two = s.slice(i, i + 2);
    if (
      two === `O${MOD}` || two === `G${MOD}` ||
      two === "SH" || two === "CH" || two === "NG"
    ) {
      tokens.push(two);
      i += 2;
      continue;
    }
    tokens.push(s[i]);
    i += 1;
  }
  return tokens;
}

function evaluateGuess(answer: string[], guess: string[]): LetterResult[] {
  const result: LetterResult[] = new Array(answer.length).fill("absent");
  const used = new Array(answer.length).fill(false);

  for (let i = 0; i < guess.length; i++) {
    if (guess[i] === answer[i]) {
      result[i] = "correct";
      used[i] = true;
    }
  }

  for (let i = 0; i < guess.length; i++) {
    if (result[i] === "correct") continue;
    const idx = answer.findIndex((c, j) => c === guess[i] && !used[j]);
    if (idx !== -1) {
      result[i] = "present";
      used[idx] = true;
    }
  }

  return result;
}

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  let body: { puzzle_date?: string; guess?: string; reveal_on_fail?: boolean };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const { puzzle_date, guess, reveal_on_fail } = body;
  if (!puzzle_date || !guess) {
    return jsonResponse({ error: "missing_fields" }, 400);
  }

  const guessLetters = logicalLetters(guess);
  const normalizedGuess = guessLetters.join("");
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const { data: puzzle, error: puzzleError } = await supabase
    .from("daily_puzzles")
    .select("puzzle_date, word_id, words(word, length)")
    .eq("puzzle_date", puzzle_date)
    .single();

  if (puzzleError || !puzzle) {
    return jsonResponse({ error: "puzzle_not_found" }, 404);
  }

  // Defense in depth: never evaluate against a future date, even if requested directly.
  const today = new Date().toISOString().slice(0, 10);
  if (puzzle_date > today) {
    return jsonResponse({ error: "puzzle_not_available" }, 403);
  }

  const wordRow = (puzzle as unknown as { words: { word: string; length: number } }).words;
  const answerLetters = logicalLetters(wordRow.word);
  const answerWord = answerLetters.join("");

  // Compare in logical letters — words.length stores the logical length (5).
  if (guessLetters.length !== answerLetters.length) {
    return jsonResponse({ error: "invalid_length" }, 400);
  }

  // Confirm the guess itself is a real dictionary word (not just any N letters).
  const { data: wordEntry } = await supabase
    .from("words")
    .select("id")
    .eq("normalized_word", normalizedGuess)
    .maybeSingle();

  if (!wordEntry) {
    return jsonResponse({ error: "not_a_word" }, 200);
  }

  const results = evaluateGuess(answerLetters, guessLetters);
  const solved = normalizedGuess === answerWord;

  const responseBody: Record<string, unknown> = { results, solved };
  if (solved || reveal_on_fail === true) {
    responseBody.answer = answerWord;
  }

  return jsonResponse(responseBody);
});
