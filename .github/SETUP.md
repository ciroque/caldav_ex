# GitHub Actions Setup Guide

This guide walks you through setting up GitHub Actions for CalDAVEx.

## Prerequisites

- Repository pushed to GitHub
- Hex.pm account with API key

## Step 1: Configure Hex.pm API Key

### 1.1 Generate Hex.pm API Key

1. **Log in to Hex.pm:**
   - Go to https://hex.pm
   - Sign in with your account (create one if needed)

2. **Navigate to API Keys:**
   - Go to https://hex.pm/settings/keys
   - Or: Click your profile → Settings → API keys

3. **Generate New Key:**
   - Click **"Generate new key"**
   - **Name:** `github-actions-caldav_ex` (or any descriptive name)
   - **Permissions:** Check **"API"** (required for publishing packages)
   - Click **"Generate"**

4. **Copy the Key:**
   - **⚠️ CRITICAL:** Copy the API key immediately
   - You will **never see this key again** after leaving the page
   - Store it temporarily in a secure location (password manager recommended)

### 1.2 Add Secret to GitHub Repository

1. **Navigate to Repository Settings:**
   - Go to https://github.com/ciroque/caldav_ex
   - Click **Settings** tab (repository settings, not your profile)

2. **Access Secrets:**
   - In the left sidebar, expand **Secrets and variables**
   - Click **Actions**

3. **Create New Secret:**
   - Click **"New repository secret"** button
   - **Name:** `HEX_API_KEY` (must be exactly this, case-sensitive)
   - **Value:** Paste the Hex.pm API key from step 1.1
   - Click **"Add secret"**

4. **Verify Secret Added:**
   - You should see `HEX_API_KEY` in the list
   - The value will be hidden (shows as `***`)
   - Note the "Updated" timestamp

### 1.3 Security Notes

- ✅ Secret is encrypted and never exposed in workflow logs
- ✅ Only accessible to workflows in this repository
- ✅ Can be updated or rotated anytime
- ✅ Revoke old keys on Hex.pm after updating
- ⚠️ Never commit API keys to your repository
- ⚠️ Never share API keys in issues or pull requests

## Step 2: Create Hex.pm Environment

1. **Create Environment:**
   - Go to Settings → Environments
   - Click "New environment"
   - Name: `hex-pm`
   - Click "Configure environment"

2. **Add Protection Rules (Recommended):**
   - ✅ Required reviewers: Add yourself or team members
   - ✅ Wait timer: 0 minutes (or add a delay if desired)
   - Click "Save protection rules"

## Step 3: Verify CI Workflow

1. **Push Code:**
   ```bash
   git add .
   git commit -m "Add GitHub Actions workflows"
   git push origin main
   ```

2. **Check Actions:**
   - Go to Actions tab in GitHub
   - You should see "CI" workflow running
   - Wait for it to complete (should be green ✅)

3. **Review Results:**
   - Click on the workflow run
   - Check all jobs passed:
     - Test (multiple Elixir/OTP versions)
     - Code Quality
     - Dialyzer

## Step 4: Test Publishing Workflow (Optional)

**⚠️ Warning:** This will actually publish to Hex.pm. Only do this when ready!

1. **Prepare for Release:**
   ```bash
   # Update version in mix.exs
   # Update CHANGELOG.md
   git add mix.exs CHANGELOG.md
   git commit -m "Bump version to 0.1.0"
   git push origin main
   ```

2. **Wait for CI:**
   - Ensure CI passes on main branch
   - Check Actions tab - all checks should be green

3. **Create and Push Tag:**
   ```bash
   # Create version tag (must match version in mix.exs)
   git tag v0.1.0
   
   # Push tag to trigger publish workflow
   git push origin v0.1.0
   ```

4. **Monitor Publish Workflow:**
   - Go to Actions tab
   - Watch "Publish to Hex.pm" workflow run
   - If environment protection is enabled, approve deployment:
     - Click "Review deployments"
     - Check `hex-pm`
     - Click "Approve and deploy"

5. **Verify Success:**
   - Check workflow completes successfully
   - Visit https://hex.pm/packages/caldav_ex
   - Visit https://hexdocs.pm/caldav_ex (docs published automatically)
   - Check GitHub Releases for new release with links

## Troubleshooting

### "HEX_API_KEY not found"
- Verify secret name is exactly `HEX_API_KEY` (case-sensitive)
- Check secret is in **repository secrets**, not environment secrets
- Ensure you're looking at the correct repository
- Try regenerating the Hex API key and updating the secret

### "Authentication failed" or "Invalid API key"
- API key may have been revoked on Hex.pm
- Key may have expired (check Hex.pm settings)
- Generate a new key on Hex.pm
- Update the GitHub secret with the new key
- Ensure "API" permission is checked when generating key

### "Version mismatch"
- Ensure version in `mix.exs` matches tag (without 'v' prefix)
- Tag must be `v0.1.0` format, mix.exs must be `0.1.0`
- Check for typos in version numbers

### "CI checks not passing"
- Publish workflow requires CI to pass first
- Check CI workflow status
- Fix any failing tests/checks before publishing

### "Package already published"
- You cannot republish the same version
- Bump version number in `mix.exs`
- Update `CHANGELOG.md`
- Try again with new version

## Maintenance

### Updating Elixir/OTP Versions

Edit `.github/workflows/ci.yml`:

```yaml
matrix:
  elixir: ['1.17', '1.18', '1.19']  # Add new versions here
  otp: ['27', '28']                  # Add new versions here
```

### Updating Dependencies

Dependencies are cached. To force refresh:
1. Go to Actions → Caches
2. Delete old caches
3. Re-run workflow

## Best Practices

1. **Always test locally first:**
   ```bash
   mix test
   mix credo --strict
   mix dialyzer
   ```

2. **Use semantic versioning:**
   - MAJOR: Breaking changes
   - MINOR: New features, backwards compatible
   - PATCH: Bug fixes, backwards compatible

3. **Update CHANGELOG.md:**
   - Document all changes
   - Follow Keep a Changelog format

4. **Review before publishing:**
   - Check diff on GitHub
   - Ensure CI is green
   - Verify version number

5. **Tag releases:**
   - Always use semantic versioning tags: `v0.1.0`
   - Tag triggers the publish workflow automatically
   - Never delete or force-push tags after publishing

## Managing API Keys

### Rotating Keys

It's good practice to rotate API keys periodically:

1. **Generate new key** on Hex.pm (Step 1.1)
2. **Update GitHub secret** with new key (Step 1.2)
3. **Revoke old key** on Hex.pm:
   - Go to https://hex.pm/settings/keys
   - Find the old key
   - Click "Revoke"

### Revoking Access

If you need to immediately revoke publishing access:

1. **Revoke on Hex.pm:**
   - Go to https://hex.pm/settings/keys
   - Click "Revoke" next to `github-actions-caldav_ex`

2. **Delete from GitHub (optional):**
   - Settings → Secrets and variables → Actions
   - Click on `HEX_API_KEY`
   - Click "Remove secret"

### Multiple Repositories

If you manage multiple packages:
- Use **different API keys** for each repository
- Name them descriptively (e.g., `github-actions-package-name`)
- This allows fine-grained access control and easier revocation

## Support

- GitHub Actions docs: https://docs.github.com/en/actions
- Hex.pm publishing: https://hex.pm/docs/publish
- Hex.pm API keys: https://hex.pm/docs/api_keys
- Issues: https://github.com/ciroque/caldav_ex/issues
