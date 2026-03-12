---
name: fg:write-e2e
description: Write Playwright e2e tests in fg-manifold and optionally validate on a preview environment using the rodney CLI
---

# Write E2E Tests

You are tasked with writing Playwright e2e tests for a FacilityGrid feature. Tests live in `fg-manifold/lib/compose/e2e/`.

## Structure

```
fg-manifold/lib/compose/e2e/
├── playwright.config.ts          # Config (baseURL, projects, timeouts)
├── page-objects/                 # Page Object Model classes
├── tests/
│   ├── auth/auth.setup.ts        # Pre-test auth (saves .auth/user.json)
│   ├── helpers/auth-state.ts     # ensureAuthenticated() and token utils
│   └── <feature>/               # Tests organized by feature area
└── fixtures/                     # Generated test data (gitignored)
```

## Test Template

Every authenticated test MUST use `ensureAuthenticated()` after navigation. This is non-negotiable — see `auth.md` for why.

```typescript
import { test, expect } from '@playwright/test';
import { ensureAuthenticated } from '../helpers/auth-state';

test.describe('Feature Name', () => {
  test.describe.configure({ mode: 'serial' });

  test('does the thing', async ({ page }) => {
    await page.goto('/main/some-page', { timeout: 15000 });
    await ensureAuthenticated(page, '/main/some-page');
    // ...assertions — auth is guaranteed valid
  });
});
```

## Before Writing Tests

1. **Read `auth.md`** — Auth token handling is the #1 source of flaky tests. Understand the 300s TTL issue before writing anything.
2. **Read `selectors-and-data.md`** — ag-grid selectors, SPA navigation, feature gates, and test data patterns.
3. If validating on a preview environment, **read `rodney.md`** for the rodney CLI.

## Page Objects

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
    // Use 'domcontentloaded' — 'networkidle' hangs on SPA polling/websockets
    await this.page.waitForLoadState('domcontentloaded', { timeout: 15000 });
  }
}
```

## Running Tests

```bash
cd fg-manifold/lib/compose/e2e
npx playwright test                              # Run all
npx playwright test tests/feature/my-test.spec.ts # Run specific file
npx playwright test -g "test name"                # Run by name
npx playwright test --headed                      # Visible browser
tilt ci -- e2e                                    # Via Tilt
```

## Checklist

Before committing e2e tests, verify:
- [ ] Tests pass locally: `npx playwright test tests/<feature>/`
- [ ] Every `page.goto()` to a protected route is followed by `ensureAuthenticated()`
- [ ] `test.describe.configure({ mode: 'serial' })` is set
- [ ] Tests clean up all created data in `afterEach`
- [ ] Entity IDs are configurable via env vars (skip if not set)
- [ ] No hardcoded credentials (use env vars or `LoginPage.loginAsTestUser()`)
- [ ] Page objects are reusable and in `page-objects/`
- [ ] Undeployed features are gated behind `test.skip(!process.env.FEATURE_FLAG, 'reason')`
