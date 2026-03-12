---
description: Write Playwright e2e tests in fg-manifold and optionally validate on a preview environment using the rodney CLI
---

# Write E2E Tests

You are tasked with writing Playwright e2e tests for a FacilityGrid feature. Tests live in `fg-manifold/lib/compose/e2e/`.

## E2E Test Location & Structure

```
fg-manifold/lib/compose/e2e/
├── playwright.config.ts          # Config (baseURL, projects, timeouts)
├── page-objects/                 # Page Object Model classes
│   ├── login.page.ts
│   ├── dashboard.page.ts
│   ├── project.page.ts
│   ├── project-list.page.ts
│   └── observation.page.ts
├── tests/
│   ├── auth/auth.setup.ts        # Pre-test auth (runs first, saves .auth/user.json)
│   └── <feature>/               # Tests organized by feature area
│       └── <name>.spec.ts
├── tests/helpers/auth-state.ts   # Auth token utilities
└── fixtures/                     # Generated test data (gitignored)
```

## Writing Tests

### 1. Create a page object if needed

Page objects go in `e2e/page-objects/`. Follow existing patterns:

```typescript
import { Page, Locator, expect } from '@playwright/test';

export class MyPage {
  readonly page: Page;
  readonly someElement: Locator;

  constructor(page: Page) {
    this.page = page;
    this.someElement = page.locator('.my-selector');
  }

  async goto() {
    await this.page.goto('/main/path/to/page');
    await this.page.waitForLoadState('networkidle', { timeout: 30000 });
  }
}
```

### 2. Create the spec file

Tests go in `e2e/tests/<feature>/<name>.spec.ts`:

```typescript
import { test, expect } from '@playwright/test';
import { MyPage } from '../../page-objects/my.page';

test.describe('Feature Name', () => {
  let myPage: MyPage;

  test.beforeEach(async ({ page }) => {
    myPage = new MyPage(page);
  });

  test('does the thing', async ({ page }) => {
    await myPage.goto();
    // ...assertions
  });
});
```

### 3. Auth & credentials

**Two environments with different credentials:**

| Environment | Email | Password | When |
|------------|-------|----------|------|
| Tilt (local) | `test@test.com` | `test123` | `npx playwright test` locally |
| Preview (Tailscale) | `support@facilitygrid.com` | `123` | Testing against `fg-pr-*` URLs |

- The Playwright `auth.setup.ts` runs before all tests, logs in, and saves state to `.auth/user.json`
- Tests in the `chromium` project load this state automatically — no login needed per test
- Credentials come from `LoginPage.loginAsTestUser()` which reads `TEST_USER_EMAIL` / `TEST_USER_PASSWORD` env vars, falling back to `test@test.com` / `test123`
- **Preview testing via rodney uses different credentials** — see below

**Auth token storage (FacilityGrid-specific):**
- `localStorage`: `ate_sct` (auth token), `ate_rft` (refresh token), `ate_exp` (expiry)
- Cookie: `act`
- If making API calls in tests (e.g. for cleanup), use `localStorage.getItem('ate_sct')` as `X-AUTH-TOKEN` header
- The backend API base path is `/api/cloud/` (not `/api/v2/`)

### 4. Test data & IDs

Tests that navigate to specific entities need valid IDs from the staging data dump:

```bash
# Query the local DB for valid IDs
docker exec -i fg-mysql mariadb -u root -plocaldev123 'fg-demo' -e "YOUR QUERY"
```

Make IDs configurable via env vars with sensible defaults:
```typescript
const PROJECT_ID = Number(process.env.TEST_PROJECT_ID) || 7401;
const OBSERVATION_ID = Number(process.env.TEST_OBSERVATION_ID) || 549;
```

### 5. Cleanup / teardown

Tests MUST clean up any data they create. Common patterns:

**Track API responses for cleanup:**
```typescript
// In page object
async startTrackingUploads() {
  this.uploadedFiles = [];
  await this.page.route('**/api/**/temp-storage-file', async (route) => {
    const response = await route.fetch();
    const body = await response.json();
    if (body?.name) this.uploadedFiles.push({ name: body.name, size: body.size });
    await route.fulfill({ response });
  });
}

async cleanupUploads() {
  if (this.uploadedFiles.length === 0) return;
  await this.page.evaluate(async ({ projectId, files }) => {
    await fetch(`/api/cloud/project/${projectId}/temp-storage-files`, {
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json',
        'X-AUTH-TOKEN': localStorage.getItem('ate_sct') || '',
      },
      body: JSON.stringify({ data: files }),
    });
  }, { projectId: this.projectId, files: this.uploadedFiles });
  this.uploadedFiles = [];
  await this.page.unroute('**/api/**/temp-storage-file');
}
```

**Use in afterEach:**
```typescript
test.afterEach(async () => {
  await myPage.cleanupUploads();
});
```

### 6. Running tests

```bash
cd fg-manifold/lib/compose/e2e

# Run all e2e tests (requires tilt up)
npx playwright test

# Run specific test file
npx playwright test tests/feature/my-test.spec.ts

# Run with visible browser
npx playwright test --headed

# Run single test by name
npx playwright test -g "test name"

# Run via Tilt (from fg-manifold/lib/compose)
tilt ci -- e2e
```

## Validating on Preview with Rodney

When a preview environment is available (e.g. `fg-pr-1039-frontend.rudd-hake.ts.net`), use the `rodney` CLI for manual browser-based validation. Rodney drives a persistent Chrome instance.

### Rodney basics

```bash
rodney status                      # Check if browser is running
rodney start --show                # Launch visible Chrome (if not running)
rodney open <url>                  # Navigate
rodney screenshot /tmp/shot.png    # Capture screenshot (read with Read tool to view)
rodney waitload                    # Wait for page load
rodney waitidle                    # Wait for network idle
rodney sleep <seconds>             # Wait N seconds
```

### Login on preview

Preview environments use `support@facilitygrid.com` / `123`:

```bash
rodney open "https://<preview-url>/login"
rodney waitload && rodney sleep 2
rodney input "#user_login" "support@facilitygrid.com"
rodney click "#submit_btn"
rodney sleep 2
rodney wait "#user_pass"
rodney input "#user_pass" "123"
rodney click "#submit_btn"
rodney sleep 5
rodney url   # Should show /main/dashboard
```

### Interacting with elements

```bash
rodney click ".my-button"                          # Click
rodney input "input.my-field" "some text"          # Type into input
rodney file "input[type=file]" /path/to/file       # Set file on file input
rodney wait ".my-element"                          # Wait for element
rodney exists ".my-element"                        # Check existence (exit 1 if not)
rodney text ".my-selector"                         # Get text content
rodney js "document.querySelector('.x')?.value"    # Evaluate JS
```

### Measuring performance with rodney

```bash
# Install a timing hook (rodney js doesn't support semicolons well — use IIFEs)
rodney js "(() => { window.__t = { start: null, end: null }; return 'ok' })()"

# Or write JS to a file and eval it:
cat > /tmp/hook.js << 'EOF'
(() => {
  window.__metrics = { start: null, end: null }
  // ... XHR monkey-patching etc
  return 'installed'
})()
EOF
rodney js "$(cat /tmp/hook.js)"

# Read results
rodney js "JSON.stringify(window.__metrics)"
rodney js "window.__metrics.end - window.__metrics.start + ' ms'"
```

### Taking screenshots for MR evidence

```bash
rodney screenshot /tmp/evidence.png
# Then read it with the Read tool to verify visually
# Upload to GitLab for MR description:
TOKEN=$(grep -A2 'lab.facilitygrid.net' ~/Library/Application\ Support/glab-cli/config.yml | grep token | awk '{print $2}')
curl --request POST --header "PRIVATE-TOKEN: $TOKEN" \
  --form "file=@/tmp/evidence.png" \
  "https://lab.facilitygrid.net/api/v4/projects/facility-grid%2Ffg-frontend/uploads"
# Returns markdown: ![alt](/uploads/hash/filename.png)
```

### Rodney caveats

- `rodney js` chokes on semicolons in inline expressions — wrap in IIFEs or load from file
- The browser session persists across commands (useful for multi-step flows)
- Use `rodney screenshot` + `Read` tool to visually verify page state
- Preview URLs follow pattern: `fg-pr-<MR_NUMBER>-<service>.rudd-hake.ts.net`

## Checklist

Before committing e2e tests, verify:
- [ ] Tests pass locally: `npx playwright test tests/<feature>/`
- [ ] Tests clean up all created data in `afterEach`
- [ ] Entity IDs are configurable via env vars
- [ ] No hardcoded credentials (use `LoginPage.loginAsTestUser()` or env vars)
- [ ] Page objects are reusable and in `page-objects/`
- [ ] Fixture files are generated programmatically (no committed binaries)
