# Beeline — Agent Handoff Context

> Context for an AI agent starting a fresh session on Beeline. Dense by design.
> Verified against the repos as of 2026-08-05. Read the linked docs for depth.

## Repos (two connected folders)
- **`platform`** — the Beeline app (Next.js, App Router, Server Functions, Prisma + PostgreSQL). GitHub: `transformteamsg/platform`.
- **`dxd-transform-infrastructure`** — central infra-as-code (Terraform/Terragrunt) + the GitLab deploy pipeline. GitLab: `wog/moe/dxdtransform/...`.

## What Beeline is
An in-house, GovTech-approved **self-serve deployment platform** (a narrow "Vercel for Transform"): lets non-engineers take a Git repo → production on AWS and monitor deploys, without an engineer at deploy time. Founding decision: `platform/docs/adr/origin-build-platform-for-non-engineer-self-serve-deployment.md` (mirrored as infra `docs/adr/0002`).

## Architecture / end-to-end flow
Three repos + AWS. User pushes to `main` → **app repo's own CI builds image, pushes to ECR** → GitHub/GitLab **webhook to Beeline** → Beeline **triggers the deploy pipeline in the infra repo via the GitLab pipeline API** (`app`, `image_tag`, `env`) → Beeline polls + shows build/deploy status.
- Build & push = app repo CI (GitHub). Deploy = infra repo (GitLab).
- Beeline deploys **itself** the same way: `svc.platform` (infra) + `.github/workflows/platform.yaml` build + `.gitlab/platform` deploy → `dev-platform.edutech.works`.

## Environments / AWS
- Envs: `dev`, `stg`, `mgmt` (hosts ECR), `prd`. **DEV applies directly; STG/MGMT/PRD require MR + DevOps approval via Atlantis.**
- AWS accounts: `acct.lower` (dev), `acct.mgmt` (ECR), `acct.stg`, `acct.prd`. Region `ap-southeast-1`. Clusters `transform-<env>-cluster`.
- aws-vault roles: `dxd-transform-{lower-dev,stg-dev,prd-dev}-role`.

## Key code locations (`platform`)
- `lib/deployments/deploy.ts` — `deploy()` (creates GitLab pipeline + `Deployment` row), `autoDeployToDev()`, `assertNotRollback`, `assertDeployAllowed`.
- `lib/gitlab/pipeline.ts` — `createPipeline()` (real POST to GitLab pipeline API).
- `lib/github/webhook.ts` — `workflowRunEvent`; on build `completed+success` → status `READY` → `autoDeployToDev(...)`.
- `lib/gitlab/webhook-service.ts` — pipeline webhook → `READY` → `autoDeployToDev(...)`.
- `lib/builds/reconcile-ecr.ts` — ECR polling fallback; sets `READY` + auto-deploys when image appears.
- `app/lib/actions/jobs.ts` — `triggerJobRun` **(STUB: returns "Not yet implemented"; missing ECS `RunTask` + `JobRun` creation)**.
- `app/lib/actions/apps.ts`, `lib/apps/validation.ts` — app CRUD + zod schemas (incl. `autoDeployDev`).
- `app/devops/apps/[id]/edit/devops-app-form.tsx` — DevOps app config form.
- `components/ui/menu.tsx` — top nav (no active-state; earmarked ramp-up fix).
- `prisma/schema.prisma` — DB schema. **Do not generate migrations; edit schema only** (`AGENTS.md`).
- `worker/worker.ts`, `worker/jobs/`, `scripts/enqueue-job.ts` — pg-boss worker scaffold (async onboarding: pull repo → verify → inject Dockerfile → push).

## Implementation status (notable)
- **Auto-deploy to dev: fully wired** across GitHub, GitLab, and ECR-reconcile paths; gated by `autoDeployDev` flag + `main` branch + configured dev env. (Test: `lib/gitlab/webhook-service.test.ts`.)
- **Job run execution: stub** (`triggerJobRun`).
- **Onboarding: manual** (6 steps in `docs/app-onboarding.md`); full automation = roadmap epic #1, in progress via the worker.
- **App-repo scaffolding-injection skill: not yet published.**

## Build / test / deploy
- `npm install` → `npm run dev` (localhost:3000) → `npm run lint` → `npm run test` (Vitest) → `npm run build`.
- Worker: `npm run worker`. Enqueue: `npm run enqueue-job`.
- Infra repo setup: `npm i` (git hooks), `tenv` for pinned Terraform/Terragrunt, `export AWS_STS_REGIONAL_ENDPOINTS=regional`, run terragrunt via `aws-vault exec <role> -- terragrunt {plan,apply}`.

## Strategy in brief (drives priorities — `docs/strategy.md`, `roadmap.md`)
- **KPI:** enable products to reach production that otherwise would not.
- **Three bets:** adoption; abstraction-layer (thin Vercel-like UX over a swappable backend); Day 2 Ops (post-deploy differentiator).
- **Roadmap filter:** new features must pass bets + KPI + **thinness** tests.
- **Thinness rule (guardrail):** keep Beeline a thin UX/orchestration layer over a swappable backend (GitLab trigger today, PaaS tomorrow) behind a seam — don't add features that fatten the layer or weld it to AWS.
- **Priority:** automated TRA (roadmap #2) > post-deploy/Day 2 Ops (#3).

## Authoritative docs
- Beeline: `docs/README.md`? (see `platform/README.md`), `docs/strategy.md`, `docs/roadmap.md`, `docs/app-onboarding.md`, `docs/git-repo-integration.md`, `docs/research-vercel.md`, `docs/assessment-ledger.md`, `docs/testing-strategy.md`, `docs/ui-ux-critique.md`, `docs/adr/*`.
- Infra: `README.md`, `CONTRIBUTING.md`, `docs/adr/0001-0003`, `.agents/skills/` (`new-web-app-infra`, `new-ecs-task`, `new-service-rds-infra`, `gitlab-cicd-new-app`, `write-adr`).

## Guardrails for an agent
- **Never apply STG/PRD directly** — MR + approval only. DEV/lower may be applied directly.
- **Don't generate Prisma migrations** — edit `schema.prisma`.
- **Respect thinness** — don't couple Beeline to a single backend or bloat it to match Vercel.
- Keep steps **idempotent** (worker retries re-run steps).
- Confirm `gitLabProjectName` + a `dev` `AppEnvironment` exist before expecting a deploy to fire.

## Open questions (unverified)
- Is auto-deploy gap M2.1-03 formally closed? (Code says wired.)
- What remains for roadmap #1 beyond the onboarding worker?
- RSN vs CCE exact meanings/permissions; the "S3 bucket doesn't exist" terragrunt error (likely `init` on remote-state backend).
