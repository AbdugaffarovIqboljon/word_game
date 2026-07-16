import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

type LetterResult = "correct" | "present" | "absent";

function evaluateGuess(answer: string, guess: string): LetterResult[] {
  const result: LetterResult[] = new Array(answer.length).fill("absent");
  const answerLetters = answer.split("");
  const guessLetters = guess.split("");
  const used = new Array(answer.length).fill(false);

  for (let i = 0; i < guessLetters.length; i++) {
    if (guessLetters[i] === answerLetters[i]) {
      result[i] = "correct";
      used[i] = true;
    }
  }

  for (let i = 0; i < guessLetters.length; i++) {
    if (result[i] === "correct") continue;
    const idx = answerLetters.findIndex((c, j) => c === guessLetters[i] && !used[j]);
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

  const normalizedGuess = guess.trim().toUpperCase();
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
  const answerWord = wordRow.word.toUpperCase();

  if (normalizedGuess.length !== answerWord.length) {
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

  const results = evaluateGuess(answerWord, normalizedGuess);
  const solved = normalizedGuess === answerWord;

  const responseBody: Record<string, unknown> = { results, solved };
  if (solved || reveal_on_fail === true) {
    responseBody.answer = answerWord;
  }

  return jsonResponse(responseBody);
});
