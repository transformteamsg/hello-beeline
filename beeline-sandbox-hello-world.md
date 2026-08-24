# Trying a Sandbox App Through Beeline — Hello-World Walkthrough

This is "Option B" from the ramp-up runbook: onboard a **throwaway hello-world repo** through Beeline's 6-step onboarding flow, so you learn the *product/user* loop (repo → build → deploy → live URL) rather than the platform's own code.

> **Before you start:** onboarding is currently **manual and DevOps-run** (full automation is roadmap epic #1). Several steps need MR approval or admin access. Confirm with **Chadin** whether there's an existing sandbox/test app you should reuse instead of provisioning fresh infra. Deploy only to **`dev`** (`acct.lower`) — never touch stg/mgmt/prd for a throwaway.

---

## Step 0 — Prep

- Pick a name, e.g. `hello-beeline`. Keep it lowercase/hyphenated; it becomes the app slug, ECR repo name, and infra stack path.
- Decide the repo host. **GitHub** is the simpler path: the app's own CI (GitHub Actions) builds and pushes the image, and the Beeline GitHub App fires webhooks. GitLab works too but the only wired-up group today is `dxd-transform`.
- Confirm the **Beeline GitHub App** is already installed on the org you'll create the repo in. Webhooks are set up **once per org by an admin**, not per app — if the org isn't whitelisted, you can't onboard there.

## Step 1 — Create the throwaway repo + inject scaffolding

Create a minimal app. A one-file Next.js/Node "hello world" that listens on a port and returns 200 is enough — the point is a buildable image, not the app.

Then inject the standard scaffolding: the **Golden Dockerfile** + the **build-and-push CI** (`.github/workflows/…`) that builds the image and pushes it to ECR.

> ⚠️ There is **no published skill** that injects this scaffolding automatically (this is the `<!-- TODO: drop skill here -->` gap in `app-onboarding.md` Step 1). Copy the Dockerfile + CI workflow from an already-onboarded app, or ask Chadin for the reference scaffolding.

The image tag your build produces is the value after `--tag` in the **"Build and Push Image"** step (e.g. `sha-acdefg`) — you'll see it flow through to deploy later.

## Step 2 — Provision the ECR repo

ECR lives in the **`acct.mgmt`** account, so this needs a **commit → push → MR → tag DevOps for approval** (never applied directly).

Use the `new-web-app-infra` skill in the infra repo (`.agents/skills/new-web-app-infra/SKILL.md`).

Record two things it outputs: the **ECR repo URL** and the **GitHub OIDC Role ARN** (the CI uses the role to push images).

## Step 3 — Provision the app infrastructure (dev)

Provision the ECS service (web app behind an ALB) for **dev only**. DEV in `acct.lower` **applies directly** — no MR needed.

Also use `new-web-app-infra`. Typical dev apply:

```bash
export AWS_STS_REGIONAL_ENDPOINTS=regional
export IMAGE_TAG=dev
cd infra/states/provider.aws/acct.lower/env.dev/svc.hello-beeline/ecs-services/<svc>/
aws-vault exec dxd-transform-lower-dev-role -- terragrunt init
aws-vault exec dxd-transform-lower-dev-role -- terragrunt plan
aws-vault exec dxd-transform-lower-dev-role -- terragrunt apply
```

> If you hit **"S3 bucket doesn't exist"**, it's most likely the Terragrunt remote-state backend not initialised — `terragrunt init` in the stack usually fixes it. Confirm the exact state bucket with Chadin.

## Step 4 — Provision the CI/CD deploy pipeline

Wire the deployment pipeline into the **central infra repo** (`dxd-transform-infrastructure`, GitLab) using the `gitlab-cicd-new-app` skill.

This is the pipeline Beeline triggers via the GitLab pipeline API, passing `app`, `image_tag`, `env`. You (and later Beeline) never click the GitLab deploy button by hand — that's the whole point of the platform.

## Step 5 — Register the app in Beeline

Go to **https://dev-platform.edutech.works/apps/new** and add the app. You'll fill in the ECR URL (from Step 2), the GitHub/GitLab project, and the environments.

This is the same onboarding UI a PM would use — good to experience it from their side.

## Step 6 — Validate the full loop

1. **Push to `main`** in your hello-world repo.
2. The **app repo's CI builds the image and pushes it to ECR**; GitHub/GitLab fire a **webhook to Beeline**, which records the build.
3. Watch the build appear in Beeline and reach **`READY`**.
4. **Deploy to `dev`** — via the Deploy button in Beeline, or the GitLab `deploy` pipeline (`env=dev`, `image_tag=<sha>`). Auto-deploy to dev is wired (`autoDeployToDev`) and fires on build→READY for `main`, so it may just deploy itself if the `autoDeployDev` flag is on.
5. **Verify** the app is live at its dev URL.

> Prod deploy of a build is only allowed **after a successful dev deploy of that same build** — but for a throwaway you should stop at dev and tear it down.

## Step 7 — Tear down

Since it's disposable: `terragrunt destroy` the dev stack (via `aws-vault exec dxd-transform-lower-dev-role`), remove the app in Beeline, revert the infra-repo pipeline MR, and delete/archive the repo. Leave no orphaned ECR repo or ECS service behind.

---

## Quick reference

| Thing | Value |
|---|---|
| Onboarding UI | https://dev-platform.edutech.works/apps/new |
| Dev AWS account / role | `acct.lower` / `dxd-transform-lower-dev-role` |
| ECR account | `acct.mgmt` (needs MR + DevOps approval) |
| Region / cluster | `ap-southeast-1` / `transform-dev-cluster` |
| Infra skills | `new-web-app-infra`, `gitlab-cicd-new-app` (in `.agents/skills/`) |
| Build vs deploy | build+push = app repo CI (GitHub) · deploy = infra repo pipeline (GitLab) |

## Ask Chadin first

- Is there an **existing sandbox/test app** to reuse instead of provisioning new infra?
- Is the target org **whitelisted** in the Beeline GitHub App?
- Where's the **reference scaffolding** (Golden Dockerfile + build CI), since no skill injects it yet?
- Is `autoDeployDev` on, or should you deploy manually the first time?
