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
