# git-wt
git worktree workflows via a handy alias

git-wt allows you to create a new git alias `git wt` for working with worktrees. It's simple and has two major benefits:

1. Cleaner, short aliases for standard worktree commands.
2. The addition of `git wt clone` for checking out a bare repository with worktree subfolders.

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