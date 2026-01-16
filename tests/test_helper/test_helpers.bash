#!/usr/bin/env bash
# Test helper functions for git-wt tests

# Path to the git-wt script being tested
GIT_WT_SCRIPT="${BATS_TEST_DIRNAME}/../git-wt"

# setup_test_repo - Creates a fresh git repo in current directory
# Initializes git, configures user, and creates an initial commit
setup_test_repo() {
  git init -q
  git config user.name "Test User"
  git config user.email "test@example.com"
  git config init.defaultBranch main

  # Create initial commit
  echo "initial content" > README.md
  git add README.md
  git commit -q -m "Initial commit"
}

# create_branch <branch_name> - Creates and checks out a new branch
create_branch() {
  local branch_name="$1"
  git checkout -q -b "$branch_name"
}

# add_uncommitted_changes - Creates modified files without committing
add_uncommitted_changes() {
  echo "modified content" > README.md
  echo "new file content" > newfile.txt
}

# add_staged_changes - Creates and stages changes
add_staged_changes() {
  echo "staged content" > staged.txt
  git add staged.txt
}

# add_untracked_files - Creates untracked files
add_untracked_files() {
  echo "untracked content" > untracked.txt
}

# create_stash - Creates stashed changes
create_stash() {
  echo "stashed content" > README.md
  git stash push -q -m "Test stash"
}

# make_repo_bare - Converts repo to bare (for testing error case)
make_repo_bare() {
  git config core.bare true
}

# create_worktree <branch> - Creates a worktree (for testing error case)
create_worktree() {
  local branch="$1"
  git checkout -q -b "$branch"
  git checkout -q main
  mkdir -p worktrees
  git worktree add -q "worktrees/$branch" "$branch"
}

# detach_head - Puts repo in detached HEAD state
detach_head() {
  local commit_sha=$(git rev-parse HEAD)
  git checkout -q --detach "$commit_sha"
}

# verify_worktree_structure - Validates post-conversion structure
# Checks that .git is bare and worktree directories exist
verify_worktree_structure() {
  local expected_branch="$1"

  # Check .git is bare
  local is_bare=$(git config core.bare)
  [[ "$is_bare" == "true" ]]

  # Check worktree directory exists
  [[ -d "$expected_branch" ]]

  # Check .git file exists in worktree
  [[ -f "$expected_branch/.git" ]]
}

# count_worktrees - Returns number of worktrees
count_worktrees() {
  git worktree list | wc -l | tr -d ' '
}

# assert_file_exists <path> - File existence assertion
assert_file_exists() {
  local file_path="$1"
  [[ -f "$file_path" ]] || [[ -d "$file_path" ]]
}

# assert_file_contains <path> <content> - Content assertion
assert_file_contains() {
  local file_path="$1"
  local expected_content="$2"
  grep -q "$expected_content" "$file_path"
}

# get_primary_branch - Returns main or master, whichever exists
get_primary_branch() {
  if git rev-parse --verify main >/dev/null 2>&1; then
    echo "main"
  elif git rev-parse --verify master >/dev/null 2>&1; then
    echo "master"
  else
    echo ""
  fi
}

# create_remote_repo - Creates a bare repo to act as remote
create_remote_repo() {
  local remote_dir="$TEST_TEMP_DIR/remote"
  mkdir -p "$remote_dir"
  git init --bare -q "$remote_dir"
  git remote add origin "$remote_dir"
  git push -q origin main
}
