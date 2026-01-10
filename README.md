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

Compare these two checkouts.

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


## Aliases

These new aliases are added:

```
git wt ls (alias for list)
git wt rm (alias for remove)
git wt a (alias for add)
```
