# Test Suite Documentation

## Overview

Integration tests for git-wt using BATS (Bash Automated Testing System).

## Structure

```
tests/
├── init.bats                    # Tests for git wt init command
├── test_helper/
│   ├── bats-support/           # BATS support library (submodule)
│   ├── bats-assert/            # BATS assertion library (submodule)
│   └── test_helpers.bash       # Custom helper functions
└── fixtures/                   # Test data (if needed)
```

## Test Categories

### A. Pre-flight Validation Tests (6 tests)
Tests that verify the init command correctly rejects invalid repository states:
- Not a git repository
- Already bare repository
- Already in worktree structure
- Existing worktrees present
- Detached HEAD state
- User confirmation abort

### B. Happy Path Tests (8 tests)
Tests for successful conversions in various scenarios:
- Clean repo with main branch
- Clean repo with master branch
- Creating both current branch and main worktrees
- Feature branch without main/master
- Primary branch preference (main over master)
- Success message verification
- Remote fetch refspec configuration
- Local repos without remotes

### C. State Preservation Tests (8 tests)
Tests verifying that all repository state is preserved during conversion:
- Uncommitted changes
- Staged changes
- Untracked files
- Stashes (multiple)
- Mix of staged/unstaged/untracked
- Git configuration
- Large number of files

### D. Edge Cases (6 tests)
Tests for special scenarios and corner cases:
- Branch names with slashes (feature/test-123)
- Long branch names
- Running from subdirectory
- Multiple remotes
- .gitattributes preservation
- Symbolic links

## Helper Functions

All helper functions are defined in `test_helper/test_helpers.bash`.

### Repository Setup
- `setup_test_repo()` - Creates fresh git repo with initial commit
- `create_branch(name)` - Creates and checks out new branch
- `make_repo_bare()` - Converts repo to bare (for error testing)

### State Manipulation
- `add_uncommitted_changes()` - Creates unstaged modifications
- `add_staged_changes()` - Creates staged changes
- `add_untracked_files()` - Creates untracked files
- `create_stash()` - Creates stashed changes
- `detach_head()` - Puts repo in detached HEAD state
- `create_worktree(branch)` - Creates worktree (for error testing)

### Remote Operations
- `create_remote_repo()` - Creates bare repo to act as remote

### Verification
- `verify_worktree_structure(branch)` - Validates post-conversion structure
- `count_worktrees()` - Returns number of worktrees
- `assert_file_exists(path)` - Checks file existence
- `assert_file_contains(path, content)` - Checks file content
- `get_primary_branch()` - Returns main or master, whichever exists

### Global Variables
- `GIT_WT_SCRIPT` - Path to the git-wt script being tested
- `TEST_TEMP_DIR` - Temporary directory for current test

## Running Tests Locally

### Run All Tests
```bash
cd /path/to/git-wt
bats tests/init.bats
```

### Run Specific Test
```bash
# By test name pattern
bats tests/init.bats -f "clean repo with main"

# By line number
bats tests/init.bats:113
```

### Verbose Output
```bash
# TAP format (Test Anything Protocol)
bats --tap tests/init.bats

# Timing information
bats --timing tests/init.bats
```

### Debugging Tests

To debug a failing test:

1. **Add `skip` to temporarily disable other tests:**
   ```bash
   @test "my test" {
     skip "debugging"
     # test code
   }
   ```

2. **Use `echo` for debugging output:**
   ```bash
   echo "Debug: variable=$variable" >&3
   ```

3. **Run with verbose output:**
   ```bash
   bats --tap tests/init.bats
   ```

4. **Manually run test commands:**
   ```bash
   # Create temp dir
   TEST_DIR=$(mktemp -d)
   cd $TEST_DIR

   # Source helpers
   source /path/to/tests/test_helper/test_helpers.bash

   # Run test commands manually
   setup_test_repo
   bash /path/to/git-wt init
   ```

## CI/CD

Tests run automatically on GitHub Actions:
- **Triggers:** Push to main/master/init, all pull requests
- **Platforms:** Ubuntu Linux (latest), macOS (latest)
- **Workflow:** `.github/workflows/test.yml`

Test results appear on:
- Pull request checks
- Commit status badges
- Actions tab in GitHub

## Writing New Tests

### Test Template

```bash
@test "description of what this tests" {
  # Setup: Prepare test environment
  setup_test_repo
  # ... additional setup

  # Run: Execute the command being tested
  run bash "$GIT_WT_SCRIPT" init

  # Assert: Verify expected outcomes
  assert_success
  assert_output --partial "expected text"

  # Additional assertions
  [[ -d "expected-directory" ]]
  [[ -f "expected-file" ]]
}
```

### Best Practices

1. **Isolation:** Each test runs in its own temp directory
2. **Descriptive names:** Test names should explain what they verify
3. **Clear structure:** Use Setup/Run/Assert comments
4. **Helper functions:** Reuse helpers from `test_helpers.bash`
5. **Assertions:** Use bats-assert for clear failure messages
6. **Cleanup:** Temp directories auto-cleanup in `teardown()`

### Example Test

```bash
@test "init converts repo and preserves uncommitted changes" {
  # Setup
  setup_test_repo
  echo "modified" > README.md
  echo "untracked" > new.txt

  # Run
  run bash -c "echo 'Y' | bash '$GIT_WT_SCRIPT' init"

  # Assert
  assert_success

  # Verify structure
  [[ $(git config core.bare) == "true" ]]
  [[ -d "main" ]]

  # Verify changes preserved
  cd main
  grep -q "modified" README.md
  [[ -f "new.txt" ]]
}
```

## Test Naming Conventions

- Use descriptive, complete sentences
- Start with the command: "init ..."
- Describe the scenario and expected outcome
- Examples:
  - "init converts clean repo with main branch successfully"
  - "init fails when repository is already bare"
  - "init preserves uncommitted changes"

## Maintenance

### Updating Tests

When modifying the init command:
1. Update affected tests to match new behavior
2. Add new tests for new features
3. Run full test suite locally
4. Check CI passes on PR

### Adding Test Categories

To add a new test file (e.g., `tests/clone.bats`):
1. Create the new `.bats` file
2. Add same setup/teardown structure
3. Load test helpers
4. Write tests following existing patterns
5. Update `.github/workflows/test.yml` to run new tests

## Troubleshooting

### Tests Fail Locally But Pass in CI
- Check git configuration differences
- Verify BATS version matches CI
- Check for absolute vs relative paths

### Tests Pass Locally But Fail in CI
- Check platform-specific behavior (Linux vs macOS)
- Verify submodules are initialized
- Check for hardcoded paths or assumptions

### Flaky Tests
- Add more specific assertions
- Check for race conditions
- Ensure proper cleanup between tests
- Verify no shared state between tests

## Resources

- [BATS Documentation](https://bats-core.readthedocs.io/)
- [bats-support](https://github.com/bats-core/bats-support)
- [bats-assert](https://github.com/bats-core/bats-assert)
- [git-worktree docs](https://git-scm.com/docs/git-worktree)
