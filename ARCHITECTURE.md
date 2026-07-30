# Architecture Decisions

*URL Shortener — the "why" behind the "what"*

This document exists so that every non-trivial technical choice in this project has a defensible answer. It's written the way I'd want to explain the project in a technical interview: what I chose, what I gave up by choosing it, and how I'd change it if circumstances changed.

Each decision follows the same shape:

- **Decision** — what we're doing and the primary reason
- **Trade-off** — what we're giving up in exchange, honestly
- **How to upgrade** — one line, actionable

---

## Contents

1. [Short-code generation: nanoid vs base62 counter](#1-short-code-generation-nanoid-vs-base62-counter)
2. [Caching strategy: cache-aside vs write-through](#2-caching-strategy-cache-aside-vs-write-through)
3. [Local Kubernetes: minikube vs EKS](#3-local-kubernetes-minikube-vs-eks)
4. [Postgres orchestration: Deployment vs StatefulSet](#4-postgres-orchestration-deployment-vs-statefulset)
5. [CI/CD authentication: static IAM keys vs OIDC](#5-cicd-authentication-static-iam-keys-vs-oidc)
6. [Secrets storage: Kubernetes Secrets vs AWS Secrets Manager](#6-secrets-storage-kubernetes-secrets-vs-aws-secrets-manager)
7. [Terraform state: local vs S3 backend](#7-terraform-state-local-vs-s3-backend)

---

## 1. Short-code generation: nanoid vs base62 counter

**Decision.** We use `nanoid` with a custom URL-safe alphabet (57 characters, dropping visually ambiguous ones like `0/O` and `1/l/I`) at a length of 7 characters. That gives us `57^7 ≈ 1.95 trillion` possible codes. At 1 million stored URLs, the probability of a collision on any single generation is roughly `5 × 10⁻⁷` — vanishingly small, and we still handle it explicitly with a retry loop that gives up after three consecutive collisions. The service returns codes immediately, statelessly, from any pod, with no coordination between instances.

**Trade-off.** A base62 counter (auto-incrementing DB primary key, then base62-encoded on the way out) would guarantee zero collisions by construction and produce shorter codes at low volumes (`1` and `2` and `a` are valid short codes if you've only created three URLs). It's genuinely more storage-efficient. But it requires a coordinated sequence — every code generator has to agree on the "next number", which either serialises writes through a single source of truth or forces you into something like Twitter's Snowflake ID scheme. It also exposes creation order (anyone can enumerate `example.com/1`, `2`, `3`...) and reveals your URL count as free intel. We accept a negligible storage overhead and a defensive retry loop in exchange for a stateless generator and non-enumerable codes.

**How to upgrade.** If we ever need to shave URL length or hit billions of records, swap to a Snowflake-style 64-bit ID + base62 encoding — same statelessness, denser output.

---

## 2. Caching strategy: cache-aside vs write-through

**Decision.** We use the cache-aside pattern on `GET /:code`, the read path. The flow is: check Redis for `url:<code>` → on hit, return the redirect immediately → on miss, query Postgres, populate the cache with a 1-hour TTL, then return. The write path (`POST /shorten`) touches only Postgres — it does not warm the cache. This choice is driven entirely by the workload shape: URL shorteners are typically read-to-write ratios of 100:1 or higher, so optimising the read path is where all the leverage sits.

**Trade-off.** The most visible cost of cache-aside is that the *first* read after a write is always a cache miss — a small latency spike on the initial redirect of every new URL. Write-through would eliminate that spike by populating the cache at write time, but it does so at two costs. First, added write-path complexity (now every `POST /shorten` has to talk to two systems, and you have to reason about what happens when one succeeds and the other fails). Second, cache pollution: most short URLs are created and never redirected, so write-through fills the cache with dead entries that push useful ones out. For our workload, cache-aside is the pragmatic default.

**How to upgrade.** If we observe consistent hot-key patterns (a small number of URLs eating most redirects), add a background job that pre-warms the top-N codes from Redis analytics — or move to write-through selectively for URLs above a click-count threshold.

---

## 3. Local Kubernetes: minikube vs EKS

**Decision.** We run the whole Kubernetes stack on **minikube** locally, not on AWS EKS. The reason is boring but decisive: EKS's control plane alone costs `$0.10/hour × 730 hours = ~$73/month` before you attach a single worker node, and this is a learning project that runs intermittently. Every K8s primitive we exercise — Deployment, Service, Ingress, HorizontalPodAutoscaler, PersistentVolumeClaim, ConfigMap, Secret, probes, rolling update strategy — is *identical* on minikube and EKS. The manifests are drop-in compatible; every file in `k8s/` includes a comment where the differences would appear.

**Trade-off.** minikube can't teach you the AWS-specific integration surface: VPC networking, IAM Roles for Service Accounts (IRSA), the AWS Load Balancer Controller, EBS/EFS storage classes, Cluster Autoscaler, KMS-based envelope encryption of Secrets at rest. Those are shells and adapters around the same primitives, and they're real skills — but they're best learned on someone else's dime (a work cluster) rather than paying for the privilege on a portfolio project. In exchange for skipping them, we get instant cluster startup, zero cost, offline capability, and the ability to `minikube delete` and start over without regret.

**How to upgrade.** When you specifically want to demonstrate EKS: `eksctl create cluster --name url-shortener --region eu-west-2 --nodegroup-name t3-medium --node-type t3.medium --nodes 2` — plan for ~$100/month all in, and destroy it the moment you're done.

---

## 4. Postgres orchestration: Deployment vs StatefulSet

**Decision.** Postgres runs as a **Deployment** with a single replica and a `PersistentVolumeClaim` mounted at `/var/lib/postgresql/data`. This is the simplest workable primitive: it teaches the PVC lifecycle (claim → bind → mount → survive pod restart), it demonstrates that stateful workloads are viable on Kubernetes, and it's straightforward to reason about.

**Trade-off.** A StatefulSet is the *technically correct* primitive for stateful workloads. It gives you stable pod identities (`postgres-0`, `postgres-1`, ...), ordered startup and shutdown, and per-pod PVCs via `volumeClaimTemplates`. For a single-replica database it's overkill, but the moment you want a primary/replica pair, StatefulSet becomes the right answer — Deployments can't guarantee which pod is which. The bigger honest trade-off, though, isn't Deployment vs StatefulSet — it's *self-hosting Postgres on Kubernetes at all*. In any real production context, the answer is a managed database service. Running your own Postgres means owning storage tuning, backup schedules, failover, point-in-time recovery, and version upgrades. That's a full-time job for someone.

**How to upgrade.** Two steps. Locally: swap Deployment for StatefulSet the moment you add a second replica. In production: don't run Postgres on K8s at all — use AWS RDS (or Aurora if you want managed read replicas and multi-AZ failover). Let AWS carry the pager.

---

## 5. CI/CD authentication: static IAM keys vs OIDC

**Decision.** GitHub Actions authenticates to AWS using **static access keys** stored in GitHub Secrets — `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. The keys are attached to a dedicated IAM user with a **least-privilege policy** scoped to the specific ECR repository (only the ECR actions needed for `docker push`, and only against `arn:aws:ecr:<region>:<account>:repository/url-shortener`). This is the simplest path to a working pipeline and matches every tutorial you'll find.

**Trade-off.** Static access keys are long-lived credentials. If one leaks — via a compromised laptop, a mis-scoped log line, a curious contractor with repo access — it stays valid until someone remembers to rotate it. And nobody remembers to rotate keys. OIDC federation solves this cleanly: GitHub Actions mints a short-lived JWT for each workflow run, AWS trusts that token via an IAM OIDC Provider, and the workflow assumes an IAM role using the token. No long-lived secrets exist anywhere. The trade-off is a one-time setup cost (an OIDC provider, a trust policy, and about 50 lines of Terraform) — after which you never touch access keys again.

**How to upgrade.** Add an `aws_iam_openid_connect_provider` for `token.actions.githubusercontent.com`, create an IAM role with a trust policy that scopes to your specific GitHub repo (via the `sub` claim: `repo:owner/url-shortener:*`), and swap the workflow's `aws-actions/configure-aws-credentials` step to use `role-to-assume` instead of an access key pair.

---

## 6. Secrets storage: Kubernetes Secrets vs AWS Secrets Manager

**Decision.** Secrets live in **native Kubernetes Secret resources**, deployed as YAML manifests. The manifest with real values (`k8s/secret.yaml`) is gitignored; a template with placeholders (`k8s/secret.example.yaml`) is committed. The app consumes them via `envFrom` on the pod spec, exactly like environment variables from a ConfigMap.

**Trade-off.** Kubernetes Secrets are base64-*encoded*, not encrypted. Anyone with `kubectl get secret -o yaml` permission on the namespace can read them in cleartext with `base64 -d`. They live in etcd, and etcd encryption-at-rest is opt-in and off by default in minikube (and even in EKS unless you specifically configure a KMS provider). By contrast, AWS Secrets Manager encrypts secrets at rest with KMS, offers automatic rotation for supported secret types, produces CloudTrail audit logs on every access, and gives you IAM-based access control at the individual secret level. For a portfolio project, native K8s Secrets are acceptable and standard — they're what most tutorials teach. For a real production system, they're a liability.

**How to upgrade.** Install the **External Secrets Operator** in the cluster. It watches `ExternalSecret` custom resources in your namespace, pulls the real values from AWS Secrets Manager (or Vault, or GCP Secret Manager, etc.) using cluster-scoped credentials, and materialises them as native K8s Secrets on the fly. The application manifests don't change — only the source of truth moves.

---

## 7. Terraform state: local vs S3 backend

**Decision.** Terraform state is a **local file** — `terraform.tfstate` on the developer's machine, gitignored. No remote backend, no state locking, no shared workspace. This is the fastest possible path to a working Terraform workflow (plan → apply → destroy) with zero infrastructure prerequisites.

**Trade-off.** Local state has three real problems that don't matter for one person on one machine but blow up immediately at "team of two". First, no locking: if you run `terraform apply` from two shells or two machines at once, both will race to update state and one will lose — potentially corrupting the file. Second, no shared source of truth: a collaborator has no way to pick up where you left off, because they don't have your state file. Third, no history: if you delete the state file by accident, Terraform believes nothing exists in AWS, and re-applying will either fail with duplicate-resource errors or (worse) succeed by creating parallel resources. For a solo learning project all three problems are theoretical. For any team, they're existential.

**How to upgrade.** Move to an **S3 backend with DynamoDB locking**. Roughly ten lines of `backend "s3"` config in Terraform, pointing at an S3 bucket for the state file and a DynamoDB table for the lock. The bucket should have versioning enabled (undo button for state corruption) and server-side encryption on. Terraform Cloud is a hosted alternative with a free tier that handles state, locking, and history without you owning any of it.

---

## Summary table

| # | Decision | We picked | Production path |
|---|---|---|---|
| 1 | Short-code generation | nanoid, 7 chars, custom alphabet | Snowflake ID + base62 at scale |
| 2 | Cache pattern | Cache-aside on the read path | Selective write-through for hot keys |
| 3 | Local K8s | minikube | EKS via `eksctl` when needed |
| 4 | Postgres on K8s | Deployment + PVC | AWS RDS or Aurora |
| 5 | CI auth to AWS | Static IAM keys (least-privilege) | OIDC federation |
| 6 | Secrets storage | Native K8s Secrets | External Secrets Operator + AWS Secrets Manager |
| 7 | Terraform state | Local file | S3 + DynamoDB, or Terraform Cloud |

Each row above represents a *deliberate* choice with an explicit reason and an explicit escape hatch. That's the standard this project holds itself to.
