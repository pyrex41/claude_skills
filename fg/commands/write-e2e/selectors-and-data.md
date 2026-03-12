# Selectors, Navigation & Test Data

## ag-Grid Selectors

The project uses ag-Grid Enterprise extensively:

| Purpose | Selector | Notes |
|---------|----------|-------|
| Grid component | `ag-grid-angular` | Top-level component |
| All rows | `.ag-body-viewport .ag-row` | Attached but may not be visible (virtualization) |
| Visible rows | `.ag-center-cols-container .ag-row` | Center viewport, excludes pinned |
| Clickable cells | `.ag-center-cols-container .ag-row .ag-cell` | Reliably visible |

- Use `toBeAttached()` not `toBeVisible()` for virtualized rows
- Row count via `.ag-body-viewport .ag-row` includes off-screen rows

## Angular SPA Routes

Base URL: `http://frontend.local.gd`

| Route | Description |
|-------|-------------|
| `/main/projects` | Project list (ag-grid) |
| `/main/project/:id/overview` | Project status overview |
| `/main/project/:id/dashboard` | Activity Summary (requires Dashboard View feature) |
| `/main/dashboard` | Global watched projects dashboard |

The main layout (`/main/*`) contains the `#user_name` element used by `ensureAuthenticated()` for auth detection.

## Feature Gates

Some pages require features enabled per project (e.g., `DASHBOARD_VIEW` for Activity Summary). If not enabled, the sidebar link won't appear and direct navigation may redirect.

- Gate tests behind env vars and `test.skip()`:
  ```typescript
  const projectId = process.env.PROJECT_ID;
  if (!projectId) {
    console.log('PROJECT_ID not set — skipping');
    test.skip();
    return;
  }
  ```
- Gate undeployed backend/frontend features:
  ```typescript
  test.skip(!process.env.BACKEND_CACHE_MR_DEPLOYED, 'requires backend MR with cache headers');
  ```

## Test Data

Tests needing specific entities require valid IDs from the staging data dump:

```bash
# Query local DB
docker exec -i fg-mysql mariadb -u root -plocaldev123 'fg-demo' -e "YOUR QUERY"

# Example: find projects with Dashboard View
docker exec -i fg-mysql mariadb -u root -plocaldev123 'fg-demo' \
  -e "SELECT project_id FROM project_features WHERE feature_name = 'DASHBOARD_VIEW' LIMIT 5"
```

Make IDs configurable via env vars. **Always skip if the ID isn't set** — never hardcode defaults.

## Cleanup / Teardown

Tests MUST clean up created data. Common pattern — track API responses for cleanup:

```typescript
test.afterEach(async () => {
  await page.evaluate(async ({ projectId, files }) => {
    await fetch(`/api/cloud/project/${projectId}/temp-storage-files`, {
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json',
        'X-AUTH-TOKEN': localStorage.getItem('ate_sct') || '',
      },
      body: JSON.stringify({ data: files }),
    });
  }, { projectId, files: uploadedFiles });
});
```

## Wait Strategies

- **Always** use `domcontentloaded` not `networkidle` — Angular's SPA has ongoing XHR/polling that prevents `networkidle` from resolving
- For element waits, prefer Playwright's built-in auto-waiting (`expect(locator).toBeVisible()`) over manual `waitForTimeout()`
