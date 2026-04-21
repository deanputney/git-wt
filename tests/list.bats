#!/usr/bin/env bats
# Integration tests for enhanced git wt list command

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

# Portable "N days ago" date string
days_ago_date() {
  local n="$1"
  date -d "${n} days ago" "+%Y-%m-%dT%H:%M:%S" 2>/dev/null \
    || date -v-"${n}"d "+%Y-%m-%dT%H:%M:%S" 2>/dev/null
}

################################################################################

@test "list shows primary branch with primary tag" {
  run bash "$GIT_WT_SCRIPT" list
  assert_success
  assert_output --partial "primary"
  assert_output --partial "main"
}

@test "list shows merged worktrees with merged tag" {
  create_feature_worktree "feature1"
  merge_into_main "feature1"

  run bash "$GIT_WT_SCRIPT" list
  assert_success
  assert_output --partial "merged"
  assert_output --partial "feature1"
}

@test "list shows merged-but-ahead worktrees with both merged and ahead tags" {
  create_feature_worktree "feature1"
  merge_into_main "feature1"

  # Add a commit after the merge
  cd feature1
  echo "extra" > extra.txt
  git add extra.txt
  git commit -q -m "Extra commit after merge"
  cd ..

  run bash "$GIT_WT_SCRIPT" list
  assert_success
  assert_output --partial "merged"
  assert_output --partial "ahead 1"
  assert_output --partial "feature1"
}

@test "list shows stale worktrees with stale tag" {
  git worktree add stale-wt -b stale-branch >/dev/null 2>&1
  cd stale-wt
  echo "work" > stale.txt
  git add stale.txt
  OLD_DATE="2020-01-01T00:00:00"
  GIT_COMMITTER_DATE="$OLD_DATE" git commit -q --date="$OLD_DATE" -m "Old commit"
  cd ..

  run bash "$GIT_WT_SCRIPT" list
  assert_success
  assert_output --partial "stale"
  assert_output --partial "stale-wt"
}

@test "list shows empty worktrees with empty tag" {
  git worktree add empty-wt -b empty-branch >/dev/null 2>&1

  run bash "$GIT_WT_SCRIPT" list
  assert_success
  assert_output --partial "empty"
  assert_output --partial "empty-wt"
}

@test "list shows dirty worktrees with dirty tag" {
  git worktree add dirty-wt -b dirty-branch >/dev/null 2>&1
  echo "uncommitted" > dirty-wt/dirty.txt

  run bash "$GIT_WT_SCRIPT" list
  assert_success
  assert_output --partial "dirty"
  assert_output --partial "dirty-wt"
}

@test "list shows ahead count for unmerged worktrees with commits" {
  create_feature_worktree "feature1"

  run bash "$GIT_WT_SCRIPT" list
  assert_success
  assert_output --partial "ahead 1"
  assert_output --partial "feature1"
}

@test "list shows all worktrees including bare repo" {
  create_feature_worktree "feature1"

  run bash "$GIT_WT_SCRIPT" list
  assert_success
  assert_output --partial "bare"
  assert_output --partial "main"
  assert_output --partial "feature1"
}

@test "ls alias works the same as list" {
  run bash "$GIT_WT_SCRIPT" ls
  assert_success
  assert_output --partial "primary"
}
