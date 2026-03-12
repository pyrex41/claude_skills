---
description: Set up a preview environment for FacilityGrid MRs by pinning image tags and adding the preview label
---

# Add Preview Environment

You are tasked with setting up a preview environment for one or more FacilityGrid MRs. Preview environments are deployed via ArgoCD and require pinned image tags in the fg-manifold repo.

## How Preview Environments Work

- Preview environments are triggered by adding the `preview` label to an **fg-manifold** MR
- When the label is on a manifold MR, ArgoCD reads ALL values **from the MR branch itself** (not main)
- This means you must pin the exact image tags for any repos with changes
- For single-repo MRs (e.g. just a backend MR), the ApplicationSet automatically overrides that repo's image tag — but for cross-repo changes or manifold MRs, you pin manually

## Labels

- **`preview`** — Deploys the main FargateApp (backend, frontend, auth, cloud, chart-service, nginx). Workers use the **same backend image tag** from `values.yaml`.
- **`preview-workers`** — Additionally deploys dedicated FargateWorker pods (12 workers + scheduler). Only needed if testing worker/queue behavior specifically. Uses `workers-values.yaml` for the backend image tag.

## Image Tag Format

Pipeline builds produce images tagged as `dev-{first 8 chars of commit SHA}`:
```
dev-5fe2351c   # from commit 5fe2351cc9cb...
```

You can determine the tag as soon as you have the commit SHA — the image just needs to finish building before ArgoCD can pull it.

## Process

### 1. Identify the image tags needed

For each repo with changes, get the HEAD commit SHA:
```bash
cd /Users/reuben/fg/fg-frontend && echo "Frontend: dev-$(git rev-parse HEAD | cut -c1-8)"
cd /Users/reuben/fg/fg-backend && echo "Backend:  dev-$(git rev-parse HEAD | cut -c1-8)"
```

### 2. Verify pipelines are running/complete

Images must be built and pushed to ECR before ArgoCD can deploy:
```bash
glab ci list -R facility-grid/fg-backend | head -5
glab ci list -R facility-grid/fg-frontend | head -5
```

Look for `(success)` or `(running)` on the MR ref. The `build` and `publish-mr` jobs are the ones that push the image.

### 3. Pin image tags in fg-manifold

Edit the values file on the manifold MR branch:

**File: `fg-manifold/deploy/facilitygrid/preview/pr/values.yaml`**

```yaml
images:
  backend:
    repository: 620666897359.dkr.ecr.us-east-2.amazonaws.com/fg-backend
    tag: dev-XXXXXXXX    # pin to specific build
  frontend:
    repository: 620666897359.dkr.ecr.us-east-2.amazonaws.com/fg-frontend
    tag: dev-XXXXXXXX    # pin to specific build
  # leave others as 'latest' unless you have changes in those repos
```

If using `preview-workers` label, also update:

**File: `fg-manifold/deploy/facilitygrid/preview/pr/workers-values.yaml`**

```yaml
image:
  repository: 620666897359.dkr.ecr.us-east-2.amazonaws.com/fg-backend
  tag: dev-XXXXXXXX    # same backend tag
```

Only repos with actual changes need pinned tags. Leave others as `latest`.

### 4. Commit and push

```bash
cd /Users/reuben/fg/fg-manifold
git add deploy/facilitygrid/preview/pr/values.yaml
# Only if using preview-workers:
# git add deploy/facilitygrid/preview/pr/workers-values.yaml
git commit -m "chore: pin image tags for preview environment"
git push
```

### 5. Add the preview label

```bash
glab mr update <MR_NUMBER> -R facility-grid/fg-manifold --label preview
# Add --label preview-workers too if worker testing is needed
```

### 6. Verify deployment

ArgoCD will detect the label and create the environment. Check the MR comments or ArgoCD UI for the preview URL.

## Important Notes

- **Pipelines must complete** before ArgoCD can pull the images. You can commit the tag pins as soon as you have the SHAs, but deployment will fail until the images exist in ECR.
- **Remember to revert tags** when closing the MR, or they'll be merged to main. Alternatively, revert in a follow-up commit before merge.
- The `preview` label alone does NOT spin up dedicated workers — it uses the backend image from `values.yaml` for the main app container which includes Horizon. Use `preview-workers` only when you need isolated worker pods.
