# CS-AutoFix Tool Design

## Doel
Automatisch C# compile-time issues oplossen zonder handmatige LLM edits.

## Functionaliteit

### Phase 1: Core Features
1. **Missing Usings Detection & Fix**
   - Parse C# files met Roslyn
   - Detect unresolved types
   - Find correct namespace via reflection/NuGet
   - Add using statement

2. **Unused Usings Removal**
   - Detect unused using statements
   - Remove them (dotnet format doet dit ook al)

3. **Package Resolution**
   - Detect "type or namespace could not be found" errors
   - Search NuGet for package
   - Add PackageReference to .csproj

### Phase 2: Advanced Fixes
4. **Common Pattern Fixes**
   - Async without await → Add await or remove async
   - Missing null checks → Add null-conditional operators
   - String interpolation fixes

5. **Code Generation**
   - Missing constructors
   - Missing interface implementations
   - Missing override members

## Architecture

```
cs-autofix/
├── Program.cs                    # Entry point, CLI parsing
├── Analyzers/
│   ├── CompilationAnalyzer.cs   # Main Roslyn analyzer
│   ├── UsingAnalyzer.cs         # Missing/unused usings
│   ├── PackageAnalyzer.cs       # Missing packages
│   └── ErrorAnalyzer.cs         # Compile error parsing
├── Fixers/
│   ├── UsingFixer.cs            # Add/remove usings
│   ├── PackageFixer.cs          # Add packages to .csproj
│   └── CodeFixer.cs             # Code generation fixes
├── Services/
│   ├── RoslynService.cs         # Roslyn API wrapper
│   ├── NuGetService.cs          # NuGet package search
│   └── FileService.cs           # File I/O
└── Models/
    ├── FixResult.cs             # Fix operation result
    └── DiagnosticInfo.cs        # Diagnostic information
```

## Implementation Plan

### Step 1: Bootstrap Project
```bash
cd C:\scripts\tools
dotnet new console -n cs-autofix
cd cs-autofix
dotnet add package Microsoft.CodeAnalysis.CSharp.Workspaces
dotnet add package Microsoft.CodeAnalysis.Workspaces.MSBuild
dotnet add package NuGet.Protocol
dotnet add package NuGet.Packaging
```

### Step 2: Core Analyzer
- Load solution/project with MSBuildWorkspace
- Get compilation
- Iterate diagnostics
- Categorize by fix type

### Step 3: Using Fixer
- Parse syntax tree
- Find unresolved identifiers
- Search in referenced assemblies
- Add using directive at top of file

### Step 4: Package Fixer
- Extract type name from error
- Search NuGet API
- Modify .csproj XML
- Trigger restore

### Step 5: CLI Integration
```powershell
cs-autofix.exe --project <path> --fix-usings --fix-packages --dry-run
```

## Integration Points

### 1. Post-Edit Hook
After any Edit tool usage on .cs files:
```
Edit tool → cs-autofix --project <worktree> --fix-usings → git add
```

### 2. Pre-Commit Hook
```
git commit → cs-autofix --verify → commit
```

### 3. On-Demand
```powershell
cd worktree
cs-autofix --project . --fix-all
```

## Expected Fixes

### Example 1: Missing Using
**Before:**
```csharp
public class MyService {
    public List<string> GetItems() { ... }  // Error: List<T> not found
}
```

**After:**
```csharp
using System.Collections.Generic;

public class MyService {
    public List<string> GetItems() { ... }
}
```

### Example 2: Missing Package
**Error:**
```
error CS0246: The type or namespace name 'JsonSerializer' could not be found
```

**Fix:**
1. Search NuGet: "JsonSerializer" → System.Text.Json
2. Add to .csproj:
```xml
<PackageReference Include="System.Text.Json" Version="8.0.0" />
```
3. Add using:
```csharp
using System.Text.Json;
```

### Example 3: Unused Usings
**Before:**
```csharp
using System;
using System.Collections.Generic;
using System.Linq;  // Not used

public class Test { }
```

**After:**
```csharp
using System;
using System.Collections.Generic;

public class Test { }
```

## Performance Considerations
- Cache compilation results
- Incremental analysis (only changed files)
- Parallel processing of multiple files
- NuGet search caching

## Success Metrics
- % of compile errors auto-fixed
- Time saved per fix
- False positive rate
- User satisfaction

## Future Enhancements
- VS Code extension
- Real-time analysis during edit
- Machine learning for package suggestions
- Integration with GitHub Copilot
