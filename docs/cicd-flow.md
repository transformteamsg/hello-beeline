# CI/CD flow: GitHub + GitLab + Beeline

How a push to `main` reaches the live app. Based on the Beeline platform
architecture (platform `README.md`, §2). Key point: **GitHub CI does not
trigger the GitLab deploy pipeline directly — Beeline does**, after it receives
the build-success webhook.

## Sequence

```mermaid
sequenceDiagram
    actor Dev as You
    participant GH as GitHub repo<br/>transformteamsg/hello-beeline
    participant GHA as GitHub Actions<br/>build-and-push.yaml
    participant ECR as AWS ECR (mgmt 787257787447)<br/>transform/hello-beeline
    participant BL as Beeline platform
    participant Infra as Central infra repo (GitLab)<br/>.gitlab/hello-beeline/trunk-pipeline.yml
    participant ECS as AWS ECS (lower 677450898165)<br/>transform-dev-hello-beeline-main
    participant URL as https://dev-hello-beeline.edutech.works

    Dev->>GH: push commit to main
    GH-->>BL: webhook (push event)
    GH->>GHA: run workflow on push:main
    Note over GHA,ECR: assume AWS_ROLE_ARN via OIDC<br/>(trust: repo:transformteamsg/*)
    GHA->>ECR: build image, push :<git-sha> and :latest
    GHA-->>BL: webhook (build succeeded)
    BL->>Infra: create pipeline via GitLab API<br/>inputs: project=hello-beeline,<br/>target_env=dev, image_tag=<git-sha>
    Note over Infra: plan (dev/hello-beeline)<br/>then deploy (dev/hello-beeline)
    Infra->>ECS: terragrunt apply + force new deployment<br/>image tag <git-sha>
    ECS->>ECR: pull image :<git-sha>
    ECS->>URL: task healthy → registers in target group
    BL->>Infra: poll pipeline status
    BL-->>Dev: build + deploy status in Beeline UI
```

## Component map (who owns what)

```mermaid
flowchart LR
    subgraph GitHub["GitHub (app repo)"]
        A[push to main] --> B[build-and-push.yaml]
    end
    subgraph MGMT["AWS acct.mgmt 787257787447"]
        ECR[(ECR: transform/hello-beeline)]
        ROLE[GitHub OIDC role<br/>trust: repo:transformteamsg/*]
    end
    subgraph BL[Beeline platform]
        WH[webhook receiver] --> TRIG[GitLab create-pipeline API]
    end
    subgraph GitLab["Central infra repo (GitLab)"]
        PIPE[trunk-pipeline.yml<br/>plan + deploy, dev-only]
    end
    subgraph LOWER["AWS acct.lower 677450898165"]
        ECSsvc[ECS: transform-dev-hello-beeline-main]
        ALB[ALB: transform-dev-hello-beeline-alb]
        R53[route53 alias]
    end

    B -->|OIDC assume| ROLE
    B -->|push :sha / :latest| ECR
    B -.->|build webhook| WH
    A -.->|push webhook| WH
    TRIG -->|inputs: project/target_env/image_tag| PIPE
    PIPE -->|apply + force deploy| ECSsvc
    ECSsvc -->|pull image| ECR
    ALB --> ECSsvc
    R53 --> ALB
    R53 --> LiveURL[dev-hello-beeline.edutech.works]
```

## Notes

- **Deployed image tag is the git SHA** (`github.sha` from the workflow), not a
  placeholder. A manual `terragrunt apply` with a non-existent tag (e.g.
  `abcde`) causes `CannotPullContainerError`; the real flow feeds a valid SHA
  that exists in ECR.
- **Beeline is the trigger, not GitHub.** For the automated path, Beeline must
  receive the build-success webhook and be configured to call the GitLab
  pipeline with `project=hello-beeline, target_env=dev`. The same pipeline can
  be triggered manually (GitLab Run pipeline with those inputs); the infra side
  is identical.
- **Two AWS accounts**: the image lives in **mgmt**; the running service, ALB,
  and DNS live in **lower**. ECS in lower pulls cross-account from the mgmt ECR.
