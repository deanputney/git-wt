# This is a template formula. PLACEHOLDER_* values are replaced by GitHub Actions.
# See .github/workflows/update-homebrew-formula.yml for the automation.
class GitWt < Formula
  desc "Enhanced workflows for Git worktrees"
  homepage "https://github.com/deanputney/git-wt"
  url "PLACEHOLDER_URL"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"
  version "PLACEHOLDER_VERSION"

  depends_on "git"

  def install
    bin.install "git-wt"
  end

  def post_install
    # Configure git alias using the built-in setup command
    ohai "Configuring git alias"
    system bin/"git-wt", "setup", "--config-only"
  rescue
    opoo "Could not set git alias automatically"
    ohai "To use git-wt as 'git wt', run:"
    puts "  git-wt setup --config-only"
  end

  def caveats
    <<~EOS
      git-wt has been installed!

      The git alias 'git wt' should be configured automatically.
      If not, you can set it up with:
        git-wt setup --config-only

      Get started:
        git wt --help
        git wt clone <repository-url>

      Reorganize an existing repository with worktrees:
        git wt init
    EOS
  end

  test do
    system "#{bin}/git-wt", "--help"
  end
end
