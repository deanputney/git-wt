# git-wt Hook System

## Overview

Starting in this experimental branch, `git-wt` supports custom hooks that run before and after worktree operations. This allows repository-specific customization without modifying the core `git-wt` script.

## Hook Convention

Hooks are executable scripts placed in `.git/hooks/` with specific names:

- **`pre-worktree-add`** - Runs before `git worktree add`
- **`post-worktree-add`** - Runs after `git worktree add` succeeds

### Hook Behavior

**Pre-worktree-add hook:**
- Called with the same arguments that will be passed to `git worktree add`
- If the hook exits with non-zero status, the worktree creation is aborted
- Example arguments: `./git-wt add new-branch` → hook receives `new-branch`

**Post-worktree-add hook:**
- Called after `git worktree add` succeeds
- First argument is the worktree path, followed by all original arguments
- If the hook exits with non-zero status, an error is reported but the worktree has already been created
- Example arguments: hook receives `new-branch new-branch`

**No hooks installed:**
- If no hooks exist, `git-wt` behaves exactly like calling `git worktree add` directly
- This maintains backward compatibility

## git-crypt Integration

### The Problem

git-crypt and git worktree have a known incompatibility (unresolved as of git-crypt 0.8.0):
- Worktree creation attempts to decrypt files before the worktree has encryption keys
- This causes `git worktree add` to fail with: `error: external filter 'git-crypt smudge' failed`

### The Solution

Ready-to-use hook examples are provided in `examples/hooks/` that implement the git-crypt workaround.

### Installation for git-crypt Users

From your repository root:

```bash
# Copy the hook examples to your hooks directory
cp examples/hooks/git-crypt-pre-worktree-add .git/hooks/pre-worktree-add
cp examples/hooks/git-crypt-post-worktree-add .git/hooks/post-worktree-add

# Make them executable
chmod +x .git/hooks/pre-worktree-add .git/hooks/post-worktree-add
```

That's it! The hooks will now handle git-crypt automatically when you run `git-wt add`.

### How It Works

The hooks work together:

1. **Pre hook:** Detects if git-crypt is configured, saves settings, temporarily disables `filter.git-crypt.required`
2. **git-wt:** Creates the worktree normally (no special flags needed)
3. **Post hook:** Restores git-crypt settings, configures worktree filters, unlocks git-crypt, re-checks out files to decrypt them

This achieves the same result as the old inline implementation but keeps `git-wt` clean and makes git-crypt support opt-in.

### Testing Your Setup

```bash
# Without hooks - will fail in git-crypt repos
./git-wt add test-branch

# With hooks installed - should work
./git-wt add test-branch

# Verify the worktree is unlocked
cd test-branch
git crypt status
# Should show files as decrypted
```

## Creating Custom Hooks

You can create your own hooks for other use cases:

**Example: Notify on worktree creation**

Create `.git/hooks/post-worktree-add`:
```bash
#!/bin/bash
worktree_path="$1"
echo "✅ New worktree created at: $worktree_path"
# Send notification, update IDE workspace, etc.
```

**Example: Validate branch naming**

Create `.git/hooks/pre-worktree-add`:
```bash
#!/bin/bash
path="$1"
branch="${2:-$1}"

if [[ ! "$branch" =~ ^(feature|bugfix|hotfix)/ ]]; then
  echo "Error: Branch must start with feature/, bugfix/, or hotfix/" >&2
  exit 1
fi
```

Don't forget to make your hooks executable:
```bash
chmod +x .git/hooks/pre-worktree-add .git/hooks/post-worktree-add
```

## Limitations

- Hooks only work for `git-wt add` (or `git-wt a`)
- Other operations (`rm`, `ls`, `clone`) do not have hooks yet
- Hooks must be in `.git/hooks/` (the shared location for worktrees)
- git-crypt hook requires git-crypt to be installed and the key to be available

## Migration from Old git-wt

If you're using an older version of `git-wt` with inline git-crypt support:

1. The new version removes inline git-crypt handling
2. Install the hooks using the instructions above
3. Test in a non-critical branch first
4. Both versions achieve the same result, but the hook-based approach is cleaner and more flexible
