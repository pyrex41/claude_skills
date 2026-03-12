# Validating on Preview with Rodney

When a preview environment is available (e.g. `fg-pr-1039-frontend.rudd-hake.ts.net`), use the `rodney` CLI for manual browser-based validation. Rodney drives a persistent Chrome instance.

## Basics

```bash
rodney status                      # Check if browser is running
rodney start --show                # Launch visible Chrome
rodney open <url>                  # Navigate
rodney screenshot /tmp/shot.png    # Capture (read with Read tool to view)
rodney waitload                    # Wait for page load
rodney waitidle                    # Wait for network idle
rodney sleep <seconds>             # Wait N seconds
```

## Login on Preview

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

## Interacting with Elements

```bash
rodney click ".my-button"
rodney input "input.my-field" "some text"
rodney file "input[type=file]" /path/to/file
rodney wait ".my-element"
rodney exists ".my-element"        # Exit 1 if not found
rodney text ".my-selector"
rodney js "document.querySelector('.x')?.value"
```

## Screenshots for MR Evidence

```bash
rodney screenshot /tmp/evidence.png
# Upload to GitLab:
TOKEN=$(grep -A2 'lab.facilitygrid.net' ~/Library/Application\ Support/glab-cli/config.yml | grep token | awk '{print $2}')
curl --request POST --header "PRIVATE-TOKEN: $TOKEN" \
  --form "file=@/tmp/evidence.png" \
  "https://lab.facilitygrid.net/api/v4/projects/facility-grid%2Ffg-frontend/uploads"
```

## Caveats

- `rodney js` chokes on semicolons in inline expressions — wrap in IIFEs or load from file
- The browser session persists across commands (useful for multi-step flows)
- Preview URLs: `fg-pr-<MR_NUMBER>-<service>.rudd-hake.ts.net`
