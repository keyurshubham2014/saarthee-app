import type { Router } from 'express';

interface Layer {
  route?: { path: string | string[]; methods: Record<string, boolean> };
  handle?: { stack?: Layer[] };
  name?: string;
}

/**
 * Lists `METHOD /path` for every route registered on an Express router, including nested routers mounted
 * without a path prefix (TASK-10 matrix test). Mounted prefixes are not resolved — staff routers use full paths.
 */
export function listRoutes(router: Router): string[] {
  const out: string[] = [];
  const walk = (stack: Layer[]) => {
    for (const layer of stack) {
      if (layer.route) {
        const paths = Array.isArray(layer.route.path) ? layer.route.path : [layer.route.path];
        for (const method of Object.keys(layer.route.methods)) {
          if (method === '_all') continue;
          for (const p of paths) out.push(`${method.toUpperCase()} ${p}`);
        }
      } else if (layer.handle?.stack) {
        walk(layer.handle.stack);
      }
    }
  };
  walk((router as unknown as { stack: Layer[] }).stack);
  return [...new Set(out)];
}
