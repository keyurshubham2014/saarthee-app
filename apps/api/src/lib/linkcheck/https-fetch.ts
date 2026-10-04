import { constants } from 'node:crypto';
import https from 'node:https';
import type { FetchLike } from './index';
import { LINK_CHECK_CA } from './intermediates';

/**
 * Default transport for the link checker: `node:https` with legacy TLS renegotiation allowed.
 * ahmedabadcity.gov.in (checked 2026-10-04) still needs unsafe legacy renegotiation, which OpenSSL 3 /
 * Node's fetch refuse (`ERR_SSL_UNSAFE_LEGACY_RENEGOTIATION_DISABLED`) while browsers and curl open it.
 * The checker only sends HEAD/GET without cookies or credentials, so relaxing this for it alone is safe;
 * certificate verification stays on (with the missing public intermediates added, see intermediates.ts).
 * Bodies are never read.
 */
export const httpsFetch: FetchLike = (url, init) =>
  new Promise((resolve, reject) => {
    const req = https.request(
      url,
      {
        method: init.method,
        headers: init.headers,
        secureOptions: constants.SSL_OP_LEGACY_SERVER_CONNECT,
        ca: LINK_CHECK_CA,
        signal: init.signal,
      },
      (res) => {
        res.destroy();
        resolve({
          status: res.statusCode ?? 0,
          headers: { get: (name: string) => {
            const v = res.headers[name.toLowerCase()];
            return Array.isArray(v) ? (v[0] ?? null) : (v ?? null);
          } },
          body: null,
        });
      },
    );
    req.on('error', (err: NodeJS.ErrnoException) => {
      if (err.name === 'AbortError' && init.signal.reason instanceof Error) {
        reject(Object.assign(new Error('timeout'), { name: init.signal.reason.name }));
        return;
      }
      reject(Object.assign(new Error('request failed'), { cause: { code: err.code, name: err.name } }));
    });
    req.end();
  });
