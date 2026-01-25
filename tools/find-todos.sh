#!/bin/bash
# find-todos.sh - Find all TODO/FIXME/HACK comments
# Usage: ./find-todos.sh [--export] [repo-name]

EXPORT=false
REPO=""

for arg in "$@"; do
  case $arg in
    --export)
      EXPORT=true
      shift
      ;;
    *)
      REPO=$arg
      shift
      ;;
  esac
done

if [ -n "$REPO" ]; then
  REPOS=("$REPO")
else
  REPOS=("client-manager" "hazina")
fi

echo "=== TODO TRACKER ==="
echo ""

OUTPUT=""
TOTAL_COUNT=0

for repo in "${REPOS[@]}"; do
  repo_path="/c/Projects/$repo"

  if [ ! -d "$repo_path" ]; then
    continue
  fi

  cd "$repo_path"

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📁 $repo"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Find all TODOs, FIXMEs, HACKs, XXXs
  results=$(grep -rn -E "(TODO|FIXME|HACK|XXX|NOTE)" \
    --include="*.cs" \
    --include="*.ts" \
    --include="*.tsx" \
    --include="*.js" \
    --include="*.jsx" \
    --exclude-dir=node_modules \
    --exclude-dir=bin \
    --exclude-dir=obj \
    --exclude-dir=dist \
    --exclude-dir=.git \
    . 2>/dev/null)

  if [ -z "$results" ]; then
    echo "  ✅ No TODOs found"
    echo ""
    continue
  fi

  # Count by type
  todo_count=$(echo "$results" | grep -c "TODO" || echo 0)
  fixme_count=$(echo "$results" | grep -c "FIXME" || echo 0)
  hack_count=$(echo "$results" | grep -c "HACK" || echo 0)
  xxx_count=$(echo "$results" | grep -c "XXX" || echo 0)
  note_count=$(echo "$results" | grep -c "NOTE" || echo 0)

  total=$((todo_count + fixme_count + hack_count + xxx_count + note_count))
  TOTAL_COUNT=$((TOTAL_COUNT + total))

  echo "  📊 Summary:"
  echo "     TODO:  $todo_count"
  echo "     FIXME: $fixme_count"
  echo "     HACK:  $hack_count"
  echo "     XXX:   $xxx_count"
  echo "     NOTE:  $note_count"
  echo "     ─────────────"
  echo "     TOTAL: $total"
  echo ""

  # Group by file
  echo "  📝 Details:"
  echo ""

  current_file=""
  echo "$results" | while IFS=: read -r file line content; do
    # Clean up file path
    file=$(echo "$file" | sed 's|^\./||')

    if [ "$file" != "$current_file" ]; then
      current_file="$file"
      echo "     $file:"
    fi

    # Extract comment type and message
    comment=$(echo "$content" | sed -E 's/.*\/(\/|\*)\s*(TODO|FIXME|HACK|XXX|NOTE)/\2/')

    # Color code by type
    if echo "$content" | grep -q "FIXME"; then
      marker="🔴 FIXME"
    elif echo "$content" | grep -q "HACK"; then
      marker="⚠️  HACK"
    elif echo "$content" | grep -q "XXX"; then
      marker="❌ XXX"
    elif echo "$content" | grep -q "NOTE"; then
      marker="📝 NOTE"
    else
      marker="📌 TODO"
    fi

    echo "       Line $line: $marker $(echo $content | sed -E 's|.*(//\|/\*)\s*(TODO\|FIXME\|HACK\|XXX\|NOTE)[:\s]*||')"
  done

  echo ""

  # Export to markdown if requested
  if [ "$EXPORT" = true ]; then
    OUTPUT="$OUTPUT\n## $repo\n\n"
    OUTPUT="$OUTPUT**Total:** $total items (TODO: $todo_count, FIXME: $fixme_count, HACK: $hack_count, XXX: $xxx_count, NOTE: $note_count)\n\n"

    echo "$results" | while IFS=: read -r file line content; do
      file=$(echo "$file" | sed 's|^\./||')
      comment=$(echo "$content" | sed -E 's/.*\/[\/\*]\s*(TODO|FIXME|HACK|XXX|NOTE)[:\s]*//')
      OUTPUT="$OUTPUT- **$file:$line** - $comment\n"
    done
    OUTPUT="$OUTPUT\n"
  fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 TOTAL: $TOTAL_COUNT items across all repos"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$EXPORT" = true ]; then
  output_file="/c/scripts/logs/todos-$(date +%Y%m%d-%H%M%S).md"
  echo -e "# TODO Report\n\nGenerated: $(date)\n\n$OUTPUT" > "$output_file"
  echo ""
  echo "📄 Report exported to: $output_file"
fi
