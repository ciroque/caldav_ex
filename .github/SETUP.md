# GitHub Actions Setup Guide

This guide walks you through setting up GitHub Actions for CalDAVEx.

## Prerequisites

- Repository pushed to GitHub
- Hex.pm account with API key

## Step 1: Configure Hex.pm API Key

1. **Generate Hex API Key:**
   - Go to https://hex.pm/settings/keys
   - Click "Generate new key"
   - Name: `github-actions-caldav_ex`
   - Permissions: Check "API" (for publishing)
   - Click "Generate"
   - **Copy the key immediately** (you won't see it again)

2. **Add Secret to GitHub:**
   - Go to your repository on GitHub
   - Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `HEX_API_KEY`
   - Value: Paste your Hex API key
   - Click "Add secret"

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
   - Check GitHub Releases for new release

## Troubleshooting

### "HEX_API_KEY not found"
- Verify secret name is exactly `HEX_API_KEY`
- Check secret is in repository secrets, not environment secrets
- Try regenerating the Hex API key

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

## Support

- GitHub Actions docs: https://docs.github.com/en/actions
- Hex.pm publishing: https://hex.pm/docs/publish
- Issues: https://github.com/ciroque/caldav_ex/issues
