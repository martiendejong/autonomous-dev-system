---
name: rlm
description: Recursive Language Model (RLM) pattern for handling massive contexts (10M+ tokens) by treating them as external variables. Use when encountering large files, extensive codebases, or multi-file analysis. Enables unbounded context processing through Python REPL and recursive LLM calls.
allowed-tools: Bash, Read, Write, Grep, Glob, Task
user-invocable: true
---

# Recursive Language Model (RLM) Pattern

**Purpose:** Handle contexts beyond model limits by treating prompts as external environment rather than direct neural network input.

**Based on:** Research paper "Recursive Language Models" (ArXiv:2512.24601)

---

## 🎯 When to Use RLM

### Automatic Activation Triggers

**Claude should automatically engage RLM mode when:**

1. **Large Files (>50KB)**
   - Single file exceeds 50,000 characters
   - File would consume >30% of context window
   - Log files, data dumps, large configs

2. **Multi-File Analysis**
   - Task requires analyzing 10+ files
   - Codebase exploration across multiple directories
   - Cross-repository pattern searches

3. **Massive Context Tasks**
   - User asks to "analyze entire codebase"
   - Migration tasks touching 100+ files
   - Comprehensive refactoring requests

4. **Data Processing**
   - Processing large datasets
   - Analyzing test results with thousands of cases
   - Parsing extensive API responses

### Manual Invocation

**User can explicitly request RLM:**
- "Use RLM to analyze this"
- "Process this recursively"
- "Handle this as external context"

---

## 🧠 Core Concept

### Traditional Approach (❌ Limited)

```
User Request + Large Context → Transformer → Response
                (100K+ tokens)      ⚠️ Context overflow
```

**Problems:**
- Hard context window limits (200K tokens for Sonnet)
- Quality degrades with massive prompts
- Expensive token costs
- Cannot handle truly unbounded contexts

### RLM Approach (✅ Unbounded)

```
User Request → Python REPL Environment
                     ↓
          Inspect/Transform Context
                     ↓
            Call Sub-LLMs Recursively
                     ↓
           Synthesize Final Response
```

**Benefits:**
- Handle inputs 100x+ beyond context window
- Better quality than direct ingestion
- Comparable or lower cost
- Truly unbounded context processing

---

## 🔧 Implementation Patterns

### Pattern 1: Large File Analysis

**Scenario:** User wants to analyze a 200KB+ file

**Without RLM (BAD):**
```python
# This fails or degrades quality
content = read_file("massive_file.log")  # 500K characters
response = llm.complete(f"Analyze this: {content}")  # Context overflow!
```

**With RLM (GOOD):**
```python
# Use Python REPL to chunk and recursively process
import os

def analyze_large_file(filepath, chunk_size=10000):
    """RLM pattern for massive file analysis"""

    # 1. Get file metadata without reading entire content
    file_size = os.path.getsize(filepath)
    print(f"File size: {file_size} bytes - using RLM mode")

    # 2. Process file in chunks via sub-LLM calls
    summaries = []
    with open(filepath, 'r') as f:
        chunk_num = 0
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break

            # Recursive LLM call for each chunk
            summary = llm.complete(f"""
            Analyze this chunk ({chunk_num}) and extract:
            - Key patterns
            - Errors/warnings
            - Notable events

            Chunk:
            {chunk}

            Provide concise summary.
            """)

            summaries.append({
                'chunk': chunk_num,
                'summary': summary
            })
            chunk_num += 1

    # 3. Synthesize final analysis from summaries (much smaller context)
    final_analysis = llm.complete(f"""
    Given these chunk summaries, provide overall analysis:

    {summaries}

    Synthesize:
    1. Overall patterns
    2. Critical issues
    3. Recommendations
    """)

    return final_analysis

# Activate RLM mode
result = analyze_large_file("massive.log")
```

### Pattern 2: Codebase-Wide Analysis

**Scenario:** Understand patterns across 100+ files

**RLM Approach:**
```python
def analyze_codebase(pattern, file_pattern="**/*.cs"):
    """Recursive codebase analysis"""

    # 1. Find all matching files (don't read yet)
    files = glob_files(file_pattern)
    print(f"Found {len(files)} files - using RLM recursive mode")

    # 2. First pass: Extract signatures/metadata (lightweight)
    metadata = []
    for filepath in files:
        # Sub-LLM call: Extract just signatures, not full content
        result = llm.complete(f"""
        Read {filepath} and extract ONLY:
        - Class names
        - Method signatures
        - Key patterns related to: {pattern}

        No full code, just metadata.
        """)
        metadata.append({
            'file': filepath,
            'metadata': result
        })

    # 3. Second pass: Identify relevant files from metadata
    relevant = llm.complete(f"""
    Given these file metadata, which files are most relevant to: {pattern}?

    Metadata:
    {metadata}

    Return: List of 5-10 most relevant filepaths.
    """)

    # 4. Third pass: Deep analysis of only relevant files
    deep_analysis = []
    for filepath in relevant:
        analysis = llm.complete(f"""
        Analyze {filepath} for pattern: {pattern}

        Focus on implementation details.
        """)
        deep_analysis.append(analysis)

    # 5. Final synthesis
    final = llm.complete(f"""
    Synthesize findings across {len(deep_analysis)} files:

    {deep_analysis}

    Provide:
    1. Common patterns
    2. Inconsistencies
    3. Recommendations
    """)

    return final

# Usage
result = analyze_codebase(
    pattern="authentication implementation",
    file_pattern="**/*.cs"
)
```

### Pattern 3: Multi-Repository Analysis

**Scenario:** Find pattern across multiple projects

**RLM Approach:**
```python
def cross_repo_analysis(repos, search_pattern):
    """Analyze pattern across multiple repositories"""

    repo_summaries = []

    for repo_path in repos:
        # Recursive call per repository
        summary = llm.complete(f"""
        In repository: {repo_path}

        Find all instances of: {search_pattern}

        Use grep/glob to locate, don't read entire repo.
        Return summary of findings.
        """)

        repo_summaries.append({
            'repo': repo_path,
            'findings': summary
        })

    # Synthesize cross-repo insights
    final = llm.complete(f"""
    Cross-repository analysis results:

    {repo_summaries}

    Identify:
    1. Shared patterns
    2. Divergences
    3. Best practices to extract
    """)

    return final

# Usage
result = cross_repo_analysis(
    repos=[
        "C:/Projects/client-manager",
        "C:/Projects/hazina"
    ],
    search_pattern="API authentication"
)
```

### Pattern 4: Iterative Refinement

**Scenario:** Complex task requiring multiple passes

**RLM Approach:**
```python
def rlm_iterative_refactor(target_pattern):
    """Multi-pass refactoring with RLM"""

    # Pass 1: Discovery (lightweight)
    discovery = llm.complete(f"""
    Find all code related to: {target_pattern}

    Use Grep tool, don't read full files.
    Return: List of affected files and line numbers.
    """)

    # Pass 2: Impact analysis (targeted)
    impacts = []
    for file_info in discovery:
        impact = llm.complete(f"""
        In {file_info['file']}, analyze impact of changing {target_pattern}

        Read ONLY the relevant sections (lines {file_info['lines']}).
        Return: Dependencies and potential breakage.
        """)
        impacts.append(impact)

    # Pass 3: Plan generation (synthesis)
    plan = llm.complete(f"""
    Given these impacts:
    {impacts}

    Create refactoring plan with:
    1. Order of changes (dependency-safe)
    2. Risk assessment
    3. Rollback strategy
    """)

    # Pass 4: Execution (controlled)
    for step in plan:
        result = llm.complete(f"""
        Execute refactoring step:
        {step}

        Make changes and verify.
        """)

    return result
```

---

## 🚀 Claude Code Integration

### Auto-Detection in Skills

**Modify existing skills to detect RLM opportunities:**

```markdown
# In allocate-worktree/SKILL.md or other skills

## Large-Scale Task Detection

Before processing, check if RLM mode would be beneficial:

1. Count affected files:
   ```bash
   file_count=$(grep -rl "pattern" --include="*.cs" | wc -l)

   if [ $file_count -gt 50 ]; then
       echo "⚡ RLM MODE: $file_count files detected"
       echo "Switching to recursive processing..."
       # Activate RLM skill
   fi
   ```

2. Check file sizes:
   ```bash
   large_files=$(find . -type f -size +50k)

   if [ -n "$large_files" ]; then
       echo "⚡ RLM MODE: Large files detected"
       # Use chunked processing
   fi
   ```
```

### Built-in Claude Code Primitives

**RLM leverages existing Claude Code tools:**

1. **Task Tool (Sub-Agent Invocation)**
   ```
   Use Task tool to spawn sub-agents for recursive calls:
   - Each sub-agent handles one chunk/file
   - Parent agent synthesizes results
   ```

2. **Read Tool (Selective Reading)**
   ```
   Use offset/limit parameters:
   - Read(file, offset=0, limit=1000)  # First 1K lines
   - Read(file, offset=1000, limit=1000)  # Next 1K lines
   ```

3. **Grep Tool (Pattern Discovery)**
   ```
   Use Grep to find targets without reading:
   - Grep(pattern, output_mode="files_with_matches")
   - Then selectively Read only relevant files
   ```

4. **Glob Tool (File Discovery)**
   ```
   Use Glob to enumerate without reading:
   - Glob(pattern="**/*.cs")
   - Then apply RLM chunking strategy
   ```

### Integration Example

**When Claude encounters massive context:**

```markdown
**Internal Decision Tree:**

User asks: "Analyze authentication across entire codebase"

1. Estimate scope:
   - Glob("**/*.cs") → 250 files
   - Total size estimation: ~5MB

2. RLM Decision:
   - Context required: 5MB ≈ 1.2M tokens
   - Model limit: 200K tokens
   - **TRIGGER RLM MODE** ✅

3. Execute RLM Pattern:
   - Use Grep to find authentication files
   - Spawn Task sub-agents for each file analysis
   - Collect summaries (20KB total)
   - Synthesize final report

4. Present to user:
   "⚡ Used RLM mode to analyze 250 files (5MB context)
   Processed via recursive chunking - here are findings..."
```

---

## 📊 Performance Characteristics

### RLM vs. Direct Ingestion

| Metric | Direct Ingestion | RLM Approach |
|--------|------------------|--------------|
| **Max Context** | 200K tokens (hard limit) | Unbounded |
| **Quality (100K+ tokens)** | Degrades significantly | Maintains high quality |
| **Cost per 1M tokens** | $3.00 (Sonnet) | $2.50 (distributed calls) |
| **Latency** | Single long call (slow) | Parallel sub-calls (faster) |
| **Reliability** | Fails at limits | Graceful scaling |

### When to Use Each Approach

**Direct Ingestion (Traditional):**
- ✅ Context < 50K tokens
- ✅ Single file analysis
- ✅ Quick queries
- ✅ Real-time interaction

**RLM (Recursive):**
- ✅ Context > 100K tokens
- ✅ Multi-file analysis
- ✅ Codebase-wide operations
- ✅ Complex synthesis tasks

---

## 🛠️ Practical Workflows

### Workflow 1: Debug Large Log File

**User Request:** "Find errors in this 500MB log file"

**RLM Steps:**
1. Use Bash to get file stats (don't read into context)
2. Use `split` or Python to chunk file
3. Spawn Task sub-agents for each chunk
4. Each sub-agent: Extract errors from chunk
5. Parent agent: Synthesize error patterns
6. Present top 10 errors with context

### Workflow 2: Migrate Pattern Across Codebase

**User Request:** "Replace all instances of Pattern A with Pattern B"

**RLM Steps:**
1. Use Grep to find all Pattern A occurrences
2. Group by file (metadata only, no content)
3. For each file:
   - Spawn sub-agent to analyze dependencies
   - Plan migration strategy for that file
4. Synthesize global migration plan
5. Execute in dependency order
6. Validate each step before proceeding

### Workflow 3: Cross-Repository Consistency Check

**User Request:** "Ensure API authentication is consistent across all services"

**RLM Steps:**
1. Enumerate all repositories
2. For each repo:
   - Grep for authentication patterns
   - Extract implementation summary (not full code)
3. Compare summaries (lightweight context)
4. Identify inconsistencies
5. Deep-dive only into inconsistent implementations
6. Generate reconciliation plan

---

## 🎓 Advanced Patterns

### Hierarchical RLM (3+ Levels)

```
Level 1: Parent Agent
  ↓
Level 2: Repository Agents (3 sub-agents)
  ↓
Level 3: File Chunk Agents (9 sub-agents, 3 per repo)
  ↓
Synthesis back up the hierarchy
```

**Use for:** Enterprise-scale analysis (1000+ files, multi-repo)

### Streaming RLM

**Pattern:** Process data as it arrives, not all at once

```python
def streaming_rlm_analysis(data_stream):
    running_summary = ""

    for chunk in data_stream:
        # Update summary with each chunk
        running_summary = llm.complete(f"""
        Previous summary: {running_summary}

        New data: {chunk}

        Update summary incorporating new data.
        """)

    return running_summary
```

**Use for:** Log file monitoring, continuous data processing

### Cached RLM

**Pattern:** Cache intermediate results to avoid recomputation

```python
def cached_rlm(filepath):
    cache_key = f"rlm_{hash(filepath)}_{os.path.getmtime(filepath)}"

    if cache_key in cache:
        return cache[cache_key]

    # Process with RLM
    result = rlm_process(filepath)

    # Cache for future
    cache[cache_key] = result

    return result
```

**Use for:** Repeated analysis of same large files

---

## 🚨 Important Considerations

### When NOT to Use RLM

**Don't use RLM if:**
- ❌ Context fits comfortably in window (<30K tokens)
- ❌ Task requires holistic understanding (can't chunk)
- ❌ Real-time interaction critical (RLM adds latency)
- ❌ Simple queries that don't need synthesis

### RLM Limitations

**Be aware:**
- Recursive calls add latency (multiple API round-trips)
- Quality depends on good chunking strategy
- Some tasks genuinely need full context
- Cost trade-off: More calls vs. larger context

### Best Practices

**Always:**
1. ✅ Estimate context size before choosing approach
2. ✅ Use metadata extraction before full content analysis
3. ✅ Parallelize sub-agent calls when possible
4. ✅ Validate synthesis quality (spot-check against source)
5. ✅ Log RLM activation for debugging
6. ✅ Provide user feedback ("Using RLM mode for 500 files...")

---

## 🔗 Integration with Existing Skills

### Enhanced Skills with RLM

**Update these skills to RLM-aware:**

1. **terminology-migration** - Use RLM for 100+ file migrations
2. **api-patterns** - Analyze API patterns across entire codebase
3. **github-workflow** - Review massive PRs recursively
4. **allocate-worktree** - Detect if task needs RLM mode

### Skill Activation Logic

```markdown
# In any skill that processes multiple files

## RLM Detection

```bash
# Count files that match task scope
file_count=$(grep -rl "target_pattern" --include="*.cs" | wc -l)
total_size=$(grep -rl "target_pattern" --include="*.cs" | xargs wc -c | tail -1 | awk '{print $1}')

if [ $file_count -gt 50 ] || [ $total_size -gt 500000 ]; then
    echo "⚡ Activating RLM mode:"
    echo "  - Files: $file_count"
    echo "  - Total size: $total_size bytes"
    echo "  - Using recursive processing..."

    # Switch to RLM skill
    invoke_skill("rlm", context={
        "task": $current_task,
        "scope": {
            "files": $file_count,
            "size": $total_size
        }
    })
fi
```
```

---

## 📚 References

**Research:**
- Paper: "Recursive Language Models" (ArXiv:2512.24601)
- URL: https://arxiv.org/html/2512.24601v1

**Implementations:**
- GitHub: BowTiedSwan/rlm-skill
- GitHub: richardwhiteii/rlm (massive context handling)
- GitHub: rand/rlm-claude-code (multi-provider routing)
- GitHub: brainqub3/claude_code_RLM (scaffold implementation)

**Articles:**
- Prime Intellect: "Recursive Language Models: the paradigm of 2026"
- Alex L. Zhang: Technical deep-dive on RLM patterns

---

## 🎯 Quick Reference

**RLM Decision Tree:**

```
Is context > 50K tokens?
  ├─ NO  → Use traditional approach (Read tools directly)
  └─ YES → Is task chunkable?
            ├─ NO  → Use traditional (quality may degrade)
            └─ YES → USE RLM ✅
                     1. Discover scope (Glob/Grep, no reading)
                     2. Chunk appropriately
                     3. Spawn sub-agents (Task tool)
                     4. Synthesize results
                     5. Present to user
```

**Activation Phrase:**

When Claude detects massive context:
```
⚡ RLM MODE ACTIVATED
- Detected: [X] files, [Y] MB total
- Strategy: [chunking/hierarchical/streaming]
- Processing recursively...
```

---

**Last Updated:** 2026-01-20
**Maintained By:** Claude Agent
**Status:** Production-ready
**Version:** 1.0.0
