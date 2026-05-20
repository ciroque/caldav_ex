# Publishing CalDAVEx to Hex.pm

This document outlines the complete process for publishing CalDAVEx to Hex.pm.

## Prerequisites

1. **Hex Account**: You need a Hex.pm account
2. **Git Repository**: Code should be committed and pushed to GitHub
3. **Tests Passing**: All tests must pass
4. **Documentation**: README, CHANGELOG, and module docs complete

## Pre-Publishing Checklist

Before publishing, verify:

```bash
# 1. Ensure all dependencies are up to date
mix deps.get

# 2. Run tests
mix test

# 3. Compile without warnings
mix compile --warnings-as-errors

# 4. Generate and review documentation
mix docs
open doc/index.html  # or xdg-open on Linux

# 5. Verify package metadata
mix hex.build
```

## Publishing Steps

### Step 1: Register or Authenticate with Hex

If this is your first time publishing:

```bash
# Register a new Hex account
mix hex.user register
```

If you already have an account:

```bash
# Authenticate
mix hex.user auth
```

### Step 2: Update Version (if needed)

Edit `mix.exs` and update the version:

```elixir
@version "0.1.0"  # Update this for new releases
```

Update `CHANGELOG.md` with release notes for the new version.

### Step 3: Commit Version Changes

```bash
git add mix.exs CHANGELOG.md
git commit -m "Bump version to 0.1.0"
git push origin main
```

### Step 4: Build and Verify Package

```bash
# Build the package (creates a .tar file)
mix hex.build

# This will show you what will be published
# Review the output carefully
```

### Step 5: Publish to Hex.pm

```bash
# Publish the package
mix hex.publish

# You'll be prompted to confirm:
# - Package name
# - Version
# - Dependencies
# - Files included
# 
# Type 'Y' to confirm and publish
```

### Step 6: Create Git Tag

After successful publication:

```bash
# Create an annotated tag
git tag -a v0.1.0 -m "Release version 0.1.0"

# Push the tag to GitHub
git push origin v0.1.0
```

### Step 7: Create GitHub Release (Optional)

1. Go to `https://github.com/ciroque/caldav_ex/releases`
2. Click "Draft a new release"
3. Select the tag `v0.1.0`
4. Title: `v0.1.0`
5. Copy release notes from `CHANGELOG.md`
6. Click "Publish release"

## Post-Publishing Verification

After publishing:

```bash
# 1. Verify package is live
open https://hex.pm/packages/caldav_ex

# 2. Verify documentation is published
open https://hexdocs.pm/caldav_ex

# 3. Test installation in a new project
mix new test_caldav
cd test_caldav
# Add {:caldav_ex, "~> 0.1.0"} to mix.exs deps
mix deps.get
```

## Publishing Updates

For subsequent releases:

1. Make your changes
2. Update tests
3. Update `CHANGELOG.md` with new changes
4. Bump version in `mix.exs`
5. Commit changes
6. Follow Steps 4-7 above

## Version Numbering

CalDAVEx follows [Semantic Versioning](https://semver.org/):

- **MAJOR** (1.0.0): Breaking changes
- **MINOR** (0.1.0): New features, backwards compatible
- **PATCH** (0.1.1): Bug fixes, backwards compatible

## Troubleshooting

### "Package name already taken"

If the package name is taken, you'll need to choose a different name. Update:
- `mix.exs` - `:app` and package `name`
- `README.md` - All references to the package name

### "Version already published"

You cannot republish the same version. Bump the version number and try again.

### "Documentation failed to build"

Check that:
- All `@moduledoc` and `@doc` attributes are valid
- No syntax errors in documentation
- `ex_doc` dependency is included

### "Authentication failed"

Run `mix hex.user auth` to re-authenticate.

## Unpublishing (Emergency Only)

If you need to unpublish a version within 24 hours:

```bash
# Revert a published version (only works within 24 hours)
mix hex.publish --revert 0.1.0
```

**Note**: This should only be used in emergencies (e.g., accidentally published secrets).

## Resources

- [Hex.pm Documentation](https://hex.pm/docs)
- [Publishing Packages](https://hex.pm/docs/publish)
- [Semantic Versioning](https://semver.org/)
- [CalDAVEx on GitHub](https://github.com/ciroque/caldav_ex)

## Support

For issues with publishing:
- Hex.pm: https://hex.pm/docs/faq
- Elixir Forum: https://elixirforum.com/
- GitHub Issues: https://github.com/ciroque/caldav_ex/issues
