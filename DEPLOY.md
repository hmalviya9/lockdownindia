# Deploy notes — Vercel + GitHub Actions

## The architecture

- **Vercel** serves the dashboard as static files (`index.html`, `state.js`, `history.js`, etc.)
- **GitHub Actions** runs the worker every 6 hours on Ubuntu, commits the updated state files back to the repo
- **Vercel auto-deploys** on every push to `main`, picking up the fresh state files automatically

The local launchd job on your Mac is now optional — the cloud cron does the same job laptop-independent.

## One-time setup (≈ 5 minutes)

You're already deployed at `lockdownindia.vercel.app`. To enable auto-updating:

### 1. Push this folder to GitHub

```bash
cd ~/india-energy-thesis
git init
git add -A
git commit -m "initial: lockdown indicator dashboard"
git branch -M main
gh repo create lockdownindia --public --source=. --remote=origin --push
```

(Or use the GitHub web UI to create the repo, then `git remote add origin ...; git push -u origin main`.)

### 2. Connect the repo to your existing Vercel project

In the Vercel dashboard:
- Open project `lockdownindia`
- Settings → Git → Connect a Git Repository → pick the GitHub repo you just pushed
- This makes Vercel auto-deploy on every push to `main`

### 3. Verify the GitHub Action runs

- Go to your GitHub repo → Actions tab
- Click "Update Lockdown Indicator" → "Run workflow" → Run
- Wait ~3 minutes
- Confirm a new commit appears authored by `lockdown-indicator-bot`
- Confirm Vercel rebuilds and `lockdownindia.vercel.app` shows the new timestamp

After this, the action fires automatically every 6 hours (cron `15 */6 * * *` UTC).

## What's already in this repo for cloud deploy

- `.github/workflows/update-indicator.yml` — the cron job that runs every 6 hrs
- `vercel.json` — caching headers (60s on state.js so dashboard refresh sees fresh data fast)
- `.gitignore` — keeps local-only `.DS_Store` and launchd logs out of the repo
- `scripts/update-indicator.sh` — already Linux-compatible (date parsing has BSD + GNU fallbacks)

## How to manually trigger an update

- **Locally** (writes to your Mac, doesn't deploy): `./scripts/update-indicator.sh --force`
- **In the cloud** (writes to repo, auto-deploys): GitHub repo → Actions → "Update Lockdown Indicator" → Run workflow

## Troubleshooting

- **GitHub Action runs but no commit appears** → workflow has nothing to commit (state didn't change). This is normal if news/prices were stable.
- **Action fails with "permission denied"** → check repo Settings → Actions → General → Workflow permissions = "Read and write permissions"
- **Vercel doesn't redeploy after push** → confirm the GitHub repo is connected in Vercel → Settings → Git
- **state.js shows old timestamp on the live site** → check Cache-Control headers; `vercel.json` sets 60s on state files. Hard refresh (⌘⇧R) clears it.
