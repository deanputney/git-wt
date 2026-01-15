# git-wt Hook System

## Overview

Starting in this experimental branch, `git-wt` supports custom hooks that run before and after worktree operations. This allows repository-specific customization without modifying the core `git-wt` script.

## Hook Convention

Hooks are executable scripts placed in `.git/hooks/` with specific names:

- **`git-wt-pre-worktree-add`** - Runs before `git worktree add`
- **`git-wt-post-worktree-add`** - Runs after `git worktree add` succeeds

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

This branch includes `git-wt-git-crypt-helper`, a script that implements the git-crypt workaround as hooks instead of inline in `git-wt`.

### Installation for git-crypt Users

**Option 1: Symlink approach (recommended)**

```bash
# From your repository root
cd .git/hooks

# Create symlinks to the helper script
ln -s ../../git-wt-git-crypt-helper git-wt-pre-worktree-add
ln -s ../../git-wt-git-crypt-helper git-wt-post-worktree-add

# Make the helper executable (the symlinks inherit this)
chmod +x ../../git-wt-git-crypt-helper
```

The helper script auto-detects whether it's running as pre or post hook based on its name.

**Option 2: Copy and configure**

```bash
# Copy the helper twice
cp git-wt-git-crypt-helper .git/hooks/git-wt-pre-worktree-add
cp git-wt-git-crypt-helper .git/hooks/git-wt-post-worktree-add

# Make them executable
chmod +x .git/hooks/git-wt-*-worktree-add

# Optional: Set explicit phase in each copy
# Edit .git/hooks/git-wt-pre-worktree-add and add near the top:
#   HOOK_PHASE=pre
# Edit .git/hooks/git-wt-post-worktree-add and add near the top:
#   HOOK_PHASE=post
```

### How It Works

The helper script:

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
```bash
#!/bin/bash
# .git/hooks/git-wt-post-worktree-add

worktree_path="$1"
echo "✅ New worktree created at: $worktree_path"
# Send notification, update IDE workspace, etc.
```

**Example: Validate branch naming**
```bash
#!/bin/bash
# .git/hooks/git-wt-pre-worktree-add

path="$1"
branch="${2:-$1}"

if [[ ! "$branch" =~ ^(feature|bugfix|hotfix)/ ]]; then
  echo "Error: Branch must start with feature/, bugfix/, or hotfix/" >&2
  exit 1
fi
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
