# GitHub Actions Workflows

This directory contains GitHub Actions workflows for CalDAVEx.

## Acknowledgments

This project was inspired by the [caldav_cleam](https://github.com/RedHelium/caldav_gleam) project, and modeled after the [python-caldav](https://github.com/python-caldav/caldav) library.

## Workflows

### CI (`ci.yml`)

**Trigger:** Automatic on push to `main` and all pull requests

**Jobs:**
1. **Test** - Runs tests across multiple Elixir/OTP versions
   - Matrix: Elixir 1.17-1.19 × OTP 27-28
   - Generates coverage report on latest version
   - Compiles with `--warnings-as-errors`

2. **Code Quality** - Runs code quality checks
   - `mix format --check-formatted`
   - `mix credo --strict`
   - `mix docs` - Builds documentation
   - Uploads docs as artifact

3. **Dialyzer** - Runs static analysis
   - Caches PLT files for faster runs
   - Reports issues in GitHub format

### Publish (`publish.yml`)

**Trigger:** Automatic on version tags (e.g., `v0.1.0`)

**Requirements:**
- All CI checks must pass
- Tag version must match `@version` in `mix.exs`
- `HEX_API_KEY` secret must be configured

**Process:**
1. Verifies CI status
2. Extracts version from tag
3. Validates version matches `mix.exs`
4. Runs tests one final time
5. Builds documentation
6. Publishes to Hex.pm (automatically publishes docs to HexDocs)
7. Creates GitHub release with Hex.pm and HexDocs links

**Usage:**
1. Update version in `mix.exs`
2. Update `CHANGELOG.md`
3. Commit and push changes
4. Wait for CI to pass
5. Create and push version tag:
   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```
6. Approve deployment in GitHub environment (if configured)

## Setup

### Required Secrets

1. **HEX_API_KEY** - Your Hex.pm API key
   - Generate at: https://hex.pm/settings/keys
   - Add to: Settings → Secrets and variables → Actions → New repository secret

### Required Environment

Create a GitHub environment named `hex-pm`:
1. Go to Settings → Environments → New environment
2. Name: `hex-pm`
3. Add protection rules (optional but recommended):
   - Required reviewers
   - Wait timer

## Local Testing

Test the workflows locally before pushing:

```bash
# Run tests
mix test --cover

# Check formatting
mix format --check-formatted

# Run Credo
mix credo --strict

# Build docs
mix docs

# Run Dialyzer
mix dialyzer
```

## Troubleshooting

### CI Failing

- Check test output in the Actions tab
- Ensure all dependencies are up to date
- Verify code passes locally first

### Publish Failing

- Ensure version in `mix.exs` matches tag (without 'v' prefix)
- Verify `HEX_API_KEY` is set correctly
- Check that CI passed before pushing tag
- Ensure version hasn't been published already
- Tag format must be `v*.*.*` (e.g., `v0.1.0`)

### Cache Issues

If builds are slow or failing due to cache:
1. Go to Actions → Caches
2. Delete relevant caches
3. Re-run workflow
