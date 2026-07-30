# MediGuide infrastructure

The `infra` directory is the single deployment entry point for the MediGuide
backend, AI workers, dashboard, data services, Ollama, and public Clinical
Guidelines Platform.

## Compose files

- `docker-compose.yml` is the production-oriented base stack. The Guidelines
  Platform is built as static assets and served by unprivileged Nginx.
- `docker-compose.dev.yml` adds local database ports and replaces the
  Guidelines service with Vite, source mounting, and hot reload.
- `development.env` contains safe local defaults.
- `production.env.example` documents production variables. Copy it to the
  ignored `production.env` and replace every placeholder before deployment.

Application-specific container assets live with their application. The
Guidelines Dockerfiles, Nginx configuration, and runtime configuration scripts
are in `../guidelines-platform`; Compose and environment orchestration remain
in `infra`.

Both environments use the same Compose project and `guidelines` service. The
Guidelines application is started, stopped, inspected, and networked as part of
the complete MediGuide stack.

## Development

From the repository root:

```bash
make config
make up
make ps
make guidelines-logs
```

Default local endpoints:

| Service | URL |
|---|---|
| Guidelines Platform | <http://localhost:5173> |
| Dashboard | <http://localhost:3000> |
| API | <http://localhost:8080> |
| MinIO | <http://localhost:9000> |
| MinIO console | <http://localhost:9001> |
| PostgreSQL | `localhost:5433` |

`make down` preserves named data volumes. Use `make reset` only when the local
PostgreSQL, MinIO, Ollama, and frontend dependency volumes should be deleted.

## Production

Create the ignored environment file and replace all placeholder credentials and
public URLs:

```bash
cp infra/production.env.example infra/production.env
make prod-config
make prod-up
make prod-ps
```

The production stack does not publish PostgreSQL or MinIO directly to the host.
The API, dashboard, and guidelines ports remain configurable for connection to
the deployment's reverse proxy.

To use prebuilt images:

```bash
make prod-pull
docker compose --env-file infra/production.env \
  -f infra/docker-compose.yml up -d --no-build
```

## Guidelines health check

Production exposes a dedicated endpoint:

```bash
curl --fail http://localhost:8081/healthz
```

The Nginx service provides immutable asset caching, no-cache HTML and runtime
configuration, security headers, gzip compression, and SPA fallback for deep
reader URLs.
