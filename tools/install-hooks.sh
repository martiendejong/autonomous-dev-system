#!/bin/bash
# install-hooks.sh - Install pre-commit hooks in repos
# Usage: ./install-hooks.sh [repo-name]

REPO="$1"

if [ -n "$REPO" ]; then
  REPOS=("$REPO")
else
  REPOS=("client-manager" "hazina")
fi

echo "=== PRE-COMMIT HOOK INSTALLER ==="
echo ""

for repo in "${REPOS[@]}"; do
  echo "━━━ Installing hooks for $repo ━━━"

  repo_path="/c/Projects/$repo"
  hook_path="$repo_path/.git/hooks/pre-commit"

  if [ ! -d "$repo_path/.git" ]; then
    echo "  ❌ Not a git repository: $repo_path"
    continue
  fi

  # Create pre-commit hook
  cat > "$hook_path" << 'HOOK_EOF'
#!/bin/bash
# Pre-commit hook - Auto-installed by install-hooks.sh

echo "🔍 Running pre-commit checks..."

# Get current branch
branch=$(git branch --show-current)

# Check 1: Validate branch name
if ! echo "$branch" | grep -qE "^(feature|fix|docs|test|chore|hotfix)/"; then
  echo "❌ Invalid branch name: $branch"
  echo "   Branch must start with: feature/, fix/, docs/, test/, chore/, or hotfix/"
  echo ""
  echo "   Fix: Rename your branch"
  echo "   git branch -m $branch feature/$(echo $branch | sed 's/[^a-zA-Z0-9-]/-/g')"
  exit 1
fi

# Check 2: Merge conflict markers
if git diff --cached | grep -qE "^(<<<<<<<|=======|>>>>>>>)"; then
  echo "❌ Merge conflict markers detected in staged files"
  echo "   Please resolve conflicts before committing"
  exit 1
fi

# Check 3: Debugger statements (frontend)
if git diff --cached --name-only | grep -qE "\.(ts|tsx|js|jsx)$"; then
  if git diff --cached | grep -E "^\+.*console\.log\("; then
    echo "⚠️  Warning: console.log() detected in staged files"
    echo "   Consider removing debug statements before committing"
    echo ""
    read -p "   Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      exit 1
    fi
  fi

  if git diff --cached | grep -E "^\+.*debugger"; then
    echo "❌ debugger statement detected - please remove"
    exit 1
  fi
fi

# Check 4: Large files (>5MB)
large_files=$(git diff --cached --name-only | while read file; do
  if [ -f "$file" ]; then
    size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
    if [ $size -gt 5242880 ]; then
      echo "$file ($(numfmt --to=iec-i --suffix=B $size))"
    fi
  fi
done)

if [ -n "$large_files" ]; then
  echo "⚠️  Warning: Large files detected:"
  echo "$large_files" | sed 's/^/   /'
  echo ""
  read -p "   Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Check 5: TODO/FIXME without ticket reference
if git diff --cached | grep -E "^\+.*(TODO|FIXME)" | grep -vE "#[0-9]+"; then
  echo "⚠️  Warning: TODO/FIXME without issue reference detected"
  echo "   Consider adding issue number: TODO(#123): description"
  echo ""
fi

echo "✅ Pre-commit checks passed"
exit 0
HOOK_EOF

  # Make hook executable
  chmod +x "$hook_path"

  echo "  ✅ Hook installed: $hook_path"
  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Pre-commit hooks installed successfully"
echo ""
echo "📝 The hooks will check for:"
echo "   • Valid branch names (feature/, fix/, etc.)"
echo "   • Merge conflict markers"
echo "   • console.log and debugger statements"
echo "   • Large files (>5MB)"
echo "   • TODO/FIXME without issue references"
echo ""
echo "💡 To skip hooks temporarily: git commit --no-verify"
echo "🗑️  To uninstall: rm .git/hooks/pre-commit"
