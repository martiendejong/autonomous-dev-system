# Hazina Code Deduplication Masterplan
## Expert Team Analysis - 50 Concrete Actions

**Datum:** 2026-01-08
**Project:** Hazina Framework (C# Monorepo)
**Scope:** 76 projecten, 1089 C# bestanden, ~150.000 LOC
**Doel:** Eliminatie van dubbele en redundante code

---

## Team Organisatie

### Cluster 1: LLM Provider Specialisten (Experts 1-10)
Focus: Unificatie van de 8 LLM provider implementaties

### Cluster 2: Model & DTO Specialisten (Experts 11-20)
Focus: Consolidatie van message modellen en DTOs

### Cluster 3: Service Architecture Specialisten (Experts 21-30)
Focus: Shared service patterns en base classes

### Cluster 4: Configuration Specialisten (Experts 31-40)
Focus: Configuratie unificatie en generieke patterns

### Cluster 5: Cross-Cutting Concerns Specialisten (Experts 41-50)
Focus: Utilities, extensions, en infrastructuur

---

## 50 CONCRETE ACTIES

### CLUSTER 1: LLM PROVIDER DEDUPLICATIE (10 acties)

| # | Expert | Actie | Bestand(en) | Geschatte Impact |
|---|--------|-------|-------------|------------------|
| **1** | Provider Base Expert | Creëer `LLMProviderBase<TConfig>` abstracte klasse met shared HTTP client logica | `Hazina.LLMs.Client/Base/` | HOOG - elimineert 300+ LOC |
| **2** | HTTP Client Expert | Extraheer `ILLMHttpClient` interface met standaard retry, timeout, auth headers | Alle 8 provider projecten | HOOG - 200+ LOC reductie |
| **3** | Message Mapper Expert | Creëer `IMessageMapper<TProviderMessage>` interface + base implementatie | `Hazina.LLMs.Client/Mapping/` | HOOG - 400+ LOC reductie |
| **4** | OpenAI Refactor Expert | Refactor `SimpleOpenAIClientChatInteraction.cs` naar base class pattern | `Hazina.LLMs.OpenAI/` | MEDIUM |
| **5** | Anthropic Refactor Expert | Refactor `ClaudeClientWrapper.cs` naar base class pattern | `Hazina.LLMs.Anthropic/` | MEDIUM |
| **6** | Gemini Refactor Expert | Refactor `GeminiClientWrapper.cs` naar base class pattern | `Hazina.LLMs.Gemini/` | MEDIUM |
| **7** | Multi-Provider Expert | Unificeer Mistral, HuggingFace, Ollama wrappers met shared base | 3 provider projecten | MEDIUM |
| **8** | Token Usage Expert | Creëer unified `TokenUsageTracker` service ipv per-provider implementatie | Alle providers | MEDIUM - 150+ LOC |
| **9** | Streaming Expert | Extraheer `IStreamingHandler` interface voor SSE/streaming responses | Alle providers | MEDIUM |
| **10** | Error Handling Expert | Creëer `LLMExceptionHandler` met provider-agnostische error mapping | `Hazina.LLMs.Client/Exceptions/` | MEDIUM - 100+ LOC |

### CLUSTER 2: MODEL & DTO CONSOLIDATIE (10 acties)

| # | Expert | Actie | Bestand(en) | Geschatte Impact |
|---|--------|-------|-------------|------------------|
| **11** | ChatMessage Unification Expert | Consolideer `HazinaChatMessage` (Core) en `ChatMessage` (Tools) naar 1 model | Core + Tools | ZEER HOOG - 200+ LOC, 20+ refactors |
| **12** | Role Enum Expert | Unificeer `ChatMessageRole` enums (3 varianten gevonden) | Multiple projects | HOOG - 50+ refactors |
| **13** | Response Model Expert | Creëer unified `LLMResponse<T>` generic response wrapper | Alle response types | MEDIUM |
| **14** | Metadata Model Expert | Consolideer `DocumentMetadata` varianten (3 gevonden) | Store + Tools | MEDIUM |
| **15** | Embedding Model Expert | Unificeer embedding result types | Store + RAG | MEDIUM |
| **16** | Tool Definition Expert | Creëer shared `ToolDefinition` model voor alle tool-calling | AgentFactory + Providers | MEDIUM |
| **17** | Conversation Expert | Unificeer `ConversationMessage` en `GeneratorMessages` types | Tools.Services | MEDIUM |
| **18** | Config DTO Expert | Creëer `IProviderConfig` interface voor alle provider configs | 8 config classes | HOOG - 200+ LOC |
| **19** | Request DTO Expert | Creëer generic `LLMRequest` base class | Alle request types | MEDIUM |
| **20** | Scored Document Expert | Unificeer `ScoredDocument` varianten tussen RAG en Store | RAG + Store | LOW |

### CLUSTER 3: SERVICE ARCHITECTURE (10 acties)

| # | Expert | Actie | Bestand(en) | Geschatte Impact |
|---|--------|-------|-------------|------------------|
| **21** | Service Base Expert | Creëer `HazinaServiceBase<TConfig>` met DI, logging, config | `Hazina.Tools.Core/` | ZEER HOOG - 500+ LOC |
| **22** | Repository Pattern Expert | Implementeer generic `IRepository<T>` pattern voor alle data access | Data projects | HOOG |
| **23** | Service Registration Expert | Creëer unified `AddHazinaServices()` extension method | Infrastructure | MEDIUM |
| **24** | Chat Service Expert | Consolideer chat interaction logic in `InterviewAgent` en gerelateerde | Services.Chat | MEDIUM |
| **25** | Embedding Service Expert | Unificeer embedding generation tussen Services.Embeddings en Store | 2 projecten | MEDIUM |
| **26** | File Operations Expert | Consolideer file handling in Services.FileOps met shared utilities | FileOps + TextExtraction | MEDIUM |
| **27** | Web Service Expert | Extraheer `IWebClient` interface uit Services.Web duplicatie | Services.Web | LOW |
| **28** | Store Service Expert | Unificeer document store operations tussen Services.Store en Core.Store | 2 projecten | MEDIUM |
| **29** | Prompt Service Expert | Consolideer prompt loading/parsing logica | Services.Prompts + AgentFactory | MEDIUM |
| **30** | Agent Service Expert | Unificeer agent creation patterns tussen Tools.AI.Agents en Core.Agents | 2 projecten | HOOG |

### CLUSTER 4: CONFIGURATION PATTERNS (10 acties)

| # | Expert | Actie | Bestand(en) | Geschatte Impact |
|---|--------|-------|-------------|------------------|
| **31** | Base Config Expert | Creëer `HazinaConfigBase` met `Endpoint`, `ApiKey`, `Model` properties | Nieuwe shared class | ZEER HOOG - 400+ LOC |
| **32** | Config Parser Expert | Unificeer `HazinaAgentConfigParser`, `HazinaStoreConfigParser` naar generic parser | AgentFactory/Configuration | HOOG - 200+ LOC |
| **33** | Formatter Base Expert | Creëer `ConfigFormatterBase` voor AgentConfig/FlowConfig/StoreConfig formatters | AgentFactory/Formatters | MEDIUM - 150+ LOC |
| **34** | Validation Expert | Extraheer config validation naar `IConfigValidator<T>` | Alle config classes | MEDIUM |
| **35** | Options Pattern Expert | Implementeer consistent `IOptions<T>` pattern overal | Alle configuraties | MEDIUM |
| **36** | Environment Config Expert | Unificeer environment variable loading patterns | Multiple projects | LOW |
| **37** | Secrets Config Expert | Consolideer secrets loading (appsettings.Secrets.json handling) | Multiple projects | LOW |
| **38** | JSON Serializer Expert | Unificeer JSON serialization options naar shared defaults | Alle JSON handling | LOW |
| **39** | YAML Config Expert | Extraheer YAML parsing naar dedicated utility | AgentFactory | LOW |
| **40** | Config Builder Expert | Creëer fluent config builder pattern voor complexe configs | New utility | LOW |

### CLUSTER 5: CROSS-CUTTING CONCERNS (10 acties)

| # | Expert | Actie | Bestand(en) | Geschatte Impact |
|---|--------|-------|-------------|------------------|
| **41** | Extension Methods Expert | Consolideer LINQ extensions tussen Tools.Extensions en andere projecten | Extensions project | MEDIUM |
| **42** | String Utilities Expert | Creëer unified `StringUtilities` class (text truncation, sanitization) | Multiple projects | MEDIUM |
| **43** | Logging Expert | Unificeer logging patterns naar consistent `ILogger<T>` gebruik | Alle projecten | MEDIUM |
| **44** | Telemetry Expert | Consolideer telemetry/observability naar Observability.Core | Multiple projects | MEDIUM |
| **45** | Exception Expert | Creëer `HazinaException` hierarchy met shared exception types | New in Core | MEDIUM |
| **46** | Guard Clauses Expert | Extraheer argument validation naar `Guard` utility class | Multiple projects | LOW |
| **47** | Async Utilities Expert | Consolideer async helper methods (retry, timeout, cancellation) | Multiple projects | MEDIUM |
| **48** | Test Utilities Expert | Creëer shared test helpers/mocks in dedicated test utilities project | Tests/ | LOW |
| **49** | Dependency Injection Expert | Unificeer DI registration patterns naar convention-based approach | Multiple projects | MEDIUM |
| **50** | Code Generation Expert | Gebruik source generators voor repetitieve patterns (configs, mappers) | New tooling | LOW - future |

---

## IMPACT/EFFORT MATRIX

### Effort Levels:
- **XS**: < 2 uur werk
- **S**: 2-4 uur werk
- **M**: 4-8 uur werk (1 dag)
- **L**: 8-16 uur werk (2 dagen)
- **XL**: 16+ uur werk (meerdere dagen)

### Impact Levels:
- **Kritiek**: 400+ LOC reductie, fixes architectural issues
- **Hoog**: 200-400 LOC reductie
- **Medium**: 100-200 LOC reductie
- **Laag**: < 100 LOC reductie

---

## TOP PRIORITY ITEMS (Beste ROI)

### Prioriteit Score = Impact / Effort

| Rang | Actie # | Beschrijving | Effort | Impact | Score | LOC Reductie |
|------|---------|--------------|--------|--------|-------|--------------|
| **1** | #31 | Base Config class creëren | S | Kritiek | 10/10 | ~400 LOC |
| **2** | #11 | ChatMessage unificatie | M | Kritiek | 9/10 | ~200 LOC + 20 refactors |
| **3** | #18 | IProviderConfig interface | S | Hoog | 8/10 | ~200 LOC |
| **4** | #21 | HazinaServiceBase class | M | Kritiek | 8/10 | ~500 LOC |
| **5** | #1 | LLMProviderBase class | M | Hoog | 7/10 | ~300 LOC |
| **6** | #3 | IMessageMapper interface | M | Hoog | 7/10 | ~400 LOC |
| **7** | #32 | Generic Config Parser | M | Hoog | 6/10 | ~200 LOC |
| **8** | #12 | Role Enum unificatie | XS | Hoog | 9/10 | ~50 refactors |
| **9** | #33 | ConfigFormatterBase | S | Medium | 6/10 | ~150 LOC |
| **10** | #2 | ILLMHttpClient interface | M | Hoog | 6/10 | ~200 LOC |

---

## AANBEVOLEN VOLGORDE VAN UITVOERING

### Fase 1: Foundation (Week 1-2)
1. #31 - Base Config class
2. #18 - IProviderConfig interface
3. #11 - ChatMessage unificatie
4. #12 - Role Enum unificatie

### Fase 2: Provider Refactoring (Week 3-4)
5. #1 - LLMProviderBase class
6. #2 - ILLMHttpClient interface
7. #3 - IMessageMapper interface
8. #4-7 - Provider-specifieke refactors

### Fase 3: Service Layer (Week 5-6)
9. #21 - HazinaServiceBase class
10. #22-30 - Service consolidaties

### Fase 4: Configuration & Utilities (Week 7-8)
11. #32-40 - Configuration improvements
12. #41-50 - Cross-cutting improvements

---

## RISICO'S EN MITIGATIES

| Risico | Mitigatie |
|--------|-----------|
| Breaking changes in public API | Semantic versioning, deprecation warnings |
| Test coverage gaps | Run full test suite na elke wijziging |
| Merge conflicts | Kleine, frequent commits |
| Runtime regressions | Integration tests voor alle providers |
| Dependency issues | Careful project reference management |

---

## METRICS VOOR SUCCES

- **LOC Reductie**: Target 2000+ LOC eliminatie
- **Bestand Reductie**: Target 30+ bestanden consolidatie
- **Duplicate Code %**: Van ~15% naar < 5%
- **Cyclomatische Complexiteit**: 20% reductie
- **Test Coverage**: Behouden of verhogen

---

## VOLGENDE STAPPEN

1. **Goedkeuring** van top 5 prioriteit items
2. **Worktree allocatie** volgens protocol
3. **Feature branch** creatie per actie-cluster
4. **Implementatie** met continuous testing
5. **Code review** en merge
6. **Documentatie update**

---

*Dit plan is opgesteld door het virtuele expert team van 50 specialisten in code deduplicatie.*
