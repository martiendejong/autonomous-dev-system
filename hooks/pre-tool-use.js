/**
 * PreToolUse Hook - Zero-Tolerance Enforcement
 *
 * Runs BEFORE any tool executes to enforce development protocols.
 * This prevents violations of the autonomous development system rules.
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

module.exports = async (context) => {
  const { tool, args } = context;

  // Load configuration
  const configPath = getConfigPath();
  if (!fs.existsSync(configPath)) {
    // Configuration not found - plugin not set up yet
    // Allow operation but warn
    console.warn('⚠️  Autonomous Dev System not configured. Run setup.sh first.');
    return;
  }

  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

  // RULE 3: Never edit in base repos directly
  if (tool === 'Edit' || tool === 'Write') {
    const filePath = args.file_path || args.path;

    if (!filePath) {
      return; // No file path to check
    }

    // Normalize path for comparison
    const normalizedPath = path.normalize(filePath).replace(/\\/g, '/');

    // Check if editing in any base repo
    for (const repo of config.repos) {
      const repoPath = path.normalize(repo.path).replace(/\\/g, '/');

      if (normalizedPath.startsWith(repoPath)) {
        // Editing in base repo - check if it's in a worktree
        const worktreePath = path.normalize(config.worktreePath).replace(/\\/g, '/');

        if (!normalizedPath.startsWith(worktreePath)) {
          // VIOLATION: Editing base repo directly!
          throw new Error(`
🚨🚨🚨 ZERO-TOLERANCE VIOLATION 🚨🚨🚨

FORBIDDEN: Editing in base repository directly!

File: ${filePath}
Repo: ${repo.name} (${repo.path})

You MUST:
1. Allocate a worktree first: /worktree:claim <branch> <description>
2. Edit only in: ${config.worktreePath}/agent-XXX/${repo.name}/

HARD STOP RULE 3: Never edit in base repos (${repo.path})
Only edit in allocated worktrees (${config.worktreePath}/agent-XXX/)

Read your zero-tolerance rules for details.
          `);
        }
      }
    }

    // Check if worktree is allocated
    const poolPath = path.join(config.controlPlane, '_machine', 'worktrees.pool.md');

    if (fs.existsSync(poolPath)) {
      const poolContent = fs.readFileSync(poolPath, 'utf8');
      const busyAgents = poolContent
        .split('\n')
        .filter(line => line.includes('| BUSY |'))
        .map(line => {
          const parts = line.split('|').map(p => p.trim());
          return {
            agent: parts[1],
            repo: parts[4]
          };
        });

      if (busyAgents.length === 0) {
        console.warn(`
⚠️  Warning: No worktrees currently allocated (all agents FREE)

If you're starting new work, run:
  /worktree:claim <branch> <description>

If you're in a worktree, the pool may be out of sync.
        `);
      }
    }
  }

  // RULE: Enforce PR base branch verification
  if (tool === 'Bash' && args.command) {
    const cmd = args.command;

    // Check for gh pr create without --base
    if (cmd.includes('gh pr create') && !cmd.includes('--base')) {
      console.warn(`
⚠️  Warning: Creating PR without specifying --base branch

BEST PRACTICE: Always specify base branch explicitly:
  gh pr create --base develop --title "..." --body "..."

Pattern 56: gh CLI defaults to 'main' if not specified!
Verify base after creation: gh pr view <num> --json baseRefName
      `);
    }

    // Check for direct editing in base repos via bash
    for (const repo of config.repos) {
      const repoPath = repo.path.replace(/\\/g, '/');

      if (cmd.includes(`cd ${repoPath}`) || cmd.includes(`cd "${repoPath}"`)) {
        if (cmd.includes('git commit') || cmd.includes('git add')) {
          throw new Error(`
🚨🚨🚨 ZERO-TOLERANCE VIOLATION 🚨🚨🚨

FORBIDDEN: Committing changes in base repository via bash!

Command: ${cmd}
Repo: ${repo.name}

You MUST work in allocated worktrees only.
Base repos (${repoPath}) must remain on ${repo.baseBranch || 'develop'} branch.
          `);
        }
      }
    }
  }
};

/**
 * Get configuration file path based on OS
 */
function getConfigPath() {
  const homeDir = os.homedir();
  const defaultPath = path.join(homeDir, '.autonomous-dev', 'config.json');

  // Check if default exists
  if (fs.existsSync(defaultPath)) {
    return defaultPath;
  }

  // Check environment variable override
  if (process.env.AUTONOMOUS_DEV_CONFIG) {
    return process.env.AUTONOMOUS_DEV_CONFIG;
  }

  return defaultPath;
}
