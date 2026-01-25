#!/bin/bash
# sync-configs.sh - Sync config files from base repos to worktrees
# Usage: ./sync-configs.sh [--dry-run] [agent-seat]

DRY_RUN=false
AGENT=""

for arg in "$@"; do
  case $arg in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      AGENT=$arg
      shift
      ;;
  esac
done

echo "=== CONFIG SYNC TOOL ==="
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "🔍 DRY RUN MODE - No files will be copied"
  echo ""
fi

pool_file="/c/scripts/_machine/worktrees.pool.md"

# Get list of agents to sync
if [ -n "$AGENT" ]; then
  AGENTS=("$AGENT")
else
  # Sync all BUSY agents
  AGENTS=($(grep "| BUSY |" "$pool_file" | cut -d'|' -f2 | xargs))
fi

if [ ${#AGENTS[@]} -eq 0 ]; then
  echo "ℹ️  No agents to sync (all FREE or agent not found)"
  exit 0
fi

SYNCED_COUNT=0
ERROR_COUNT=0

# Config files to sync
CLIENT_MANAGER_CONFIGS=(
  "appsettings.json"
  "appsettings.Development.json"
  ".env"
  "secrets.json"
)

HAZINA_CONFIGS=(
  "appsettings.json"
  ".env"
)

for agent in "${AGENTS[@]}"; do
  echo "━━━ Syncing $agent ━━━"

  agent_path="/c/Projects/worker-agents/$agent"

  if [ ! -d "$agent_path" ]; then
    echo "  ⚠️  Agent directory not found: $agent_path"
    ERROR_COUNT=$((ERROR_COUNT + 1))
    echo ""
    continue
  fi

  # Sync client-manager configs
  if [ -d "$agent_path/client-manager" ]; then
    echo "  📁 client-manager:"

    for config in "${CLIENT_MANAGER_CONFIGS[@]}"; do
      source_file="/c/Projects/client-manager/$config"
      dest_file="$agent_path/client-manager/$config"

      if [ ! -f "$source_file" ]; then
        continue
      fi

      if [ "$DRY_RUN" = true ]; then
        echo "     [DRY RUN] Would copy: $config"
      else
        # Check if file exists and show diff
        if [ -f "$dest_file" ]; then
          if diff -q "$source_file" "$dest_file" > /dev/null; then
            echo "     ✅ $config (already up-to-date)"
          else
            echo "     🔄 $config (updating...)"
            cp "$source_file" "$dest_file"
            SYNCED_COUNT=$((SYNCED_COUNT + 1))
          fi
        else
          echo "     ➕ $config (new file)"
          cp "$source_file" "$dest_file"
          SYNCED_COUNT=$((SYNCED_COUNT + 1))
        fi
      fi
    done
  fi

  # Sync hazina configs
  if [ -d "$agent_path/hazina" ]; then
    echo "  📁 hazina:"

    for config in "${HAZINA_CONFIGS[@]}"; do
      source_file="/c/Projects/hazina/$config"
      dest_file="$agent_path/hazina/$config"

      if [ ! -f "$source_file" ]; then
        continue
      fi

      if [ "$DRY_RUN" = true ]; then
        echo "     [DRY RUN] Would copy: $config"
      else
        if [ -f "$dest_file" ]; then
          if diff -q "$source_file" "$dest_file" > /dev/null; then
            echo "     ✅ $config (already up-to-date)"
          else
            echo "     🔄 $config (updating...)"
            cp "$source_file" "$dest_file"
            SYNCED_COUNT=$((SYNCED_COUNT + 1))
          fi
        else
          echo "     ➕ $config (new file)"
          cp "$source_file" "$dest_file"
          SYNCED_COUNT=$((SYNCED_COUNT + 1))
        fi
      fi
    done
  fi

  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$DRY_RUN" = true ]; then
  echo "💡 Run without --dry-run to sync files"
else
  echo "✅ Sync complete!"
  echo "   Files synced: $SYNCED_COUNT"
  echo "   Errors: $ERROR_COUNT"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
