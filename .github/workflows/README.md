# GitHub Actions Setup

## Update Homebrew Formula Workflow

This workflow automatically updates the formula in the `homebrew-tap` repository when a new release is published.

### Setup Instructions

1. **Create a Personal Access Token (PAT)** - Fine-grained (Recommended):
   - Go to GitHub Settings → Developer settings → Personal access tokens → Fine-grained tokens
   - Click "Generate new token"
   - Give it a descriptive name like "Homebrew Tap Update"
   - Set expiration (or "No expiration" if you prefer)
   - **Repository access**: Select "Only select repositories" → choose `homebrew-tap`
   - **Repository permissions**:
     - Contents: Read and write (required to push commits)
   - Generate and copy the token

   **Alternative - Classic token** (if you prefer):
   - Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Click "Generate new token (classic)"
   - Give it a descriptive name like "Homebrew Tap Update"
   - Select scopes: `repo` (Full control of private repositories)
   - Generate and copy the token

2. **Add the token as a repository secret**:
   - Go to this repository's Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `HOMEBREW_TAP_TOKEN`
   - Value: Paste the PAT from step 1
   - Click "Add secret"

3. **How it works**:
   - When you create a new release (e.g., `v1.0.0`), the workflow triggers
   - It downloads the release tarball and calculates its SHA256
   - Updates `Formula/git-wt.rb` with the correct version, URL, and SHA256
   - Commits and pushes the updated formula to the homebrew-tap repository

### Creating a Release

To trigger this workflow, create a release:

```bash
# Tag the release
git tag -a v1.0.0 -m "Version 1.0.0 - Initial release"
git push origin v1.0.0
```

Then go to GitHub and create a release from that tag, or use the GitHub CLI:

```bash
gh release create v1.0.0 --title "v1.0.0" --notes "Release notes here"
```

The workflow will automatically update your homebrew-tap repository within a few minutes.

### Alternative: Manual Trigger

If you prefer to trigger updates on every push to main (not recommended for Homebrew), uncomment the push trigger section in `update-homebrew-formula.yml`.
