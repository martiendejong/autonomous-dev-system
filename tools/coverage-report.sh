#!/bin/bash
# coverage-report.sh - Generate test coverage reports
# Usage: ./coverage-report.sh [--html] [repo-name]

GENERATE_HTML=false
REPO=""

for arg in "$@"; do
  case $arg in
    --html)
      GENERATE_HTML=true
      shift
      ;;
    *)
      REPO=$arg
      shift
      ;;
  esac
done

echo "=== TEST COVERAGE REPORTER ==="
echo ""

if [ -n "$REPO" ]; then
  REPOS=("$REPO")
else
  REPOS=("client-manager")
fi

LOW_COVERAGE_THRESHOLD=80

for repo in "${REPOS[@]}"; do
  repo_path="/c/Projects/$repo"

  if [ ! -d "$repo_path" ]; then
    continue
  fi

  cd "$repo_path"

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📁 $repo"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Backend coverage (if .NET project exists)
  if [ -f "ClientManagerAPI/ClientManagerAPI.csproj" ] || [ -f "ClientManagerAPI/ClientManagerAPI.local.csproj" ]; then
    echo "🔬 Running backend tests with coverage..."
    echo ""

    # Run tests with coverage
    dotnet test --collect:"XPlat Code Coverage" --verbosity quiet 2>&1 | tail -10

    # Find coverage file
    coverage_file=$(find . -name "coverage.cobertura.xml" | head -1)

    if [ -n "$coverage_file" ]; then
      echo ""
      echo "📊 Backend Coverage Analysis:"
      echo ""

      # Parse coverage (simplified - would need better XML parsing in production)
      overall=$(grep "line-rate" "$coverage_file" | head -1 | sed -E 's/.*line-rate="([0-9.]+)".*/\1/')
      overall_pct=$(echo "$overall * 100" | bc)

      echo "  Overall: ${overall_pct}%"

      if (( $(echo "$overall_pct < $LOW_COVERAGE_THRESHOLD" | bc -l) )); then
        echo "  ⚠️  Below ${LOW_COVERAGE_THRESHOLD}% threshold"
      else
        echo "  ✅ Above ${LOW_COVERAGE_THRESHOLD}% threshold"
      fi

      # Clean up coverage files
      find . -name "coverage.cobertura.xml" -delete
      find . -type d -name "TestResults" -exec rm -rf {} + 2>/dev/null
    else
      echo "  ⚠️  No coverage data generated"
    fi

    echo ""
  fi

  # Frontend coverage (if npm project exists)
  if [ -f "ClientManagerFrontend/package.json" ]; then
    echo "🔬 Running frontend tests with coverage..."
    echo ""

    cd ClientManagerFrontend

    # Run tests with coverage
    npm run test:coverage -- --run 2>&1 | tail -20

    # Check if coverage summary exists
    if [ -f "coverage/coverage-summary.json" ]; then
      echo ""
      echo "📊 Frontend Coverage Analysis:"
      echo ""

      # Parse coverage using jq if available
      if command -v jq &> /dev/null; then
        total=$(jq -r '.total' coverage/coverage-summary.json)
        lines=$(echo "$total" | jq -r '.lines.pct')
        statements=$(echo "$total" | jq -r '.statements.pct')
        functions=$(echo "$total" | jq -r '.functions.pct')
        branches=$(echo "$total" | jq -r '.branches.pct')

        echo "  Lines:      ${lines}%"
        echo "  Statements: ${statements}%"
        echo "  Functions:  ${functions}%"
        echo "  Branches:   ${branches}%"

        if (( $(echo "$lines < $LOW_COVERAGE_THRESHOLD" | bc -l) )); then
          echo ""
          echo "  ⚠️  Line coverage below ${LOW_COVERAGE_THRESHOLD}%"
        else
          echo ""
          echo "  ✅ Coverage above ${LOW_COVERAGE_THRESHOLD}%"
        fi

        # Find low coverage files
        echo ""
        echo "  📉 Low coverage files (<${LOW_COVERAGE_THRESHOLD}%):"
        jq -r 'to_entries[] | select(.key != "total") | select(.value.lines.pct < 80) | "     \(.key): \(.value.lines.pct)%"' coverage/coverage-summary.json | head -10
      fi

      # Generate HTML report if requested
      if [ "$GENERATE_HTML" = true ]; then
        echo ""
        echo "  📄 HTML report: file://$(pwd)/coverage/index.html"
      fi
    fi

    cd ..
    echo ""
  fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Coverage report complete"
echo ""

if [ "$GENERATE_HTML" = false ]; then
  echo "💡 Run with --html to generate HTML reports"
fi
