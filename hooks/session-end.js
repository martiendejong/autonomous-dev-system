/**
 * SessionEnd Hook - Execute at End of Session
 *
 * This hook runs when the user ends the Claude Code session.
 *
 * Use cases:
 * - Verify all agents released (no BUSY agents)
 * - Warn about uncommitted work
 * - Generate session summary
 * - Update activity logs
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

module.exports = async (context) => {
  const { conversation } = context;

  // Load configuration
  const configPath = getConfigPath();
  if (!fs.existsSync(configPath)) {
    // No config = plugin not set up yet, skip
    return;
  }

  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const poolFile = path.join(config.controlPlane, '_machine', 'worktrees.pool.md');

  if (!fs.existsSync(poolFile)) {
    return;
  }

  console.log('');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('SESSION END CHECKLIST');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('');

  // Check 1: BUSY agents
  const poolContent = fs.readFileSync(poolFile, 'utf8');
  const busyAgents = poolContent.split('\n').filter(line => line.includes('| BUSY |'));

  if (busyAgents.length > 0) {
    console.log('❌ BUSY AGENTS FOUND:');
    busyAgents.forEach(line => {
      const parts = line.split('|');
      const agent = parts[1]?.trim();
      const repo = parts[5]?.trim();
      const branch = parts[6]?.trim();
      const desc = parts[8]?.trim();
      console.log(`   ${agent}: ${repo} (${branch})`);
      console.log(`      ${desc}`);
    });
    console.log('');
    console.log('⚠️  CRITICAL: Release ALL agents before ending session!');
    console.log('   Run: /worktree:release <agent-seat> "<pr-title>"');
    console.log('');
  } else {
    console.log('✅ All agents FREE (clean state)');
    console.log('');
  }

  // Check 2: Base repos on correct branch
  console.log('Checking base repositories...');
  let baseBranchIssues = 0;

  for (const repo of config.repos) {
    try {
      const branch = execSync('git branch --show-current', {
        cwd: repo.path,
        encoding: 'utf8'
      }).trim();

      const baseBranch = repo.baseBranch || 'develop';

      if (branch !== baseBranch) {
        console.log(`❌ ${repo.name}: On '${branch}' (should be '${baseBranch}')`);
        baseBranchIssues++;
      } else {
        console.log(`✅ ${repo.name}: On ${baseBranch}`);
      }
    } catch (error) {
      console.log(`⚠️  ${repo.name}: Could not check branch (${error.message})`);
    }
  }

  console.log('');

  if (baseBranchIssues > 0) {
    console.log('⚠️  WARNING: Base repos should be on base branch');
    console.log('   This can cause issues in next session (Pattern 59)');
    console.log('');
  }

  // Check 3: Uncommitted changes in base repos
  console.log('Checking for uncommitted changes...');
  let uncommittedIssues = 0;

  for (const repo of config.repos) {
    try {
      const status = execSync('git status --porcelain', {
        cwd: repo.path,
        encoding: 'utf8'
      });

      if (status.trim()) {
        console.log(`❌ ${repo.name}: Has uncommitted changes`);
        uncommittedIssues++;
      } else {
        console.log(`✅ ${repo.name}: Clean`);
      }
    } catch (error) {
      console.log(`⚠️  ${repo.name}: Could not check status`);
    }
  }

  console.log('');

  // Summary
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  if (busyAgents.length === 0 && baseBranchIssues === 0 && uncommittedIssues === 0) {
    console.log('✅ SESSION CLEAN - Safe to end');
  } else {
    console.log('⚠️  SESSION HAS ISSUES - Review checklist above');
  }

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('');
};

function getConfigPath() {
  if (process.env.AUTONOMOUS_DEV_CONFIG) {
    return process.env.AUTONOMOUS_DEV_CONFIG;
  }

  const homeDir = process.env.HOME || process.env.USERPROFILE;
  return path.join(homeDir, '.autonomous-dev', 'config.json');
}
