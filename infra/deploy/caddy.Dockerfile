# Caddy with Saarthee's config baked in (V2 TASK-13): the deployed config is versioned with the image,
# and the host needs no config bind mounts (only the Origin CA certificate directory).
# Build: docker build -f infra/deploy/caddy.Dockerfile -t saarthee-caddy:<sha> infra/deploy
FROM caddy:2.10.2-alpine
COPY caddy/api.caddy /etc/caddy/snippets/api.caddy
COPY Caddyfile /etc/caddy/Caddyfile
COPY Caddyfile.local /etc/caddy/Caddyfile.local
RUN caddy validate --config /etc/caddy/Caddyfile.local --adapter caddyfile \
  && SITE_ADDRESS=api.example.invalid caddy adapt --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null
# CADDYFILE selects the config: /etc/caddy/Caddyfile (staging/pilot, TLS) or /etc/caddy/Caddyfile.local.
ENV CADDYFILE=/etc/caddy/Caddyfile
CMD ["sh", "-c", "exec caddy run --config \"$CADDYFILE\" --adapter caddyfile"]
