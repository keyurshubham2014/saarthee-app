/**
 * Injectable clock (TASK-08 §6 step 4). Services call `now()` instead of `new Date()` where tests need to
 * control time (quiet hours, expiry). Tests use `setClock(() => fixedDate)` and `resetClock()`.
 */
let source: () => Date = () => new Date();

export function now(): Date {
  return source();
}

export function setClock(fn: () => Date): void {
  source = fn;
}

export function resetClock(): void {
  source = () => new Date();
}
