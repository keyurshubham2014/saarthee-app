import { config } from '../../config';
import { EmulatorFirebaseGateway } from './emulator';
import { FakeFirebaseGateway } from './fake';
import { GoogleFirebaseGateway } from './google';
import type { FirebaseGateway } from './types';

export * from './types';
export { FakeFirebaseGateway } from './fake';
export { EmulatorFirebaseGateway } from './emulator';
export { GoogleFirebaseGateway, firebaseAdminApp } from './google';

let gateway: FirebaseGateway | undefined;

function create(): FirebaseGateway {
  switch (config.FIREBASE_AUTH_MODE) {
    case 'google':
      return new GoogleFirebaseGateway();
    case 'emulator':
      return new EmulatorFirebaseGateway(config.FIREBASE_AUTH_EMULATOR_HOST, config.FIREBASE_PROJECT_ID);
    case 'fake':
      return new FakeFirebaseGateway(config.FIREBASE_PROJECT_ID);
  }
}

/** The gateway selected by FIREBASE_AUTH_MODE (created on first use). */
export function firebaseGateway(): FirebaseGateway {
  gateway ??= create();
  return gateway;
}

/** Tests only: swap the gateway (e.g. a FakeFirebaseGateway whose tokens the test issues). */
export function setFirebaseGateway(next: FirebaseGateway | undefined): void {
  gateway = next;
}
