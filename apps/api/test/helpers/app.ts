import request from 'supertest';
import { createApp } from '../../src/app';

let app: ReturnType<typeof createApp> | undefined;

/** Supertest agent over one in-process app (no listening port). */
export function api() {
  app ??= createApp();
  return request(app);
}
