# Information Compression for LLM Requests

## Status: ✅ IMPLEMENTED (Phase 1)

**Implementation Date**: 2026-01-07
**Location**: `C:\Projects\hazina\src\Tools\Foundation\Hazina.Tools.ContextCompression`
**Branch**: `agent-002-context-compression`

## Overview
Implement multi-strategy information compression to optimize context sent to LLMs, reducing token usage while maintaining code understanding.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Compression Pipeline                    │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  Source Files ──┬──> AST Parser ──> Symbol Extractor    │
│                 │                                         │
│                 ├──> Diff Analyzer ──> Context Builder   │
│                 │                                         │
│                 ├──> Semantic Chunker ──> Relevance      │
│                 │                          Filter         │
│                 │                                         │
│                 └──> Template Reducer ──> Deduplicator   │
│                                                           │
│                          ↓                                │
│                                                           │
│                  Compression Manager                      │
│                  (Strategy Selector)                      │
│                          ↓                                │
│                                                           │
│                  Compressed Context                       │
│                  (Ready for LLM)                          │
└─────────────────────────────────────────────────────────┘
```

## Compression Strategies

### Strategy 1: AST-Based Summarization
**Purpose**: Extract code structure without implementation details

**Implementation**:
- Use Roslyn for C#, Babel/TypeScript parser for JS/TS
- Extract:
  - Class/interface definitions
  - Method signatures (not bodies)
  - Public properties
  - XML documentation comments
  - Attributes/decorators

**Example**:
```csharp
// Original (500 tokens)
public class UserService {
    private readonly IUserRepository _repo;
    public UserService(IUserRepository repo) {
        _repo = repo;
    }

    public async Task<User> GetUserAsync(int id) {
        var user = await _repo.FindByIdAsync(id);
        if (user == null) throw new NotFoundException();
        return user;
    }
}

// Compressed (100 tokens)
class UserService {
    UserService(IUserRepository)
    Task<User> GetUserAsync(int id)
}
```

### Strategy 2: Diff-Based Context
**Purpose**: Send only changed code with minimal context

**Implementation**:
- Git diff parsing
- Extract hunks with ±5 line context
- Include file metadata (path, change type)
- Omit unchanged files entirely

**Token Savings**: 70-90% for incremental changes

### Strategy 3: Symbol Indexing
**Purpose**: Reference code locations instead of duplicating code

**Implementation**:
```json
{
  "symbols": {
    "UserService": "Services/UserService.cs:15",
    "IUserRepository": "Repositories/IUserRepository.cs:8"
  },
  "context": [
    "UserService uses IUserRepository (see Services/UserService.cs:15)",
    "Error occurs when calling GetUserAsync"
  ]
}
```

**Token Savings**: 40-60% when referencing multiple times

### Strategy 4: Semantic Chunking
**Purpose**: Send only relevant code sections

**Implementation**:
- Split files into logical units (methods, classes)
- Score chunks by relevance to query
- Include only top N chunks
- Use embeddings for similarity matching

**Relevance Scoring**:
```
score =
  0.4 × keyword_match +
  0.3 × embedding_similarity +
  0.2 × call_graph_proximity +
  0.1 × recency_factor
```

### Strategy 5: Template Reduction
**Purpose**: Remove boilerplate and repeated patterns

**Implementation**:
- Detect common patterns (CRUD operations, constructors)
- Replace with templates: `<CRUD_PATTERN userId>`
- Compress repeated error handling
- Deduplicate similar functions

**Example**:
```
// 5 similar CRUD methods (2000 tokens)
CreateUser, UpdateUser, DeleteUser, GetUser, ListUsers

// Compressed (300 tokens)
<CRUD_OPERATIONS entity="User" operations="CRUDE" />
+ unique business logic only
```

### Strategy 6: Hierarchical Context
**Purpose**: Provide overview before details

**Implementation**:
```
Level 1: Project structure (file tree)
├── Services/
│   ├── UserService.cs
│   └── AuthService.cs
└── Repositories/
    └── UserRepository.cs

Level 2: File summaries (per relevant file)
UserService.cs: 3 classes, 12 methods, handles user CRUD

Level 3: Detailed code (only for specific query)
UserService.GetUserAsync implementation
```

## Compression Module Design

### Core Components

#### 1. `IContextCompressor` Interface
```csharp
public interface IContextCompressor {
    Task<CompressedContext> CompressAsync(
        CompressionRequest request,
        CompressionOptions options
    );
}

public class CompressionRequest {
    public List<string> FilePaths { get; set; }
    public string Query { get; set; }
    public CompressionStrategy Strategy { get; set; }
    public int MaxTokens { get; set; }
}

public class CompressedContext {
    public string Content { get; set; }
    public int OriginalTokens { get; set; }
    public int CompressedTokens { get; set; }
    public double CompressionRatio { get; set; }
    public Dictionary<string, object> Metadata { get; set; }
}
```

#### 2. Strategy Implementations

```csharp
public class AstCompressor : IContextCompressor { }
public class DiffCompressor : IContextCompressor { }
public class SymbolIndexCompressor : IContextCompressor { }
public class SemanticChunker : IContextCompressor { }
public class TemplateReducer : IContextCompressor { }
```

#### 3. Compression Manager

```csharp
public class CompressionManager {
    private readonly Dictionary<CompressionStrategy, IContextCompressor> _compressors;

    public async Task<CompressedContext> CompressAsync(
        CompressionRequest request
    ) {
        // Auto-select best strategy based on:
        // - File types
        // - Change magnitude
        // - Query type
        // - Available token budget

        var strategy = SelectStrategy(request);
        var compressor = _compressors[strategy];
        return await compressor.CompressAsync(request);
    }
}
```

## Implementation Phases

### Phase 1: Foundation (Week 1)
- [ ] Create compression module structure
- [ ] Implement token counting utility
- [ ] Build AST parser for C# (Roslyn)
- [ ] Build AST parser for JS/TS (TypeScript Compiler API)
- [ ] Create base interfaces and models

### Phase 2: Core Strategies (Week 2)
- [ ] Implement AST-based summarization
- [ ] Implement diff-based compression
- [ ] Implement symbol indexing
- [ ] Add compression metrics/telemetry

### Phase 3: Advanced Features (Week 3)
- [ ] Implement semantic chunking
- [ ] Add embedding-based relevance scoring
- [ ] Implement template reduction
- [ ] Build strategy auto-selection

### Phase 4: Integration (Week 4)
- [ ] Integrate with LLM request pipeline
- [ ] Add caching layer for symbols/indexes
- [ ] Create CLI tool for testing compression
- [ ] Write documentation and examples

## Token Counting

Use tiktoken (OpenAI's tokenizer) or similar:

```csharp
public class TokenCounter {
    private readonly TiktokenTokenizer _tokenizer;

    public int Count(string text) {
        return _tokenizer.Encode(text).Count;
    }

    public string Truncate(string text, int maxTokens) {
        var tokens = _tokenizer.Encode(text);
        if (tokens.Count <= maxTokens) return text;
        return _tokenizer.Decode(tokens.Take(maxTokens).ToList());
    }
}
```

## Strategy Selection Logic

```csharp
public CompressionStrategy SelectStrategy(CompressionRequest request) {
    // Single file edit -> Diff-based
    if (IsSingleFileChange(request)) {
        return CompressionStrategy.Diff;
    }

    // Architecture question -> AST + Symbol index
    if (IsArchitectureQuery(request.Query)) {
        return CompressionStrategy.AstWithSymbols;
    }

    // Bug investigation -> Semantic chunking
    if (IsBugInvestigation(request.Query)) {
        return CompressionStrategy.Semantic;
    }

    // Large refactoring -> Template reduction
    if (IsLargeRefactoring(request)) {
        return CompressionStrategy.Template;
    }

    // Default: Hierarchical
    return CompressionStrategy.Hierarchical;
}
```

## Expected Results

| Strategy | Use Case | Token Reduction | Quality Loss |
|----------|----------|-----------------|--------------|
| AST | Architecture queries | 70-85% | Low |
| Diff | Incremental changes | 80-95% | Very Low |
| Symbol Index | Cross-file references | 50-70% | Low |
| Semantic | Bug investigation | 60-80% | Medium |
| Template | Large codebases | 75-90% | Medium |
| Hierarchical | General queries | 50-70% | Low |

## Integration Points

### 1. Pre-Request Hook
```csharp
// Before sending to LLM
var compressed = await compressionManager.CompressAsync(new CompressionRequest {
    FilePaths = context.Files,
    Query = context.UserQuery,
    MaxTokens = 4000 // Reserve tokens for response
});

llmRequest.Context = compressed.Content;
```

### 2. Symbol Cache
```csharp
// Build once, reuse across requests
public class SymbolCache {
    private Dictionary<string, SymbolIndex> _cache;

    public async Task WarmupAsync(string projectPath) {
        // Index entire codebase
        _cache = await BuildSymbolIndexAsync(projectPath);
    }
}
```

### 3. Metrics Dashboard
Track compression effectiveness:
- Average compression ratio
- Token savings per request
- Strategy usage distribution
- Quality feedback (user corrections needed)

## Tools & Libraries

**C# Parsing**:
- Microsoft.CodeAnalysis (Roslyn)
- Microsoft.CodeAnalysis.CSharp

**JS/TS Parsing**:
- TypeScript Compiler API
- Babel parser

**Token Counting**:
- SharpToken (tiktoken for C#)
- TiktokenSharp

**Embeddings** (for semantic chunking):
- Sentence-Transformers
- OpenAI embeddings API
- Local models via ONNX

**Diff Processing**:
- LibGit2Sharp
- DiffPlex

## Example Usage

```csharp
// Create compression manager
var manager = new CompressionManager(new CompressionOptions {
    MaxTokens = 8000,
    PreferredStrategy = CompressionStrategy.Auto
});

// Compress context
var result = await manager.CompressAsync(new CompressionRequest {
    FilePaths = new[] {
        "Services/UserService.cs",
        "Repositories/UserRepository.cs"
    },
    Query = "How does user authentication work?",
    Strategy = CompressionStrategy.Auto
});

Console.WriteLine($"Compression: {result.OriginalTokens} -> {result.CompressedTokens}");
Console.WriteLine($"Ratio: {result.CompressionRatio:P}");
Console.WriteLine($"Strategy used: {result.Metadata["strategy"]}");

// Use compressed context in LLM request
var response = await llm.ChatAsync(new ChatRequest {
    SystemPrompt = "You are a code assistant.",
    Context = result.Content,
    Query = request.Query
});
```

## Testing Strategy

1. **Unit Tests**: Each compression strategy independently
2. **Benchmark Tests**: Measure compression ratios on real codebases
3. **Quality Tests**: Verify LLM can still answer correctly with compressed context
4. **Regression Tests**: Ensure compression doesn't break existing functionality

## Next Steps

1. Create project structure under `C:\Projects\worker-agents\agent-001\`
2. Implement token counter utility first
3. Start with AST-based compression (highest value, lowest risk)
4. Build incrementally, testing each strategy
5. Integrate with your agent control plane

## References

- [Aider: How context compression works](https://aider.chat/docs/benchmarks.html)
- [Continue.dev: Context providers](https://docs.continue.dev/reference/config#context-providers)
- [Cursor: Codebase indexing](https://cursor.sh)
- [GitHub Copilot: Context awareness](https://github.blog/2023-05-17-how-github-copilot-is-getting-better-at-understanding-your-code/)
