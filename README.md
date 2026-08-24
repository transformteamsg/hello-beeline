# hello-beeline

Minimal zero-dependency Node hello-world app for the Beeline sandbox onboarding walkthrough.

## Run locally

Requires Node.js 18+.

```bash
npm start
```

The server listens on `PORT` (defaults to `3000`). To use a different port:

```bash
PORT=8080 npm start
```

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
