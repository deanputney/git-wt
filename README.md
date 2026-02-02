# git-wt

**An opinionated git alias to encourage all work inside worktrees.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A common reaction to discovering git worktrees is "oh my god, why didn't I know about this sooner???" Although the worktree system is incredibly powerful, it is difficult to adopt due to lack of organizational clarity and inconvenient naming.

git-wt aims to solve these problems:

* Where do you put a new worktree when you create one?
* Do you need to add your worktree to .gitignore?
* Why are the `git worktree` commands long and unfamiliar in Unix terms? 

git-wt allows you to create a new git alias `git wt` for working with worktrees. It's simple and has two major benefits:

1. The addition of `git wt clone` for checking out a bare repository with worktree subfolders.
2. Cleaner, short aliases for standard worktree commands. Might as well clean this up too.

## Clone

`git wt` adds an opinionated `clone` feature for organizing a new repository with worktrees. `git wt clone` creates an empty directory for your repository, checks out the `.git` directory inside it, and **leaves the rest of your directory as clean empty space for your worktree directories**.

Compare these two checkouts:

The standard clone for a new repository:

```
~/git-wt-standard $ $ tree -a
.
├── .git
│   ├── config
│   ├── HEAD
│   ├── # ... etc etc
├── git-wt
├── LICENSE
└── README.md
```

With the standard clone the repository code files leave no clear space for your worktrees to go. It also implies getting to work straight away in there, in a way that's not easy to clean up. 

Common locations for worktree directories in this flow are to put them inside the current directory as `worktrees` (requiring .gitignore), as siblings (???), or in a hidden home directory like `~/.worktrees` (creating issues with multiple repositories). These solutions simply create more problems.

Compare to a `git wt clone` clone:

```
~/git-wt-clone $ tree -a
.
├── .git
│   ├── config
│   ├── HEAD
│   ├── # ... etc etc
└── main
    ├── .git
    ├── git-wt
    ├── LICENSE
    └── README.md
```

The `git wt clone` approach puts all work inside a worktree, even `main`. 

* It's clear where new worktrees should be created.
* In progress work is always contained.
* There are no conflicts with other repositories.

The `git` command will continue to behave as normal in each worktree. Simply create a new worktree from the repo root with `git wt add`.


The `git wt clone` approach puts all work inside a worktree, even `main`. It's clear where new worktrees should be created. In progress work is always contained.

### Init

Already have a repository and want to convert it to the worktree structure? `git wt init` will reorganize your existing repository into the same clean structure that `git wt clone` creates.

Running `git wt init` from inside a standard git repository will:

1. Convert your `.git` directory to a bare repository
2. Move your current branch and working files into a worktree subdirectory
3. Automatically create a worktree for the main/master branch
4. Preserve all uncommitted changes, untracked files, and stashes

For example, if you have a standard repository on branch `feature`:

```
~/my-repo $ tree -a -L 1
.
├── .git
├── file1.txt
└── file2.txt
```

After running `git wt init`:

```
~/my-repo $ tree -a -L 1
.
├── .git (now bare)
├── feature
│   ├── .git
│   ├── file1.txt
│   └── file2.txt
└── main
    ├── .git
    └── # files from main branch
```

**Note**: `git wt init` will warn you if you have uncommitted changes or untracked files, and ask for confirmation before proceeding. All your work will be safely preserved in the worktree directory.

## Aliases

These new aliases are added:

```
git wt ls (alias for list)
git wt rm (alias for remove)
git wt a (alias for add)
```

## Hooks

git-wt supports custom hooks for advanced workflows. To install the built-in git-crypt hooks:

```bash
git wt install-hooks git-crypt
```

See [HOOKS.md](HOOKS.md) for more information about creating custom hooks and troubleshooting git-crypt integration.

## Installation

### Homebrew Installation

If you use Homebrew, you can install via a tap:

```bash
brew tap deanputney/tap
brew install git-wt
```

The git alias is configured automatically during installation. Verify it's working:

```bash
git wt --help
```

### Manual Installation

If you prefer to install manually without the setup script:

1. Copy the git-wt script to a directory in your PATH:
```bash
cp git-wt /usr/local/bin/git-wt
chmod +x /usr/local/bin/git-wt
```

2. Configure the git alias:
```bash
git-wt setup --config-only
```

or

```bash
git config --global alias.wt '!git-wt'
```

3. Verify installation:
```bash
git wt --help
```


## Development

### Running Tests

This project uses [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core) for testing.

#### Prerequisites

Install BATS:

```bash
# macOS
brew install bats-core

# Linux (Ubuntu/Debian)
sudo apt-get install bats

# Or install from source
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh /usr/local
```

#### Running Tests

```bash
# Run all tests
bats tests/

# Run specific test file
bats tests/init.bats

# Run tests with verbose output
bats --tap tests/init.bats

# Run specific test by line number
bats tests/init.bats:42
```

#### Test Structure

- `tests/init.bats` - Integration tests for `git wt init` command
- `tests/test_helper/` - Helper functions and libraries
- Tests run in isolated temporary directories
- Each test creates a fresh git repository

#### Writing Tests

When adding new features:
1. Add test cases to appropriate `.bats` file
2. Use helper functions from `test_helpers.bash`
3. Ensure tests clean up properly in `teardown()`
4. Run tests locally before submitting PR

Tests run automatically on all pull requests via GitHub Actions.
