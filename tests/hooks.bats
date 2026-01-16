#!/usr/bin/env bats
# Integration tests for git wt hook system

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

  # Initialize a bare repo with main worktree
  bash "$GIT_WT_SCRIPT" init >/dev/null 2>&1
  cd main
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
# A. Pre-worktree-add Hook Tests
################################################################################

@test "pre-worktree-add hook runs before worktree creation" {
  # Setup: Create pre-hook that logs execution
  local marker_file="$TEST_TEMP_DIR/.hook-pre-ran"
  mkdir -p .git/hooks
  cat > .git/hooks/pre-worktree-add <<EOF
#!/bin/bash
echo "PRE_HOOK_RAN" > "$marker_file"
exit 0
EOF
  chmod +x .git/hooks/pre-worktree-add

  # Run
  run bash "$GIT_WT_SCRIPT" add feature

  # Assert
  assert_success
  [[ -f "$marker_file" ]]
}

@test "pre-worktree-add hook receives correct arguments" {
  # Setup: Create pre-hook that captures arguments
  local args_file="$TEST_TEMP_DIR/.hook-args"
  mkdir -p .git/hooks
  cat > .git/hooks/pre-worktree-add <<EOF
#!/bin/bash
echo "\$@" > "$args_file"
exit 0
EOF
  chmod +x .git/hooks/pre-worktree-add

  # Run
  run bash "$GIT_WT_SCRIPT" add feature-branch

  # Assert
  assert_success
  local args=$(cat "$args_file")
  [[ "$args" == "feature-branch" ]]
}

@test "pre-worktree-add hook can abort worktree creation" {
  # Setup: Create pre-hook that fails
  mkdir -p .git/hooks
  cat > .git/hooks/pre-worktree-add <<'EOF'
#!/bin/bash
echo "Hook validation failed" >&2
exit 1
EOF
  chmod +x .git/hooks/pre-worktree-add

  # Run
  run bash "$GIT_WT_SCRIPT" add feature

  # Assert
  assert_failure
  assert_output --partial "pre-worktree-add hook failed"

  # Verify worktree was NOT created
  [[ ! -d "feature" ]]
}

@test "pre-worktree-add hook failure includes exit code" {
  # Setup: Create pre-hook that fails with specific code
  mkdir -p .git/hooks
  cat > .git/hooks/pre-worktree-add <<'EOF'
#!/bin/bash
exit 42
EOF
  chmod +x .git/hooks/pre-worktree-add

  # Run
  run bash "$GIT_WT_SCRIPT" add feature

  # Assert
  assert_failure
  assert_output --partial "exit code 42"
}

################################################################################
# B. Post-worktree-add Hook Tests
################################################################################

@test "post-worktree-add hook runs after worktree creation" {
  # Setup: Create post-hook that logs execution
  local marker_file="$TEST_TEMP_DIR/.hook-post-ran"
  mkdir -p .git/hooks
  cat > .git/hooks/post-worktree-add <<EOF
#!/bin/bash
echo "POST_HOOK_RAN" > "$marker_file"
exit 0
EOF
  chmod +x .git/hooks/post-worktree-add

  # Run
  run bash "$GIT_WT_SCRIPT" add feature

  # Assert
  assert_success
  [[ -f "$marker_file" ]]
  [[ -d "feature" ]]  # Worktree was created
}

@test "post-worktree-add hook receives worktree path as first argument" {
  # Setup: Create post-hook that captures arguments
  local path_file="$TEST_TEMP_DIR/.hook-path"
  mkdir -p .git/hooks
  cat > .git/hooks/post-worktree-add <<EOF
#!/bin/bash
echo "\$1" > "$path_file"
exit 0
EOF
  chmod +x .git/hooks/post-worktree-add

  # Run
  run bash "$GIT_WT_SCRIPT" add feature-branch

  # Assert
  assert_success
  local path=$(cat "$path_file")
  [[ "$path" == "feature-branch" ]]
}

@test "post-worktree-add hook failure reports error but worktree exists" {
  # Setup: Create post-hook that fails
  mkdir -p .git/hooks
  cat > .git/hooks/post-worktree-add <<'EOF'
#!/bin/bash
echo "Post-processing failed" >&2
exit 1
EOF
  chmod +x .git/hooks/post-worktree-add

  # Run
  run bash "$GIT_WT_SCRIPT" add feature

  # Assert
  assert_failure
  assert_output --partial "post-worktree-add hook failed"
  assert_output --partial "worktree was created"

  # Verify worktree WAS created (post-hook failure doesn't prevent creation)
  [[ -d "feature" ]]
}

################################################################################
# C. Both Hooks Together
################################################################################

@test "both pre and post hooks run in correct order" {
  # Setup: Create both hooks that log execution
  local order_file="$TEST_TEMP_DIR/.hook-order"
  mkdir -p .git/hooks

  cat > .git/hooks/pre-worktree-add <<EOF
#!/bin/bash
echo "PRE" >> "$order_file"
exit 0
EOF
  chmod +x .git/hooks/pre-worktree-add

  cat > .git/hooks/post-worktree-add <<EOF
#!/bin/bash
echo "POST" >> "$order_file"
exit 0
EOF
  chmod +x .git/hooks/post-worktree-add

  # Run
  run bash "$GIT_WT_SCRIPT" add feature

  # Assert
  assert_success
  local order=$(cat "$order_file")
  [[ "$order" == $'PRE\nPOST' ]]
}

@test "post hook does not run if pre hook fails" {
  # Setup: Create both hooks, pre fails
  local marker_file="$TEST_TEMP_DIR/.post-should-not-run"
  mkdir -p .git/hooks

  cat > .git/hooks/pre-worktree-add <<'EOF'
#!/bin/bash
exit 1
EOF
  chmod +x .git/hooks/pre-worktree-add

  cat > .git/hooks/post-worktree-add <<EOF
#!/bin/bash
echo "POST_RAN" > "$marker_file"
exit 0
EOF
  chmod +x .git/hooks/post-worktree-add

  # Run
  run bash "$GIT_WT_SCRIPT" add feature

  # Assert
  assert_failure
  [[ ! -f "$marker_file" ]]
}

################################################################################
# D. Backward Compatibility Tests
################################################################################

@test "git-wt works without any hooks installed" {
  # Setup: No hooks directory or files
  rm -rf .git/hooks

  # Run
  run bash "$GIT_WT_SCRIPT" add feature

  # Assert
  assert_success
  [[ -d "feature" ]]
}

@test "git-wt works with hooks directory but no hook files" {
  # Setup: Empty hooks directory
  mkdir -p .git/hooks

  # Run
  run bash "$GIT_WT_SCRIPT" add feature

  # Assert
  assert_success
  [[ -d "feature" ]]
}

@test "git-wt works with non-executable hook files" {
  # Setup: Create hook files but don't make them executable
  mkdir -p .git/hooks
  echo '#!/bin/bash' > .git/hooks/pre-worktree-add
  echo 'exit 1' >> .git/hooks/pre-worktree-add
  # Don't chmod +x

  # Run
  run bash "$GIT_WT_SCRIPT" add feature

  # Assert - should succeed because non-executable hooks are ignored
  assert_success
  [[ -d "feature" ]]
}

################################################################################
# E. Hook Location Tests
################################################################################

@test "hooks work from common git directory in worktrees" {
  # Setup: Create hook in main .git/hooks
  local marker_file="$TEST_TEMP_DIR/.hook-from-worktree"
  mkdir -p .git/hooks
  cat > .git/hooks/pre-worktree-add <<EOF
#!/bin/bash
echo "HOOK_FROM_COMMON_DIR" > "$marker_file"
exit 0
EOF
  chmod +x .git/hooks/pre-worktree-add

  # Create first worktree
  bash "$GIT_WT_SCRIPT" add feature1 >/dev/null 2>&1

  # Run from inside the worktree
  cd feature1
  run bash "$GIT_WT_SCRIPT" add feature2

  # Assert - hook should still work from within worktree
  assert_success
  [[ -f "$marker_file" ]]
}

################################################################################
# F. git-crypt Example Hook Tests
################################################################################

@test "git-crypt pre-hook example is valid bash" {
  # Get the directory containing git-wt script
  local script_dir=$(dirname "$GIT_WT_SCRIPT")

  # Run syntax check on example
  run bash -n "$script_dir/examples/hooks/git-crypt-pre-worktree-add"

  # Assert
  assert_success
}

@test "git-crypt post-hook example is valid bash" {
  # Get the directory containing git-wt script
  local script_dir=$(dirname "$GIT_WT_SCRIPT")

  # Run syntax check on example
  run bash -n "$script_dir/examples/hooks/git-crypt-post-worktree-add"

  # Assert
  assert_success
}

@test "git-crypt hooks exit cleanly when git-crypt is not configured" {
  # Get the directory containing git-wt script
  local script_dir=$(dirname "$GIT_WT_SCRIPT")

  # Setup: Install git-crypt hooks
  mkdir -p .git/hooks
  cp "$script_dir/examples/hooks/git-crypt-pre-worktree-add" .git/hooks/pre-worktree-add
  cp "$script_dir/examples/hooks/git-crypt-post-worktree-add" .git/hooks/post-worktree-add
  chmod +x .git/hooks/pre-worktree-add .git/hooks/post-worktree-add

  # Run (no git-crypt configured)
  run bash "$GIT_WT_SCRIPT" add feature

  # Assert - should succeed because hooks detect no git-crypt and exit cleanly
  assert_success
  [[ -d "feature" ]]
}
