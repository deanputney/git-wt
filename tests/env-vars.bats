#!/usr/bin/env bats
# Tests for environment variables and argument parsing

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load 'test_helper/test_helpers'

setup() {
  # Create unique temp directory for each test
  TEST_TEMP_DIR="$(mktemp -d)"
  cd "$TEST_TEMP_DIR"

  # Configure git via environment variables
  export GIT_AUTHOR_NAME="Test User"
  export GIT_AUTHOR_EMAIL="test@example.com"
  export GIT_COMMITTER_NAME="Test User"
  export GIT_COMMITTER_EMAIL="test@example.com"

  # Initialize a bare repo with main worktree
  bash "$GIT_WT_SCRIPT" init >/dev/null 2>&1
  cd main

  # Set local config for this repo
  git config user.name "Test User"
  git config user.email "test@example.com"
  git config init.defaultBranch main

  echo "test content" > README.md
  git add README.md
  git commit -q -m "Initial commit"
  cd ..
}

teardown() {
  # Clean up temp directory
  cd /
  rm -rf "$TEST_TEMP_DIR"
}

################################################################################
# A. GIT_WORKTREE_PATH Environment Variable Tests
################################################################################

@test "GIT_WORKTREE_PATH is set in pre-worktree-add hook" {
  # Setup: Create pre-hook that captures GIT_WORKTREE_PATH
  local env_file="$TEST_TEMP_DIR/.env-pre"
  mkdir -p .git/hooks
  cat > .git/hooks/pre-worktree-add <<EOF
#!/bin/bash
echo "\$GIT_WORKTREE_PATH" > "$env_file"
exit 0
EOF
  chmod +x .git/hooks/pre-worktree-add

  # Run
  run bash "$GIT_WT_SCRIPT" add feature-branch

  # Assert
  assert_success
  local captured_path=$(cat "$env_file")
  [[ "$captured_path" == "feature-branch" ]]
}

@test "GIT_WORKTREE_PATH is set in post-worktree-add hook" {
  # Setup: Create post-hook that captures GIT_WORKTREE_PATH
  local env_file="$TEST_TEMP_DIR/.env-post"
  mkdir -p .git/hooks
  cat > .git/hooks/post-worktree-add <<EOF
#!/bin/bash
echo "\$GIT_WORKTREE_PATH" > "$env_file"
exit 0
EOF
  chmod +x .git/hooks/post-worktree-add

  # Run
  run bash "$GIT_WT_SCRIPT" add feature-branch

  # Assert
  assert_success
  local captured_path=$(cat "$env_file")
  [[ "$captured_path" == "feature-branch" ]]
}

@test "GIT_WORKTREE_PATH is correct with -b option" {
  # Setup: Create pre-hook that captures GIT_WORKTREE_PATH
  local env_file="$TEST_TEMP_DIR/.env-path"
  mkdir -p .git/hooks
  cat > .git/hooks/pre-worktree-add <<EOF
#!/bin/bash
echo "\$GIT_WORKTREE_PATH" > "$env_file"
exit 0
EOF
  chmod +x .git/hooks/pre-worktree-add

  # Run with -b option (this was the buggy case)
  run bash "$GIT_WT_SCRIPT" add -b new-branch my-worktree

  # Assert - path should be "my-worktree", NOT "-b"
  assert_success
  local captured_path=$(cat "$env_file")
  [[ "$captured_path" == "my-worktree" ]]
}

################################################################################
# B. GIT_BRANCH Environment Variable Tests
################################################################################

@test "GIT_BRANCH is set when using -b option in pre-hook" {
  # Setup: Create pre-hook that captures GIT_BRANCH
  local env_file="$TEST_TEMP_DIR/.env-branch-pre"
  mkdir -p .git/hooks
  cat > .git/hooks/pre-worktree-add <<EOF
#!/bin/bash
echo "\$GIT_BRANCH" > "$env_file"
exit 0
EOF
  chmod +x .git/hooks/pre-worktree-add

  # Run
  run bash "$GIT_WT_SCRIPT" add -b test-branch test-worktree

  # Assert
  assert_success
  local captured_branch=$(cat "$env_file")
  [[ "$captured_branch" == "test-branch" ]]
}

@test "GIT_BRANCH is set correctly in post-hook with -b option" {
  # Setup: Create post-hook that captures GIT_BRANCH
  local env_file="$TEST_TEMP_DIR/.env-branch-post"
  mkdir -p .git/hooks
  cat > .git/hooks/post-worktree-add <<EOF
#!/bin/bash
echo "\$GIT_BRANCH" > "$env_file"
exit 0
EOF
  chmod +x .git/hooks/post-worktree-add

  # Run
  run bash "$GIT_WT_SCRIPT" add -b test-branch test-worktree

  # Assert
  assert_success
  local captured_branch=$(cat "$env_file")
  [[ "$captured_branch" == "test-branch" ]]
}

@test "GIT_BRANCH is set with -B option" {
  # Setup: Create post-hook that captures GIT_BRANCH
  local env_file="$TEST_TEMP_DIR/.env-branch"
  mkdir -p .git/hooks
  cat > .git/hooks/post-worktree-add <<EOF
#!/bin/bash
echo "\$GIT_BRANCH" > "$env_file"
exit 0
EOF
  chmod +x .git/hooks/post-worktree-add

  # Run
  run bash "$GIT_WT_SCRIPT" add -B force-branch test-worktree

  # Assert
  assert_success
  local captured_branch=$(cat "$env_file")
  [[ "$captured_branch" == "force-branch" ]]
}

@test "GIT_BRANCH is set from commitish when no -b option" {
  # Setup: Create a branch to use as commitish
  cd main
  git checkout -q -b existing-branch
  git checkout -q main
  cd ..

  # Create post-hook that captures GIT_BRANCH
  local env_file="$TEST_TEMP_DIR/.env-branch"
  mkdir -p .git/hooks
  cat > .git/hooks/post-worktree-add <<EOF
#!/bin/bash
echo "\$GIT_BRANCH" > "$env_file"
exit 0
EOF
  chmod +x .git/hooks/post-worktree-add

  # Run
  run bash "$GIT_WT_SCRIPT" add test-worktree existing-branch

  # Assert
  assert_success
  local captured_branch=$(cat "$env_file")
  [[ "$captured_branch" == "existing-branch" ]]
}

@test "GIT_BRANCH is not set with --detach option" {
  # Setup: Create post-hook that checks if GIT_BRANCH is set
  local env_file="$TEST_TEMP_DIR/.env-branch"
  mkdir -p .git/hooks
  cat > .git/hooks/post-worktree-add <<EOF
#!/bin/bash
if [ -z "\${GIT_BRANCH+x}" ]; then
  echo "UNSET" > "$env_file"
else
  echo "SET:\$GIT_BRANCH" > "$env_file"
fi
exit 0
EOF
  chmod +x .git/hooks/post-worktree-add

  # Run
  run bash "$GIT_WT_SCRIPT" add --detach test-worktree

  # Assert
  assert_success
  local captured_status=$(cat "$env_file")
  [[ "$captured_status" == "UNSET" ]]
}

@test "GIT_BRANCH reflects actual branch in post-hook" {
  # This tests that post-hook gets the actual branch from the worktree,
  # not just the parsed argument (important for auto-generated branch names)
  local env_file="$TEST_TEMP_DIR/.env-branch"
  mkdir -p .git/hooks
  cat > .git/hooks/post-worktree-add <<EOF
#!/bin/bash
echo "\$GIT_BRANCH" > "$env_file"
exit 0
EOF
  chmod +x .git/hooks/post-worktree-add

  # Run with just path (git will auto-create branch from path basename)
  run bash "$GIT_WT_SCRIPT" add auto-branch

  # Assert
  assert_success
  local captured_branch=$(cat "$env_file")
  [[ "$captured_branch" == "auto-branch" ]]
}

################################################################################
# C. GIT_COMMITISH Environment Variable Tests
################################################################################

@test "GIT_COMMITISH is set when commitish is provided" {
  # Setup: Create a branch to use as commitish
  cd main
  git checkout -q -b source-branch
  git checkout -q main
  cd ..

  # Create pre-hook that captures GIT_COMMITISH
  local env_file="$TEST_TEMP_DIR/.env-commitish"
  mkdir -p .git/hooks
  cat > .git/hooks/pre-worktree-add <<EOF
#!/bin/bash
echo "\$GIT_COMMITISH" > "$env_file"
exit 0
EOF
  chmod +x .git/hooks/pre-worktree-add

  # Run
  run bash "$GIT_WT_SCRIPT" add test-worktree source-branch

  # Assert
  assert_success
  local captured_commitish=$(cat "$env_file")
  [[ "$captured_commitish" == "source-branch" ]]
}

@test "GIT_COMMITISH is not set when only path is provided" {
  # Setup: Create pre-hook that checks if GIT_COMMITISH is set
  local env_file="$TEST_TEMP_DIR/.env-commitish"
  mkdir -p .git/hooks
  cat > .git/hooks/pre-worktree-add <<EOF
#!/bin/bash
if [ -z "\${GIT_COMMITISH+x}" ]; then
  echo "UNSET" > "$env_file"
else
  echo "SET:\$GIT_COMMITISH" > "$env_file"
fi
exit 0
EOF
  chmod +x .git/hooks/pre-worktree-add

  # Run
  run bash "$GIT_WT_SCRIPT" add test-worktree

  # Assert
  assert_success
  local captured_status=$(cat "$env_file")
  [[ "$captured_status" == "UNSET" ]]
}

################################################################################
# D. Argument Parsing Bug Regression Tests
################################################################################

@test "argument parsing: -b option doesn't cause duplicate arguments" {
  # This is the main bug that was fixed - with -b option, the worktree path
  # was incorrectly identified as "-b", causing duplicate -b in hook args

  local args_file="$TEST_TEMP_DIR/.hook-args"
  local path_file="$TEST_TEMP_DIR/.hook-path"
  mkdir -p .git/hooks
  cat > .git/hooks/post-worktree-add <<EOF
#!/bin/bash
echo "\$@" > "$args_file"
echo "\$GIT_WORKTREE_PATH" > "$path_file"
exit 0
EOF
  chmod +x .git/hooks/post-worktree-add

  # Run - this was the buggy scenario from FIX_GIT_WT.md
  run bash "$GIT_WT_SCRIPT" add -b test-4 test-worktree

  # Assert
  assert_success
  local captured_args=$(cat "$args_file")
  local captured_path=$(cat "$path_file")

  # Path should be "test-worktree", not "-b"
  [[ "$captured_path" == "test-worktree" ]]

  # Arguments should not have duplicate -b
  # Count occurrences of -b in arguments
  local b_count=$(echo "$captured_args" | grep -o -- "-b" | wc -l | tr -d ' ')
  [[ "$b_count" == "1" ]]
}

@test "argument parsing: handles multiple options before path" {
  local env_file="$TEST_TEMP_DIR/.env-path"
  mkdir -p .git/hooks
  cat > .git/hooks/pre-worktree-add <<EOF
#!/bin/bash
echo "\$GIT_WORKTREE_PATH" > "$env_file"
exit 0
EOF
  chmod +x .git/hooks/pre-worktree-add

  # Run with multiple options
  run bash "$GIT_WT_SCRIPT" add -b new-branch --force test-worktree

  # Assert
  assert_success
  local captured_path=$(cat "$env_file")
  [[ "$captured_path" == "test-worktree" ]]
}

@test "argument parsing: handles --orphan with -b option" {
  local env_file="$TEST_TEMP_DIR/.env-branch"
  mkdir -p .git/hooks
  cat > .git/hooks/post-worktree-add <<EOF
#!/bin/bash
echo "\$GIT_BRANCH" > "$env_file"
exit 0
EOF
  chmod +x .git/hooks/post-worktree-add

  # Run - --orphan is a flag, branch name comes from -b
  run bash "$GIT_WT_SCRIPT" add --orphan -b orphan-branch orphan-worktree

  # Assert
  assert_success
  local captured_branch=$(cat "$env_file")
  [[ "$captured_branch" == "orphan-branch" ]]
}

@test "argument parsing: handles flags without values" {
  local env_file="$TEST_TEMP_DIR/.env-path"
  mkdir -p .git/hooks
  cat > .git/hooks/pre-worktree-add <<EOF
#!/bin/bash
echo "\$GIT_WORKTREE_PATH" > "$env_file"
exit 0
EOF
  chmod +x .git/hooks/pre-worktree-add

  # Run with various flags
  run bash "$GIT_WT_SCRIPT" add --force --checkout -q test-worktree

  # Assert
  assert_success
  local captured_path=$(cat "$env_file")
  [[ "$captured_path" == "test-worktree" ]]
}

@test "argument parsing: error when no worktree path found" {
  # Run with only options, no path
  run bash "$GIT_WT_SCRIPT" add -b branch-only

  # Assert - should fail because no path was provided
  assert_failure
  assert_output --partial "No worktree path found"
}

################################################################################
# E. All Environment Variables Together
################################################################################

@test "all environment variables are set correctly together" {
  local env_file="$TEST_TEMP_DIR/.env-all"
  mkdir -p .git/hooks
  cat > .git/hooks/post-worktree-add <<EOF
#!/bin/bash
echo "PATH:\$GIT_WORKTREE_PATH" > "$env_file"
echo "BRANCH:\$GIT_BRANCH" >> "$env_file"
echo "COMMITISH:\$GIT_COMMITISH" >> "$env_file"
exit 0
EOF
  chmod +x .git/hooks/post-worktree-add

  # Create a branch to use as commitish
  cd main
  git checkout -q -b source-branch
  git checkout -q main
  cd ..

  # Run
  run bash "$GIT_WT_SCRIPT" add -b my-branch my-worktree source-branch

  # Assert
  assert_success
  assert_file_contains "$env_file" "PATH:my-worktree"
  assert_file_contains "$env_file" "BRANCH:my-branch"
  assert_file_contains "$env_file" "COMMITISH:source-branch"
}

################################################################################
# F. Updated Example Hooks Tests
################################################################################

@test "hello-world hooks display environment variables" {
  # Setup: Install hello-world hooks
  bash -c "echo 'y' | bash '$GIT_WT_SCRIPT' install-hooks hello-world" >/dev/null 2>&1

  # Run
  run bash "$GIT_WT_SCRIPT" add -b test-branch test-hello

  # Assert
  assert_success
  assert_output --partial "GIT_WORKTREE_PATH: test-hello"
  assert_output --partial "GIT_BRANCH: test-branch"
}

@test "git-crypt post-hook uses GIT_WORKTREE_PATH" {
  # Get the directory containing git-wt script
  local script_dir=$(dirname "$GIT_WT_SCRIPT")

  # Setup: Copy git-crypt post-hook
  mkdir -p .git/hooks
  cp "$script_dir/examples/hooks/git-crypt-post-worktree-add" .git/hooks/post-worktree-add
  chmod +x .git/hooks/post-worktree-add

  # Run (git-crypt not configured, should exit cleanly)
  run bash "$GIT_WT_SCRIPT" add feature

  # Assert - should succeed even though GIT_WORKTREE_PATH changed
  # (the hook should detect no git-crypt and exit cleanly)
  assert_success
  [[ -d "feature" ]]
}
