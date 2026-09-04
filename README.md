# hello-beeline

Minimal Next.js hello-world app for the Beeline sandbox onboarding walkthrough.

## Run locally

Requires Node.js 18+.

```bash
npm install
npm run dev
```

The dev server listens on [http://localhost:3000](http://localhost:3000).

For a production-style run:

```bash
npm run build
npm start
```

## Run with Docker (locally, behind the SEED proxy)

The app ships a Beeline-generated `Dockerfile` (`FROM node:24-alpine`). Building it
on a SEED device needs one extra step: SEED **intercepts TLS with a corporate
Cloudflare CA**, so the build stage's `npm ci` fails with
`SELF_SIGNED_CERT_IN_CHAIN` (or `ECONNRESET`) until that CA is trusted **inside the
build**. GitHub CI has clean egress and needs none of this, so the CA must stay a
local-only concern — we never edit the `Dockerfile`.

The setup below bakes a patched base image (`node:24-alpine` + the SEED CA) and a
`seedbuild` wrapper that transparently swaps it in for any `FROM node:24-alpine`.

### Prerequisites

```bash
brew install colima docker docker-buildx   # Docker engine + BuildKit (no Docker Desktop needed)
colima start --cpu 4 --memory 8            # 2 GB (the default) OOM-kills `next build`
```

Colima persists this sizing; if it's already running with less, resize once with
`colima stop && colima start --cpu 4 --memory 8`.

### One-time SEED setup

```bash
mkdir -p ~/.seed

# 1. Fetch the SEED Cloudflare interception CA
curl -fsSk \
  https://seed-general-public-files.s3.ap-southeast-1.amazonaws.com/seed-cloudflare-root-certs/Cloudflare_CA.pem \
  -o ~/.seed/Cloudflare_CA.pem

# 2. Patched base image: node:24-alpine that trusts the SEED CA (no apk / no network)
cat > ~/.seed/Dockerfile.node24-alpine <<'DOCKERFILE'
FROM node:24-alpine
COPY Cloudflare_CA.pem /usr/local/share/ca-certificates/seed-cloudflare-ca.crt
RUN cat /usr/local/share/ca-certificates/seed-cloudflare-ca.crt >> /etc/ssl/certs/ca-certificates.crt
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
DOCKERFILE

# 3. Build it — multi-arch so it works for native runs AND linux/amd64 ECR pushes.
#    (Multi-platform --load needs the containerd image store, which is Colima's default.)
docker buildx build --load --platform linux/amd64,linux/arm64 \
  -t node:24-alpine-seed -f ~/.seed/Dockerfile.node24-alpine ~/.seed
```

Add the wrapper to your shell (`~/.zshrc`), then `source ~/.zshrc`:

```bash
# Build images that trust the SEED CA without editing any Dockerfile.
seedbuild() {
  docker buildx build \
    --build-context node:24-alpine=docker-image://node:24-alpine-seed \
    "$@"
}
```

Re-run steps 1 and 3 whenever `node:24-alpine` updates or the CA rotates.

### Build & run

```bash
seedbuild --load -t hello-beeline .
docker run --rm -p 3000:3000 hello-beeline
```

Then hit the [endpoints](#endpoints) below on `http://localhost:3000`. On non-SEED
networks (or in CI) drop the wrapper and use `docker buildx build` directly — the
`Dockerfile` is identical either way.

### Build & push to ECR

For a real image in ECR, log in first, then build for `linux/amd64` and push.
`seedbuild` forwards every flag to `docker buildx build`, so it slots straight in:

```bash
aws-vault exec dxd-transform-mgmt-dev-role -- \
  aws ecr get-login-password --region ap-southeast-1 \
  | docker login --username AWS --password-stdin 787257787447.dkr.ecr.ap-southeast-1.amazonaws.com

TAG=$(git rev-parse HEAD)
seedbuild \
  --platform linux/amd64 \
  --provenance=false \
  -t 787257787447.dkr.ecr.ap-southeast-1.amazonaws.com/transform/hello-beeline:$TAG \
  --push .
```

The `docker login` line is unchanged — auth isn't part of the build. `--push`
publishes to ECR, so run it only when you mean to.

## Endpoints

| Path | Response |
|---|---|
| `/` | `200` — `Hello from hello-beeline!` |
| `/healthz` | `200` — `ok` (health/readiness probe) |

Quick check once it's running:

```bash
curl http://localhost:3000/
curl http://localhost:3000/healthz
```
