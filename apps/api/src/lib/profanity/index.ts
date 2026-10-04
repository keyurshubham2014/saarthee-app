/**
 * Profanity screen for the message relay (V2 TASK-09 §5.3, REQ-S-009). Lists are English, Gujarati script and
 * transliterated Gujarati/Hindi. Matching is whole-word on Unicode-normalised (NFKC, lower-case) text, so a
 * harmless longer word that contains a listed word ("shiitake", "Scunthorpe") is not rejected.
 * The lists live in code (not .txt) so the compiled build carries them — ASSUMPTION in TASK-09 §5.6.
 * Never log the matched word or the text.
 */
import { EN_WORDS, GU_WORDS, TRANSLIT_WORDS } from './words';

function normalise(s: string): string {
  return s.normalize('NFKC').toLocaleLowerCase('en-IN');
}

const LIST = new Set([...EN_WORDS, ...GU_WORDS, ...TRANSLIT_WORDS].map(normalise));
/** Multi-word entries (e.g. "son of a bitch") are matched as token sequences. */
const PHRASES = [...LIST].filter((w) => w.includes(' ')).map((w) => w.split(' '));

/** Letters plus combining marks (Gujarati vowel signs, virama) form a word; everything else separates. */
function tokens(text: string): string[] {
  return normalise(text).match(/[\p{L}\p{M}\p{N}]+/gu) ?? [];
}

export function containsProfanity(...texts: string[]): boolean {
  for (const text of texts) {
    const t = tokens(text);
    if (t.some((w) => LIST.has(w))) return true;
    for (const p of PHRASES) {
      for (let i = 0; i + p.length <= t.length; i++) {
        if (p.every((w, j) => t[i + j] === w)) return true;
      }
    }
  }
  return false;
}
