/**
 * PreCompact Hook - Execute Before Conversation Compaction
 *
 * This hook runs when Claude Code is about to compact/summarize
 * the conversation due to context limits.
 *
 * Use cases:
 * - Warn if worktree is BUSY (user should release first)
 * - Remind to commit unsaved work
 * - Save critical state to files
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

  // Check for BUSY agents
  const poolContent = fs.readFileSync(poolFile, 'utf8');
  const busyAgents = poolContent.split('\n').filter(line => line.includes('| BUSY |'));

  if (busyAgents.length > 0) {
    console.warn('⚠️  WARNING: Conversation compaction imminent!');
    console.warn('');
    console.warn(`You have ${busyAgents.length} BUSY agent(s):`);
    busyAgents.forEach(line => {
      const parts = line.split('|');
      const agent = parts[1]?.trim();
      const repo = parts[5]?.trim();
      const branch = parts[6]?.trim();
      console.warn(`  - ${agent}: ${repo} (${branch})`);
    });
    console.warn('');
    console.warn('RECOMMENDED: Release agents before compaction to avoid losing context');
    console.warn('Run: /worktree:release <agent-seat> "<pr-title>"');
    console.warn('');
  }

  // Check for uncommitted changes in worktrees
  const worktreePath = config.worktreePath;
  if (fs.existsSync(worktreePath)) {
    const agents = fs.readdirSync(worktreePath).filter(name => name.startsWith('agent-'));

    for (const agent of agents) {
      const agentDir = path.join(worktreePath, agent);
      const repos = fs.readdirSync(agentDir).filter(name => {
        const fullPath = path.join(agentDir, name);
        return fs.statSync(fullPath).isDirectory() && fs.existsSync(path.join(fullPath, '.git'));
      });

      for (const repo of repos) {
        const repoPath = path.join(agentDir, repo);
        try {
          const status = execSync('git status --porcelain', { cwd: repoPath, encoding: 'utf8' });
          if (status.trim()) {
            console.warn(`⚠️  ${agent}/${repo} has uncommitted changes!`);
            console.warn('   Commit before compaction to preserve work');
          }
        } catch (error) {
          // Ignore git errors
        }
      }
    }
  }
};

function getConfigPath() {
  if (process.env.AUTONOMOUS_DEV_CONFIG) {
    return process.env.AUTONOMOUS_DEV_CONFIG;
  }

  const homeDir = process.env.HOME || process.env.USERPROFILE;
  return path.join(homeDir, '.autonomous-dev', 'config.json');
}
