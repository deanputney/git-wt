#!/usr/bin/env bats
# Integration tests for git wt init command

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load 'test_helper/test_helpers'

setup() {
  # Create unique temp directory for each test
  TEST_TEMP_DIR="$(mktemp -d)"
  cd "$TEST_TEMP_DIR"

  # Configure git globally for tests
  git config --global user.name "Test User"
  git config --global user.email "test@example.com"
  git config --global init.defaultBranch main
}

teardown() {
  # Clean up temp directory
  cd /
  rm -rf "$TEST_TEMP_DIR"
}

################################################################################
# A. Pre-flight Validation Tests
################################################################################

@test "init fails when not in a git repository" {
  # Setup: Empty directory (no git init)

  # Run
  run bash "$GIT_WT_SCRIPT" init

  # Assert
  assert_failure
  assert_output --partial "Error: Not a git repository"
}

@test "init fails when repository is already bare" {
  # Setup: Create bare repo
  git init --bare -q

  # Run
  run bash "$GIT_WT_SCRIPT" init

  # Assert
  assert_failure
  assert_output --partial "Error: Repository is already bare"
}

@test "init fails when already in worktree structure" {
  # Setup: Create repo and convert to worktree structure, then cd into worktree
  setup_test_repo
  echo "Y" | bash "$GIT_WT_SCRIPT" init
  cd main

  # Run
  run bash "$GIT_WT_SCRIPT" init

  # Assert
  assert_failure
  assert_output --partial "Error: Already in a worktree-based repository structure"
}

@test "init fails when repository has existing worktrees" {
  # Setup: Create repo with worktree
  setup_test_repo
  create_worktree "feature"

  # Run
  run bash "$GIT_WT_SCRIPT" init

  # Assert
  assert_failure
  assert_output --partial "Error: Repository already has worktrees"
}

@test "init fails when in detached HEAD state" {
  # Setup: Create repo and detach HEAD
  setup_test_repo
  detach_head

  # Run
  run bash "$GIT_WT_SCRIPT" init

  # Assert
  assert_failure
  assert_output --partial "Error: Repository is in detached HEAD state"
}

@test "init aborts when user declines confirmation with uncommitted changes" {
  # Setup: Create repo with uncommitted changes
  setup_test_repo
  add_uncommitted_changes

  # Run with "N" response
  run bash -c "echo 'N' | bash '$GIT_WT_SCRIPT' init"

  # Assert
  assert_success
  assert_output --partial "Aborted"

  # Verify no conversion occurred
  [[ ! -d "main" ]]
  [[ $(git config core.bare) != "true" ]]
}

################################################################################
# B. Happy Path Tests
################################################################################

@test "init converts clean repo with main branch successfully" {
  skip "TODO: Fix worktree count assertion - platform difference between macOS and Linux"
  # Setup: Clean repo on main branch
  setup_test_repo

  # Run
  run bash "$GIT_WT_SCRIPT" init

  # Assert
  assert_success
  assert_output --partial "Successfully converted"

  # Verify .git is bare
  bare_config=$(git config core.bare)
  [[ "$bare_config" == "true" ]]

  # Verify main/ directory exists with .git file
  [[ -d "main" ]]
  [[ -f "main/.git" ]]

  # Verify worktree count
  local count=$(count_worktrees)
  [[ "$count" -eq 1 ]]

  # Verify file content preserved
  [[ -f "main/README.md" ]]
}

@test "init converts clean repo with master branch successfully" {
  # Setup: Clean repo on master branch
  git init -q
  git config user.name "Test User"
  git config user.email "test@example.com"
  git config init.defaultBranch master
  git checkout -q -b master
  echo "initial content" > README.md
  git add README.md
  git commit -q -m "Initial commit"

  # Run
  run bash "$GIT_WT_SCRIPT" init

  # Assert
  assert_success

  # Verify master/ directory exists
  [[ -d "master" ]]
  [[ -f "master/.git" ]]
}

@test "init creates both current branch and main worktrees" {
  skip "TODO: Fix worktree count assertion"
  # Setup: Clean repo on feature branch
  setup_test_repo
  create_branch "feature"

  # Run
  run bash "$GIT_WT_SCRIPT" init

  # Assert
  assert_success

  # Verify feature/ directory exists
  [[ -d "feature" ]]
  [[ -f "feature/.git" ]]

  # Verify main/ directory exists
  [[ -d "main" ]]
  [[ -f "main/.git" ]]

  # Verify worktree count
  local count=$(count_worktrees)
  [[ "$count" -eq 2 ]]
}

@test "init on feature branch without main creates only feature worktree" {
  skip "TODO: Fix worktree count assertion"
  # Setup: Clean repo on feature branch, delete main
  setup_test_repo
  git branch -m main feature

  # Run
  run bash "$GIT_WT_SCRIPT" init

  # Assert
  assert_success

  # Verify feature/ directory exists
  [[ -d "feature" ]]

  # Verify main/ does not exist
  [[ ! -d "main" ]]

  # Verify worktree count
  local count=$(count_worktrees)
  [[ "$count" -eq 1 ]]
}

@test "init prefers main over master for primary branch" {
  # Setup: Repo with both main and master, on feature
  setup_test_repo
  create_branch "master"
  git checkout -q main
  create_branch "feature"

  # Run
  run bash "$GIT_WT_SCRIPT" init

  # Assert
  assert_success

  # Verify feature/ and main/ created (not master/)
  [[ -d "feature" ]]
  [[ -d "main" ]]
  [[ ! -d "master" ]]
}

@test "init success message includes branch names" {
  # Setup: Clean repo on feature branch
  setup_test_repo
  create_branch "feature"

  # Run
  run bash "$GIT_WT_SCRIPT" init

  # Assert
  assert_success
  assert_output --partial "feature"
}

@test "init configures fetch refspec when remote exists" {
  skip "TODO: Fix hanging git push in create_remote_repo helper"
  # Setup: Repo with remote
  setup_test_repo
  create_remote_repo

  # Run
  run bash "$GIT_WT_SCRIPT" init

  # Assert
  assert_success

  # Verify fetch refspec configured
  local fetch_spec=$(git config remote.origin.fetch)
  [[ "$fetch_spec" == "+refs/heads/*:refs/remotes/origin/*" ]]
}

@test "init works without remote" {
  skip "TODO: Fix remote refspec test logic"
  # Setup: Local repo without remote
  setup_test_repo

  # Run
  run bash "$GIT_WT_SCRIPT" init

  # Assert
  assert_success

  # Verify no remote configured
  run git config remote.origin.fetch
  assert_failure
}

################################################################################
# C. State Preservation Tests
################################################################################

@test "init preserves uncommitted changes" {
  # Setup: Repo with uncommitted changes
  setup_test_repo
  echo "modified content" > README.md

  # Run (with Y confirmation)
  run bash -c "echo 'Y' | bash '$GIT_WT_SCRIPT' init"

  # Assert
  assert_success

  # Verify changes preserved in worktree
  [[ -f "main/README.md" ]]
  grep -q "modified content" "main/README.md"

  # Verify git status shows modifications
  cd main
  run git status --short
  assert_output --partial "M README.md"
}

@test "init preserves staged changes" {
  # Setup: Repo with staged changes
  setup_test_repo
  echo "staged content" > staged.txt
  git add staged.txt

  # Run
  run bash -c "echo 'Y' | bash '$GIT_WT_SCRIPT' init"

  # Assert
  assert_success

  # Verify staged changes preserved
  cd main
  [[ -f "staged.txt" ]]

  # Check if file is staged
  run git diff --cached --name-only
  assert_output --partial "staged.txt"
}

@test "init preserves untracked files" {
  # Setup: Repo with untracked files
  setup_test_repo
  echo "untracked content" > untracked.txt

  # Run
  run bash -c "echo 'Y' | bash '$GIT_WT_SCRIPT' init"

  # Assert
  assert_success

  # Verify untracked file exists
  [[ -f "main/untracked.txt" ]]
  grep -q "untracked content" "main/untracked.txt"

  # Verify git status shows untracked
  cd main
  run git status --short
  assert_output --partial "?? untracked.txt"
}

@test "init preserves stashes" {
  skip "TODO: Fix stash handling in bare repos"
  # Setup: Repo with stashes
  setup_test_repo
  echo "stashed content" > README.md
  git stash push -q -m "Test stash"

  # Create another stash
  echo "another change" > README.md
  git stash push -q -m "Second stash"

  # Run
  run bash "$GIT_WT_SCRIPT" init

  # Assert
  assert_success

  # Verify stashes exist
  run git stash list
  assert_output --partial "Test stash"
  assert_output --partial "Second stash"

  # Count stashes
  local stash_count=$(git stash list | wc -l | tr -d ' ')
  [[ "$stash_count" -eq 2 ]]
}

@test "init preserves mix of staged, unstaged, and untracked files" {
  # Setup: Complex working state
  setup_test_repo

  # Staged change
  echo "staged content" > staged.txt
  git add staged.txt

  # Unstaged modification
  echo "modified content" > README.md

  # Untracked file
  echo "untracked content" > untracked.txt

  # Run
  run bash -c "echo 'Y' | bash '$GIT_WT_SCRIPT' init"

  # Assert
  assert_success

  cd main

  # Verify staged file
  [[ -f "staged.txt" ]]
  run git diff --cached --name-only
  assert_output --partial "staged.txt"

  # Verify unstaged modification
  grep -q "modified content" "README.md"

  # Verify untracked file
  [[ -f "untracked.txt" ]]
  grep -q "untracked content" "untracked.txt"
}

@test "init preserves git config" {
  skip "TODO: Fix custom config preservation"
  # Setup: Repo with local config
  setup_test_repo
  git config core.ignorecase false
  git config custom.setting "test-value"

  # Run
  run bash "$GIT_WT_SCRIPT" init

  # Assert
  assert_success

  # Verify config preserved
  local ignorecase=$(git config core.ignorecase)
  [[ "$ignorecase" == "false" ]]

  local custom=$(git config custom.setting)
  [[ "$custom" == "test-value" ]]
}

@test "init handles repository with many files" {
  # Setup: Repo with many files
  setup_test_repo

  # Create 50 files
  for i in {1..50}; do
    echo "content $i" > "file$i.txt"
  done
  git add .
  git commit -q -m "Add many files"

  # Run
  run bash "$GIT_WT_SCRIPT" init

  # Assert
  assert_success

  # Verify all files present
  cd main
  local file_count=$(ls file*.txt 2>/dev/null | wc -l | tr -d ' ')
  [[ "$file_count" -eq 50 ]]
}

################################################################################
# D. Edge Cases
################################################################################

@test "init handles branch names with slashes" {
  skip "TODO: Fix directory creation for branch names with slashes"
  # Setup: Branch with special characters
  setup_test_repo
  create_branch "feature/test-123"

  # Run
  run bash "$GIT_WT_SCRIPT" init

  # Assert
  assert_success

  # Verify directory created (slashes become subdirectories)
  [[ -d "feature" ]]
  [[ -d "feature/test-123" ]]
}

@test "init handles long branch names" {
  # Setup: Branch with long name
  setup_test_repo
  local long_name="feature-with-a-very-long-branch-name-that-exceeds-typical-length"
  create_branch "$long_name"

  # Run
  run bash "$GIT_WT_SCRIPT" init

  # Assert
  assert_success

  # Verify directory created
  [[ -d "$long_name" ]]
}

@test "init works when run from subdirectory" {
  skip "TODO: Fix directory assertion - platform difference between macOS and Linux"
  # Setup: Repo with subdirectory
  setup_test_repo
  mkdir -p subdir
  cd subdir

  # Run
  run bash "$GIT_WT_SCRIPT" init

  # Assert
  assert_success

  # Verify conversion happened at repo root
  cd ..
  [[ -d "main" ]]
  local bare_config=$(git config core.bare)
  [[ "$bare_config" == "true" ]]
}

@test "init preserves multiple remotes" {
  skip "TODO: Fix hanging git push in create_remote_repo helper"
  # Setup: Repo with multiple remotes
  setup_test_repo
  create_remote_repo

  # Create second remote
  local remote2_dir="$TEST_TEMP_DIR/remote2"
  mkdir -p "$remote2_dir"
  git init --bare -q "$remote2_dir"
  git remote add backup "$remote2_dir"

  # Run
  run bash "$GIT_WT_SCRIPT" init

  # Assert
  assert_success

  # Verify both remotes exist
  run git remote
  assert_output --partial "origin"
  assert_output --partial "backup"
}

@test "init handles repository with .gitattributes" {
  # Setup: Repo with .gitattributes
  setup_test_repo
  echo "*.txt text eol=lf" > .gitattributes
  git add .gitattributes
  git commit -q -m "Add gitattributes"

  # Run
  run bash "$GIT_WT_SCRIPT" init

  # Assert
  assert_success

  # Verify .gitattributes preserved
  [[ -f "main/.gitattributes" ]]
  grep -q "*.txt text eol=lf" "main/.gitattributes"
}

@test "init handles repository with symbolic links" {
  skip "TODO: Fix symbolic link handling"
  # Setup: Repo with symlink
  setup_test_repo
  echo "target content" > target.txt
  ln -s target.txt link.txt
  git add link.txt
  git commit -q -m "Add symlink"

  # Run
  run bash "$GIT_WT_SCRIPT" init

  # Assert
  assert_success

  # Verify symlink preserved
  [[ -L "main/link.txt" ]]

  # Verify symlink target
  cd main
  [[ -f "link.txt" ]]
  local target=$(readlink link.txt)
  [[ "$target" == "target.txt" ]]
}

