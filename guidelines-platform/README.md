# Clinical Guidelines Platform

A React and Markdown platform for publishing multiple clinical guidelines. Uganda Clinical Guidelines is the first available publication.

The platform is the public entry point to the MediGuide ecosystem. Clinical
publications are available without authentication, while the staff login links
to the separately deployed MediGuide administration dashboard.

## Architecture

The application uses a feature-oriented structure:

```text
src/
  components/common/       Shared branding, icons, and loading states
  content/                 Publication metadata, generated index, and loaders
  features/landing/        Public landing page and publication library
  features/reader/         Markdown reader, search, and table of contents
  layouts/                 Public application shell
  lib/markdown/            Parsing, headings, paths, and navigation utilities
  styles/                  Design tokens and page-specific style layers
  types/                   Content and publication contracts
```

The main routes are:

```text
/                                                   Public guideline library
/publications/:publication                          Publication entry redirect
/publications/:publication/read/:document            Lazy-loaded reader route
```

Chapter `index.md` files contain aggregate copies of entire chapters. The
smaller documents under each chapter directory are the canonical reader
sources, preventing duplicated content and providing stable section routes.
The front matter and split documents are indexed in
`src/content/generated-manifest.json`.

The manifest contains navigation and search metadata only. Vite creates a
separate lazy chunk for each Markdown body, so opening the landing page does not
download the clinical publications.

## Requirements

Choose either Docker with Docker Compose, or Node.js `20.19+`/`22.12+` with npm.

## Development containers

All deployment files live under [`infra`](../infra). From the repository root,
start the complete development stack, including the Vite service with hot
module replacement:

```bash
make config
make up
```

Open <http://localhost:5173>. The source tree is mounted into the container, so
edits are reflected without rebuilding. The content manifest is regenerated
when the container starts.

The “Log in” button opens the Mediguide POS login page configured by
`DASHBOARD_PUBLIC_URL` in `infra/development.env`.

After changing dependencies, recreate the dependency volume:

```bash
make reset
make up
```

## Production containers

The shared production stack builds the optimized frontend and serves it with
unprivileged Nginx. Create the ignored production environment file first and
replace all placeholder values:

```bash
cp infra/production.env.example infra/production.env
make prod-config
make prod-up
```

Open <http://localhost:8081>. Port 8081 avoids the backend API's default 8080
port. The container includes:

- a non-root Nginx runtime;
- read-only root filesystem;
- dropped Linux capabilities;
- runtime dashboard URL validation;
- SPA deep-link fallback;
- immutable asset caching and compression;
- browser security headers;
- `/healthz` container health check.

Configure `DASHBOARD_PUBLIC_URL`, `GUIDELINES_PUBLIC_PORT`, image metadata, and
production credentials in `infra/production.env`.

Inspect or stop production:

```bash
make prod-ps
make prod-logs
make prod-down
```

Build or run the production image directly:

```bash
docker build \
  -f guidelines-platform/Dockerfile.prod \
  -t mediguide-guidelines:production .

docker run --rm -p 8081:8080 \
  -e MEDIGUIDE_POS_URL=https://app.example.org \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=16m \
  mediguide-guidelines:production
```

## Release process

The platform follows semantic versioning. Choose the release command based on the change:

- `patch` for backward-compatible fixes: `1.2.0` → `1.2.1`
- `minor` for backward-compatible features: `1.2.0` → `1.3.0`
- `major` for breaking changes: `1.2.0` → `2.0.0`

Start from an up-to-date, clean default branch:

```bash
git switch main
git pull --ff-only
npm ci
```

Create the appropriate version commit and Git tag:

```bash
npm run release:patch
# or: npm run release:minor
# or: npm run release:major
```

The release command runs lint and build checks, updates both `package.json` and `package-lock.json`, creates a `chore(release): vX.Y.Z` commit, and creates the matching `vX.Y.Z` Git tag. It stops if the working tree is not clean.

Inspect the result before publishing:

```bash
git show --stat HEAD
git tag --points-at HEAD
npm run release:check -- vX.Y.Z
```

Publish the release commit and tag:

```bash
npm run release:push
```

Pushing the `vX.Y.Z` tag starts the repository container workflow. Alongside
the API, AI worker, and dashboard images, it publishes the Guidelines image
with these GHCR tags:

```text
ghcr.io/<github-owner>/mediguide-pos-guidelines:X.Y.Z
ghcr.io/<github-owner>/mediguide-pos-guidelines:X.Y
ghcr.io/<github-owner>/mediguide-pos-guidelines:X
ghcr.io/<github-owner>/mediguide-pos-guidelines:sha-<commit>
```

Default-branch builds additionally publish `main` and `latest`. See
[`infra/README.md`](../infra/README.md#container-image-publishing) for the
complete image list and deployment configuration.

## Local development without Docker

```bash
npm ci
npm run dev
```

Available checks:

```bash
npm run content:manifest
npm run format:markdown
npm run lint
npm run test
npm run build
npm run verify
```

The build regenerates the content manifest automatically.

## Adding a publication

1. Add typed publication metadata to `src/content/publications.ts`.
2. Place its Markdown source in a dedicated content directory.
3. Extend `scripts/generate-content-manifest.mjs` with the publication's
   filename and ordering rules.
4. Add the new lazy Markdown glob to `src/content/content-loader.ts`.
5. Regenerate the manifest and run `npm run verify`.

Publication bodies should remain authoritative source material. Use metadata,
routes, and presentation changes to improve navigation; do not rewrite clinical
recommendations during platform maintenance.

## Configuration

Deployment environment files are managed centrally as `infra/development.env`
and `infra/production.env.example`. Create the ignored `infra/production.env`
for production values. The dashboard URL is public client configuration rather
than a credential.

The production container writes the public login configuration when it starts,
so the same immutable image can be promoted across environments. Runtime
configuration is written to a temporary filesystem, allowing the application
container to keep its root filesystem read-only. The final image contains only
Nginx and compiled static assets; Node.js, source files, and development
dependencies are excluded.
