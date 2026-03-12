# Auth in E2E Tests

## The 300s TTL Problem

The backend issues auth tokens with a **300-second TTL** that exactly matches Angular's `isFresh(300)` freshness threshold. This means:

1. `auth.setup.ts` logs in and saves tokens to `.auth/user.json`
2. Test contexts load these tokens via Playwright's `storageState`
3. Angular sees tokens as "stale" (`TTL <= 300s`) and silently refreshes them
4. The refresh **invalidates the original tokens** for all other test contexts
5. Subsequent tests get redirected to the login page

This is unfixable at the test level — the backend always issues 300s tokens.

## Required Pattern: `ensureAuthenticated()`

**Every test** that navigates to a protected route must call `ensureAuthenticated()`:

```typescript
import { ensureAuthenticated } from '../helpers/auth-state';

test('my test', async ({ page }) => {
  await page.goto('/main/some-page', { timeout: 15000 });
  await ensureAuthenticated(page, '/main/some-page');
  // Auth is now guaranteed valid
});
```

**How it works:**
- Races login form visibility (`#user_login`) vs app element (`#user_name`)
- If on login page: re-authenticates with test credentials, persists refreshed tokens, navigates to `targetUrl`
- If already authenticated: returns immediately (no overhead)

**Source:** `tests/helpers/auth-state.ts`

## Serial Execution

Tests MUST run serially (`workers: 1` in config, `test.describe.configure({ mode: 'serial' })` per file). Parallel execution causes:
- Concurrent token refreshes that invalidate each other
- Multiple re-authentication attempts hitting the backend's **login rate limit** ("Too many login attempts")

## Credentials

| Environment | Email | Password | When |
|------------|-------|----------|------|
| Tilt (local) | `test@test.com` | `test123` | `npx playwright test` locally |
| Preview (Tailscale) | `support@facilitygrid.com` | `123` | Testing against `fg-pr-*` URLs |

- `LoginPage.loginAsTestUser()` reads `TEST_USER_EMAIL` / `TEST_USER_PASSWORD` env vars, falling back to local defaults
- Preview environments don't have the 300s TTL issue

## Token Storage

- `localStorage`: `ate_sct` (auth token), `ate_rft` (refresh token), `ate_exp` (expiry epoch)
- Cookie: `act` (scoped to `/api/cloud` path only)
- API calls in tests: use `localStorage.getItem('ate_sct')` as `X-AUTH-TOKEN` header
- Backend API base path: `/api/cloud/` (not `/api/v2/`)

## SPA Navigation vs Full Reload

`page.goto()` triggers a full SPA reload → re-checks auth → may fail. Within a single test, prefer clicking links for multi-step flows. Use `page.goto()` only for the initial navigation, followed by `ensureAuthenticated()`.
