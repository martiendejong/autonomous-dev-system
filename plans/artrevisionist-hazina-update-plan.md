# ArtRevisionist Hazina Update Plan

**Datum:** 2026-01-08
**Huidige Hazina Versie:** v1.0.0 + 301 commits (develop branch)
**Huidige ArtRevisionist Status:** Laatste commit 381a8cf (docs: comprehensive WordPress features guide)
**Status:** CONCEPT - Wacht op gebruiker bevestiging

---

## Executive Summary

ArtRevisionist is een **zeer goed geïntegreerd Hazina systeem** met 13 actieve Hazina project references en 9 major components in gebruik. De laatste significante Hazina updates zijn echter nog niet geadopteerd.

**Belangrijkste Bevindingen:**
- ✅ ArtRevisionist gebruikt Hazina extensief en correct
- ⚠️ 301 nieuwe Hazina commits sinds december 2025 nog niet geïntegreerd
- ✅ Geen breaking changes geïdentificeerd - alle updates zijn backward compatible
- 🎯 Significant potentieel voor verbetering met nieuwe Hazina features

---

## Huidige Status Analyse

### ArtRevisionist Hazina Usage (Volledig)

**Core AI Features:**
- ✅ `Hazina.AI.FluentAPI` - Fluent API voor LLM calls
- ✅ `Hazina.AI.Providers` - Multi-provider orchestration (OpenAI + Anthropic)
- ✅ `Hazina.AI.Orchestration` - Provider orchestrator
- ✅ `Hazina.AI.FaultDetection` - Hallucination detection + fault correction

**Tools & Services:**
- ✅ `Hazina.Tools.Services.Embeddings` - Embeddings generation
- ✅ `Hazina.Tools.Services.Chat` - Chat services
- ✅ `Hazina.Tools.Services.Store` - Document store
- ✅ `Hazina.Tools.AI.Agents` - Agent framework (GeneratorAgentBase)
- ✅ `Hazina.Store.DocumentStore` - Document storage

**Active Features:**
1. **Multi-provider orchestration** met automatic failover
2. **Cost tracking & budget management** ($50/dag limit)
3. **Hallucination detection** met confidence scoring
4. **Neurochain pipeline** (8-stage content generation)
5. **Advanced document store** met metadata, tagging, graph relationships
6. **Embeddings processing** met background queue
7. **Chat system** met streaming, images, agents
8. **Research agent** met composite scoring

### Nieuwe Hazina Features (Niet Gebruikt)

**High Priority:**
1. ❌ `IEmbeddingsService.GenerateEmbeddingAsync(string text)` - Single text embedding API
2. ❌ `IToolAgentService` - 3-layer architecture voor tool orchestration
3. ❌ Social Media Providers (LinkedIn, Instagram, TikTok, X/Twitter, Bluesky)
4. ❌ Hierarchical Metadata Store - Cross-project knowledge sharing
5. ❌ Query-adaptive Tag Scoring - Enhanced document ranking

**Medium Priority:**
6. ❌ Enterprise Observability (OpenTelemetry, Grafana dashboards)
7. ❌ Distributed Tracing voor monitoring
8. ❌ Code Generation Pipeline (intent parser, templates)
9. ❌ Image Modification Tools (provider-agnostic)
10. ❌ Secure Database Tooling Layer

**Low Priority:**
11. ❌ Social Blog Publishers Infrastructure
12. ❌ Generic PromptBasedToolsOrchestrator refactor
13. ❌ HazinaServiceBase/LLMProviderBase deduplication

---

## Update Plan

### Fase 1: Foundation Updates (Kritisch - Week 1)

**Doel:** Update naar laatste Hazina versie en integreer essentiële API verbeteringen

#### Stap 1.1: Hazina Repository Sync
**Actie:**
```bash
cd C:\Projects\hazina
git checkout develop
git pull origin develop
git log --oneline -10  # Verify latest commits
```
**Impact:** LOW - Alleen lokale repository update
**Risico:** None
**Test:** Verify commit hash matches latest develop

#### Stap 1.2: Build & Test Hazina
**Actie:**
```bash
cd C:\Projects\hazina
dotnet build Hazina.sln
dotnet test Hazina.sln --no-build
```
**Impact:** LOW - Alleen verificatie
**Risico:** LOW - Mogelijk zijn er test failures door nieuwe features
**Test:** All existing tests should pass
**Rollback:** N/A (read-only verification)

#### Stap 1.3: Update ArtRevisionist Project References
**Actie:**
- ArtRevisionist gebruikt **lokale project references** (niet NuGet)
- Geen wijzigingen nodig - references wijzen al naar `..\..\hazina\src\`
- Verify dat alle references naar develop branch wijzen

**Files:** `ArtRevisionistAPI.csproj`, `HazinaStoreAPI.local.csproj`
**Impact:** NONE - References zijn al correct
**Risico:** NONE

#### Stap 1.4: Rebuild ArtRevisionist
**Actie:**
```bash
cd C:\Projects\artrevisionist\ArtRevisionistAPI
dotnet clean
dotnet build
```
**Impact:** MEDIUM - Mogelijk compile errors door API changes
**Risico:** MEDIUM - Breaking changes kunnen build breken
**Test:** Solution should build successfully
**Rollback:** `git checkout develop` in Hazina repo

---

### Fase 2: API Compatibility Updates (High Priority - Week 1-2)

**Doel:** Adopteer nieuwe APIs die backward compatible zijn

#### Stap 2.1: Implementeer GenerateEmbeddingAsync
**Waar:** `EmbeddingsController.cs`, mogelijk nieuwe endpoints
**Actie:**
```csharp
// Nieuwe endpoint toevoegen
[HttpPost("generate")]
public async Task<IActionResult> GenerateEmbedding([FromBody] string text)
{
    var embedding = await _embeddingsService.GenerateEmbeddingAsync(text);
    return Ok(new { embedding, dimension = embedding.Count });
}
```
**Impact:** LOW - Additive change (geen bestaande code breekt)
**Risico:** LOW
**Test:**
- Unit test: Generate embedding voor "test text"
- Integration test: Verify embedding dimension (1536 voor OpenAI)

#### Stap 2.2: Gebruik FragmentMetadata.NeedsRegeneration
**Waar:** Brand fragment management, client-manager integratie
**Actie:**
- Update FragmentMetadata models om nieuwe properties te gebruiken
- Implementeer regeneration detection logic
```csharp
if (fragment.Metadata.NeedsRegeneration)
{
    _logger.LogInformation(
        "Fragment needs regeneration: {Reason}",
        fragment.Metadata.RegenerationReason
    );
    await RegenerateFragmentAsync(fragment);
}
```
**Impact:** MEDIUM - Verbetert change detection
**Risico:** LOW - Properties zijn nullable/optional
**Test:**
- Verify fragments with changed source assets trigger regeneration
- Log regeneration reasons correctly

---

### Fase 3: Architecture Enhancements (Medium Priority - Week 2-3)

**Doel:** Adopteer 3-layer architecture en tool orchestration

#### Stap 3.1: Integreer IToolAgentService
**Waar:** Nieuwe service layer tussen ChatController en specialized tools
**Actie:**
1. Add project reference: `Hazina.Tools.Services.ToolAgent`
2. Registreer in DI: `builder.Services.AddScoped<IToolAgentService, ToolAgentService>()`
3. Refactor chat workflows om via ToolAgent te gaan:
```csharp
// Layer 1 (Chat): Decide WHAT
var action = await DetermineActionAsync(userMessage);

// Layer 2 (ToolAgent): Decide HOW
var request = new ToolAgentRequest
{
    Action = action,
    Context = chatContext
};
var result = await _toolAgentService.ExecuteActionAsync(request);

// Layer 3 (Specialized Tools): DO
// Handled by ToolAgent internally
```
**Impact:** HIGH - Significant architectural change
**Risico:** MEDIUM - Requires careful migration van bestaande workflows
**Test:**
- Integration tests voor complete 3-layer flow
- Verify alle bestaande chat features blijven werken
**Rollback:** Behoud oude direct tool calls als fallback

#### Stap 3.2: Gebruik ModelRouter voor Dynamic LLM Selection
**Waar:** Content generation, analysis workflows
**Actie:**
- Gebruik ModelRouter om per taak optimale LLM te selecteren
- Goedkope modellen voor simple tasks, sterke modellen voor complex reasoning
**Impact:** MEDIUM - Cost optimization + quality improvement
**Risico:** LOW - Optional feature, kan geleidelijk adopteren
**Test:**
- Verify simple tasks gebruiken gpt-4o-mini
- Verify complex tasks gebruiken claude-3-5-sonnet

---

### Fase 4: Storage & Knowledge Enhancements (Medium Priority - Week 3-4)

**Doel:** Verbeter document retrieval en knowledge management

#### Stap 4.1: Implementeer Hierarchical Metadata Store
**Waar:** ResearchAgentService, document management
**Actie:**
1. Add project reference: `Hazina.Store.HierarchicalMetadata`
2. Registreer in DI:
```csharp
builder.Services.AddSingleton<IHierarchicalMetadataStore>(sp =>
{
    var basePath = Path.Combine(settings.ProjectsFolder, "_hierarchy");
    return new HierarchicalMetadataFileStore(basePath);
});
```
3. Update research workflows om cross-project knowledge te gebruiken
**Impact:** MEDIUM - Enables knowledge sharing across projects
**Risico:** LOW - Additive feature
**Test:**
- Create metadata in project A
- Verify accessible from project B via hierarchy

#### Stap 4.2: Implementeer Query-Adaptive Tag Scoring
**Waar:** ResearchAgentService, document ranking
**Actie:**
- Upgrade van `NoOpTagScoringService` naar query-adaptive scoring
- Gebruik nieuwe composite scoring features
**Impact:** MEDIUM - Significant verbeterde document ranking
**Risico:** LOW - Kan geleidelijk testen en rollout
**Test:**
- Compare ranking results: old vs new algorithm
- Measure relevance improvement met test queries

---

### Fase 5: Social Media Integration (Low Priority - Week 5-6)

**Doel:** Integreer social media providers voor content import

#### Stap 5.1: LinkedIn Provider
**Waar:** Nieuwe SocialMediaController
**Actie:**
1. Add project references:
   - `Hazina.Tools.Services.Social.LinkedIn`
   - `Hazina.Tools.Services.Social.Core`
2. Registreer providers in DI
3. Implementeer endpoints:
   - `GET /api/social/linkedin/posts` - Import posts
   - `GET /api/social/linkedin/profile` - Fetch profile
**Impact:** LOW - Nieuwe feature, bestaande code niet beïnvloed
**Risico:** LOW
**Test:** Integration tests met LinkedIn API (sandbox)

#### Stap 5.2: Instagram, TikTok, X/Twitter Providers
**Actie:** Analoog aan LinkedIn provider
**Impact:** LOW - Optional features
**Risico:** LOW
**Test:** Per provider, integration tests

---

### Fase 6: Enterprise Observability (Low Priority - Week 7-8)

**Doel:** Production monitoring en observability

#### Stap 6.1: OpenTelemetry Integration
**Waar:** Program.cs, infrastructure
**Actie:**
1. Add NuGet packages:
   - `OpenTelemetry.Exporter.Console`
   - `OpenTelemetry.Instrumentation.AspNetCore`
   - `OpenTelemetry.Instrumentation.Http`
2. Configure in Program.cs:
```csharp
builder.Services.AddOpenTelemetry()
    .WithTracing(tracing => tracing
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddConsoleExporter()
    );
```
**Impact:** MEDIUM - Adds telemetry overhead
**Risico:** LOW - Can be disabled if issues arise
**Test:**
- Verify traces exported correctly
- Check performance impact (should be <5%)

#### Stap 6.2: Grafana Dashboard
**Actie:**
- Setup Grafana instance (optional - docker-compose)
- Import Hazina monitoring dashboard templates
**Impact:** LOW - External tooling
**Risico:** NONE - Optional feature
**Test:** Manual verification van dashboards

---

### Fase 7: Code Generation Pipeline (Future - Week 9+)

**Doel:** Adopteer code generation features indien nodig

**Actie:** Evaluate use cases voor code generation binnen ArtRevisionist
**Status:** ON HOLD - Wacht op concrete use case
**Impact:** TBD
**Risico:** TBD

---

## Risico Management

### Kritische Risico's

| Risico | Impact | Waarschijnlijkheid | Mitigatie |
|--------|--------|-------------------|-----------|
| Breaking changes in Hazina APIs | HIGH | LOW | Thorough testing in dev environment eerst |
| Build failures na update | MEDIUM | MEDIUM | Feature branch + rollback plan |
| Performance degradation | MEDIUM | LOW | Benchmark tests voor/na update |
| Data migration issues | HIGH | LOW | Backup database voor updates |
| Integration test failures | MEDIUM | MEDIUM | Comprehensive test suite uitvoeren |

### Rollback Plan

**Per Fase:**
1. **Fase 1:** `cd C:\Projects\hazina && git checkout <previous-commit>`
2. **Fase 2-7:** `git revert <feature-commit>` + rollback DI registrations
3. **Emergency:** Volledig rollback naar pre-update state via git

**Backup Strategy:**
- Database backup voor updates
- Git feature branches voor elke fase
- Document current state in `CURRENT_STATE.md`

---

## Testing Strategy

### Per Fase Tests

**Fase 1: Foundation**
- ✅ Build succeeds
- ✅ All existing unit tests pass
- ✅ Integration tests pass
- ✅ Manual smoke test van critical flows

**Fase 2: API Compatibility**
- ✅ Unit tests voor nieuwe APIs
- ✅ Integration tests voor embeddings
- ✅ Regression tests (bestaande features)

**Fase 3: Architecture**
- ✅ 3-layer architecture integration tests
- ✅ Model routing tests
- ✅ End-to-end chat flow tests
- ✅ Performance benchmarks

**Fase 4: Storage**
- ✅ Cross-project knowledge tests
- ✅ Document ranking accuracy tests
- ✅ Storage migration tests

**Fase 5-7:** Per feature, dedicated test suites

### Acceptance Criteria

**Per Fase:**
- [ ] All tests pass (unit + integration)
- [ ] No performance regression (>10% slower)
- [ ] No memory leaks
- [ ] All existing features blijven werken
- [ ] New features documented
- [ ] Code review completed

---

## Success Metrics

### Kwantitatief
- ✅ Build success rate: 100%
- ✅ Test pass rate: 100%
- ✅ Performance: <5% overhead
- ✅ Code coverage: >80% voor nieuwe code

### Kwalitatief
- Verbeterde document retrieval accuracy
- Betere cost efficiency (via ModelRouter)
- Enhanced monitoring capabilities
- Cleaner architecture (3-layer)
- Cross-project knowledge sharing

---

## Timeline (Conservatief)

| Fase | Duur | Start | Eind |Afhankelijkheden |
|------|------|-------|------|------------------|
| Fase 1 | 1 week | Week 1 | Week 1 | None |
| Fase 2 | 1 week | Week 1 | Week 2 | Fase 1 |
| Fase 3 | 2 weken | Week 2 | Week 3 | Fase 2 |
| Fase 4 | 2 weken | Week 3 | Week 4 | Fase 2 |
| Fase 5 | 2 weken | Week 5 | Week 6 | Fase 1 |
| Fase 6 | 2 weken | Week 7 | Week 8 | Fase 1 |
| Fase 7 | TBD | On Hold | - | Use case definition |

**Totaal:** 6-8 weken (excl. Fase 7)

---

## Aanbevelingen

### Must Have (Kritisch)
1. ✅ **Fase 1: Foundation Updates** - Essentieel voor compatibility
2. ✅ **Fase 2: API Compatibility** - Nieuwe APIs adopteren

### Should Have (Belangrijk)
3. ✅ **Fase 3: Architecture Enhancements** - Significant architectural improvement
4. ✅ **Fase 4: Storage Enhancements** - Betere knowledge management

### Could Have (Optioneel)
5. ⚠️ **Fase 5: Social Media** - Alleen indien use case aanwezig
6. ⚠️ **Fase 6: Observability** - Handig voor production, niet kritisch

### Won't Have (Later)
7. ❌ **Fase 7: Code Generation** - Geen concrete use case nu

---

## Volgende Stappen

**Na Goedkeuring:**
1. Creëer feature branch: `feature/hazina-update-2026-01`
2. Maak worktree voor isolatie:
   ```bash
   cd C:\Projects\worker-agents
   # Allocate worktree via protocol
   git worktree add agent-001/artrevisionist -b feature/hazina-update-2026-01
   ```
3. Start met Fase 1.1
4. Daily progress updates in `C:\scripts\status\hazina-update.md`
5. Weekly review meetings

---

## Open Vragen

1. **Prioriteit Social Media:** Zijn LinkedIn/Instagram providers een requirement?
2. **Observability:** Is Grafana/OpenTelemetry gewenst voor production?
3. **Timeline:** Is 6-8 weken acceptabel of moet het sneller?
4. **Testing:** Manual testing of volledig geautomatiseerd?
5. **Rollout:** Big bang (alle fases tegelijk) of incrementeel?

---

**Status:** ⏸️ WAITING FOR APPROVAL
**Next Action:** Review met gebruiker + bevestiging om door te gaan
