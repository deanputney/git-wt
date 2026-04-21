#!/usr/bin/env bats
# Integration tests for git wt clean command

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load 'test_helper/test_helpers'

setup() {
  TEST_TEMP_DIR="$(mktemp -d)"
  cd "$TEST_TEMP_DIR"

  export GIT_AUTHOR_NAME="Test User"
  export GIT_AUTHOR_EMAIL="test@example.com"
  export GIT_COMMITTER_NAME="Test User"
  export GIT_COMMITTER_EMAIL="test@example.com"

  # Initialize git-wt repo (bare + main worktree)
  bash "$GIT_WT_SCRIPT" init >/dev/null 2>&1
  cd main
  git config user.name "Test User"
  git config user.email "test@example.com"
  git config init.defaultBranch main
  echo "initial" > README.md
  git add README.md
  git commit -q -m "Initial commit"
  cd ..
}

teardown() {
  cd /
  rm -rf "$TEST_TEMP_DIR"
}

# Create a feature worktree with one commit
create_feature_worktree() {
  local branch="$1"
  git worktree add "$branch" -b "$branch" >/dev/null 2>&1
  cd "$branch"
  echo "work" > "${branch}.txt"
  git add "${branch}.txt"
  git commit -q -m "Add work in ${branch}"
  cd ..
}

# Merge a branch into main
merge_into_main() {
  local branch="$1"
  cd main
  git merge -q --no-ff "$branch" -m "Merge ${branch} into main"
  cd ..
}

# Return a date string N days ago (Linux + macOS portable)
days_ago_date() {
  local n="$1"
  date -d "${n} days ago" "+%Y-%m-%dT%H:%M:%S" 2>/dev/null \
    || date -v-"${n}"d "+%Y-%m-%dT%H:%M:%S" 2>/dev/null
}

################################################################################
# clean merge tests
################################################################################

@test "clean merge detects and removes merged worktrees" {
  create_feature_worktree "feature1"
  merge_into_main "feature1"

  run bash "$GIT_WT_SCRIPT" clean merge --force
  assert_success
  assert_output --partial "feature1"
  [ ! -d "feature1" ]
}

@test "clean merge does not remove worktrees with commits ahead of merged state" {
  create_feature_worktree "feature1"
  merge_into_main "feature1"

  # Add a commit after the merge — branch diverges from what was merged
  cd feature1
  echo "extra" > extra.txt
  git add extra.txt
  git commit -q -m "Extra commit after merge"
  cd ..

  run bash "$GIT_WT_SCRIPT" clean merge --force
  assert_success
  assert_output "No worktrees to clean."
  [ -d "feature1" ]
}

@test "clean merge --dry-run shows preview without removing" {
  create_feature_worktree "feature1"
  merge_into_main "feature1"

  run bash "$GIT_WT_SCRIPT" clean merge --dry-run
  assert_success
  assert_output --partial "feature1"
  assert_output --partial "Dry run — no changes made."
  [ -d "feature1" ]
}

@test "clean merge --force removes without interactive prompt" {
  create_feature_worktree "feature1"
  merge_into_main "feature1"

  # Run with --force; no stdin needed
  run bash "$GIT_WT_SCRIPT" clean merge --force
  assert_success
  [ ! -d "feature1" ]
}

################################################################################
# clean stale tests
################################################################################

@test "clean stale detects worktrees with old last-commit dates" {
  git worktree add stale-wt -b stale-branch >/dev/null 2>&1
  cd stale-wt
  echo "work" > stale.txt
  git add stale.txt
  OLD_DATE="2020-01-01T00:00:00"
  GIT_COMMITTER_DATE="$OLD_DATE" git commit -q --date="$OLD_DATE" -m "Old commit"
  cd ..

  run bash "$GIT_WT_SCRIPT" clean stale 30 --force
  assert_success
  assert_output --partial "stale-wt"
  [ ! -d "stale-wt" ]
}

@test "clean stale skips worktrees with uncommitted changes" {
  git worktree add stale-wt -b stale-branch >/dev/null 2>&1
  cd stale-wt
  echo "work" > stale.txt
  git add stale.txt
  OLD_DATE="2020-01-01T00:00:00"
  GIT_COMMITTER_DATE="$OLD_DATE" git commit -q --date="$OLD_DATE" -m "Old commit"
  # Leave dirty file
  echo "dirty" > dirty.txt
  cd ..

  run bash "$GIT_WT_SCRIPT" clean stale 30 --force
  assert_success
  assert_output "No worktrees to clean."
  [ -d "stale-wt" ]
}

@test "clean stale uses custom day threshold - stale when age exceeds threshold" {
  git worktree add stale-wt -b stale-branch >/dev/null 2>&1
  cd stale-wt
  echo "work" > stale.txt
  git add stale.txt
  OLD_DATE=$(days_ago_date 10)
  GIT_COMMITTER_DATE="$OLD_DATE" git commit -q --date="$OLD_DATE" -m "10-day-old commit"
  cd ..

  # 10 days > threshold 7 → stale
  run bash "$GIT_WT_SCRIPT" clean stale 7 --force
  assert_success
  assert_output --partial "stale-wt"
  [ ! -d "stale-wt" ]
}

@test "clean stale uses custom day threshold - not stale when age within threshold" {
  git worktree add stale-wt -b stale-branch >/dev/null 2>&1
  cd stale-wt
  echo "work" > stale.txt
  git add stale.txt
  OLD_DATE=$(days_ago_date 10)
  GIT_COMMITTER_DATE="$OLD_DATE" git commit -q --date="$OLD_DATE" -m "10-day-old commit"
  cd ..

  # 10 days < threshold 30 → not stale
  run bash "$GIT_WT_SCRIPT" clean stale 30 --force
  assert_success
  assert_output "No worktrees to clean."
  [ -d "stale-wt" ]
}

################################################################################
# clean empty tests
################################################################################

@test "clean empty detects worktrees with no commits beyond primary" {
  # Create worktree with no new commits (branch starts at same point as main)
  git worktree add empty-wt -b empty-branch >/dev/null 2>&1

  run bash "$GIT_WT_SCRIPT" clean empty --force
  assert_success
  assert_output --partial "empty-wt"
  [ ! -d "empty-wt" ]
}

@test "clean empty skips worktrees with uncommitted changes" {
  git worktree add empty-wt -b empty-branch >/dev/null 2>&1
  # Leave a dirty file (not committed)
  echo "dirty" > empty-wt/dirty.txt

  run bash "$GIT_WT_SCRIPT" clean empty --force
  assert_success
  assert_output "No worktrees to clean."
  [ -d "empty-wt" ]
}

@test "clean empty skips worktrees with commits beyond primary" {
  git worktree add empty-wt -b empty-branch >/dev/null 2>&1
  cd empty-wt
  echo "extra" > extra.txt
  git add extra.txt
  git commit -q -m "Unique commit beyond primary"
  cd ..

  run bash "$GIT_WT_SCRIPT" clean empty --force
  assert_success
  assert_output "No worktrees to clean."
  [ -d "empty-wt" ]
}

################################################################################
# clean (no subcommand) tests
################################################################################

@test "clean with no subcommand collects all candidates with correct tags" {
  create_feature_worktree "merged-wt"
  merge_into_main "merged-wt"
  git worktree add empty-wt -b empty-branch >/dev/null 2>&1

  run bash "$GIT_WT_SCRIPT" clean --dry-run
  assert_success
  assert_output --partial "merged-wt"
  assert_output --partial "merged"
  assert_output --partial "empty-wt"
  assert_output --partial "empty"
  assert_output --partial "Dry run — no changes made."
}

@test "clean -n is equivalent to --dry-run" {
  create_feature_worktree "feature1"
  merge_into_main "feature1"

  run bash "$GIT_WT_SCRIPT" clean -n
  assert_success
  assert_output --partial "Dry run — no changes made."
  [ -d "feature1" ]
}

@test "clean reports no candidates when nothing to clean" {
  # No feature worktrees added
  run bash "$GIT_WT_SCRIPT" clean --force
  assert_success
  assert_output "No worktrees to clean."
}
