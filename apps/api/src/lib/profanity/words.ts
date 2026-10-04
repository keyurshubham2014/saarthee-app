/**
 * Abusive-word lists for the relay screen (TASK-09). Deliberately short and conservative: only clearly abusive
 * words, never political, caste-neutral criticism or ordinary complaint language ("useless", "corrupt",
 * "shame" are allowed). Ops extends these lists by pull request; native Gujarati review pending.
 */
export const EN_WORDS: readonly string[] = [
  'fuck', 'fucking', 'fucker', 'motherfucker', 'shit', 'bullshit', 'bitch', 'bastard', 'asshole',
  'dick', 'cunt', 'whore', 'slut', 'prick', 'wanker', 'son of a bitch',
];

export const GU_WORDS: readonly string[] = [
  'ભડવો', 'ભડવા', 'હરામી', 'હરામખોર', 'માદરચોદ', 'બહેનચોદ', 'ચુતિયા', 'રાંડ', 'લોડો', 'લવડા',
];

export const TRANSLIT_WORDS: readonly string[] = [
  'bhadvo', 'bhadva', 'bhadwa', 'harami', 'haramkhor', 'madarchod', 'madarchot', 'behenchod', 'bhenchod',
  'benchod', 'chutiya', 'chutiyo', 'chodu', 'gandu', 'randi', 'raand', 'lodo', 'lavda', 'lauda', 'loda',
];
