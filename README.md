# git-wt
git worktree workflows via a handy alias

git-wt allows you to create a new git alias `git wt` for working with worktrees. It's simple and has two major benefits:

1. Cleaner, short aliases for standard worktree commands.
2. The addition of `git wt clone` for checking out a bare repository with worktree subfolders.

## Installation

### Quick Start

The easiest way to get started is to clone this repository and run the setup script:

```bash
git clone https://github.com/deanputney/git-wt.git
cd git-wt
./git-wt setup
```

The setup script will:
- Install git-wt to /usr/local/bin (or ~/bin if you don't have write access)
- Configure the git alias: `git config --global alias.wt '!git-wt'`
- Check for optional dependencies (git-crypt)

After setup, you can use `git wt` from anywhere.

### Homebrew Installation

If you use Homebrew, you can install via a tap:

```bash
brew tap deanputney/tap
brew install git-wt
```

Then run the setup to configure the git alias:

```bash
git-wt setup
```

For more information about Homebrew taps and creating your own, see [HOMEBREW.md](HOMEBREW.md).

### Manual Installation

If you prefer to install manually without the setup script:

1. Copy the git-wt script to a directory in your PATH:
   ```bash
   cp git-wt /usr/local/bin/git-wt
   chmod +x /usr/local/bin/git-wt
   ```

2. Configure the git alias:
   ```bash
   git config --global alias.wt '!git-wt'
   ```

3. Verify installation:
   ```bash
   git wt --help
   ```

## Usage

### Aliases

These new aliases are added:

```
git wt ls (alias for list)
git wt rm (alias for remove)
git wt a (alias for add)
```

### Clone

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

A `git wt clone` clone:

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

With the standard clone the repository code files leave no clear space for your worktrees to go. It also implies getting to work straight away in there, in a way that's not easy to clean up.

The `git wt clone` approach puts all work inside a worktree, even `main`. It's clear where new worktrees should be created. In progress work is always contained.