# Analysis Field Architecture - Incremental Implementation Plan
**Date:** 2026-01-17
**Based on:** 50-Expert Panel Assessment
**Timeline:** 6 Months (24 Sprints)
**Goal:** Transform analysis field system into template-based, scalable architecture

---

## Executive Summary

**Current State:**
- 14 analysis fields with 6 having specialized components
- Configuration duplicated across 5+ locations
- No modal editor system, no click-to-edit
- No field-level validation or error handling

**Target State:**
- Template-based field registry (add new fields in 1 location)
- Unified component architecture with shared Modal/Edit/Chat/Row patterns
- Click-to-edit everywhere (chat, activities, modals)
- Full validation, error boundaries, accessibility compliance
- Cost-optimized AI model selection per field

**Migration Strategy:** Incremental refactoring with zero downtime, backward compatibility maintained

---

## Phase 1: Foundation (Weeks 1-4) - "Stop the Bleeding"

### Objective
Fix critical architectural issues blocking further development

### Sprint 1-2: Unified Configuration System

**Task 1.1: Create Single Source of Truth**
```bash
Location: C:/Projects/client-manager/config/
Files to create:
  - field-catalog.json (master registry)
  - component-templates.json (template definitions)
  - field-prompts.json (AI generation prompts)
```

**Task 1.2: Design Field Catalog Schema**
```json
{
  "version": "1.0.0",
  "fields": [
    {
      "id": "color-scheme",
      "metadata": {
        "displayName": { "en": "Color Scheme", "nl": "Kleurenschema" },
        "description": "Brand color palette",
        "category": "visual-identity",
        "order": 10,
        "icon": "palette"
      },
      "storage": {
        "fileName": "color-scheme.json",
        "promptFileName": "color-scheme.prompt.txt"
      },
      "components": {
        "templateId": "color-array",
        "variants": {
          "full": "ColorScheme",
          "compact": "ColorSchemeRow",
          "chat": "ColorSchemeChat",
          "modal": "ColorSchemeModal"
        }
      },
      "validation": {
        "schemaId": "ColorSchemeSchema",
        "required": true
      },
      "generation": {
        "model": "haiku",
        "temperature": 0.7,
        "maxTokens": 500
      },
      "permissions": {
        "read": ["user", "admin"],
        "write": ["admin"],
        "generate": ["user", "admin"]
      }
    }
  ],
  "categories": [
    { "id": "visual-identity", "label": { "en": "Visual Identity" }, "order": 1 },
    { "id": "brand-strategy", "label": { "en": "Brand Strategy" }, "order": 2 }
  ]
}
```

**Task 1.3: Create Component Template Registry**
```json
{
  "templates": [
    {
      "id": "color-array",
      "displayName": "Color Array Component",
      "dataType": "ColorScheme",
      "compatibleFields": ["color-scheme", "accent-colors"],
      "variants": {
        "full": { "component": "ColorScheme", "lazy": false },
        "compact": { "component": "ColorSchemeRow", "lazy": false },
        "chat": { "component": "ColorSchemeChat", "lazy": true },
        "modal": { "component": "ColorSchemeModal", "lazy": true }
      },
      "sharedUtilities": ["ColorPicker", "HexValidator"],
      "exampleData": {
        "colors": [
          { "key": "primary", "name": "Deep Plum", "color": "#6C3483" }
        ]
      }
    },
    {
      "id": "items-list",
      "displayName": "Title-Description List",
      "dataType": "ItemsList",
      "compatibleFields": ["core-values", "usps", "benefits"],
      "variants": {
        "full": { "component": "ItemsList", "lazy": false },
        "compact": { "component": "ItemsListRow", "lazy": false },
        "chat": { "component": "ItemsListChat", "lazy": true },
        "modal": { "component": "ItemsListModal", "lazy": true }
      },
      "sharedUtilities": ["EditableObjectList"],
      "exampleData": {
        "values": [
          { "title": "Innovation", "description": "We pioneer new solutions" }
        ]
      }
    }
  ]
}
```

**Task 1.4: Migrate Existing Fields to New Catalog**
- Script to auto-convert analysis-fields.config.json → field-catalog.json
- Validate all 14 existing fields migrate correctly
- Add 6 hidden BrandDocumentFragment fields to catalog

**Deliverables:**
- ✅ `field-catalog.json` with all 20 fields
- ✅ `component-templates.json` with 7 templates
- ✅ Migration script: `migrate-field-config.js`
- ✅ Backward compatibility layer (old API still works)

---

### Sprint 3-4: Error Boundaries & Validation

**Task 2.1: Field Error Boundary Component**
```typescript
// src/components/shared/FieldErrorBoundary.tsx
interface Props {
  fieldKey: string
  fallback?: React.ReactNode
  onError?: (error: Error, errorInfo: React.ErrorInfo) => void
}

export function FieldErrorBoundary({ fieldKey, children, fallback }: Props) {
  const [hasError, setHasError] = useState(false)

  if (hasError) {
    return fallback || (
      <div className="field-error">
        <AlertTriangle />
        <p>Unable to load {fieldKey} editor</p>
        <button onClick={() => setHasError(false)}>Try Again</button>
      </div>
    )
  }

  return <ErrorBoundary onError={(e) => logFieldError(fieldKey, e)}>
    {children}
  </ErrorBoundary>
}
```

**Task 2.2: JSON Schema Validation System**
```typescript
// src/validation/schemas.ts
export const ColorSchemeSchema = {
  type: "object",
  required: ["colors"],
  properties: {
    colors: {
      type: "array",
      minItems: 3,
      maxItems: 10,
      items: {
        type: "object",
        required: ["key", "name", "color"],
        properties: {
          key: { type: "string", pattern: "^[a-z-]+$" },
          name: { type: "string", minLength: 2 },
          color: { type: "string", pattern: "^#[0-9A-Fa-f]{6}$" }
        }
      }
    }
  }
}

// Auto-validate on save
export function validateFieldData(fieldKey: string, data: any) {
  const schema = getSchemaForField(fieldKey)
  const result = ajv.validate(schema, data)
  if (!result) {
    return {
      valid: false,
      errors: ajv.errors.map(e => ({
        path: e.instancePath,
        message: e.message,
        suggestion: getSuggestion(e)
      }))
    }
  }
  return { valid: true }
}
```

**Task 2.3: User-Facing Validation UI**
```typescript
// Display validation errors before save
<ValidationErrors errors={validationResult.errors}>
  {errors.map(err => (
    <div className="validation-error">
      <AlertCircle />
      <span>{err.message}</span>
      {err.suggestion && <button onClick={err.suggestion.action}>
        {err.suggestion.label}
      </button>}
    </div>
  ))}
</ValidationErrors>
```

**Deliverables:**
- ✅ FieldErrorBoundary wrapping all dynamic components
- ✅ JSON schemas for 7 field types
- ✅ Validation UI component
- ✅ Error logging to backend (OpenTelemetry)

---

## Phase 2: Component Refactoring (Weeks 5-8) - "Build the Legos"

### Objective
Extract shared patterns into reusable wrapper components

### Sprint 5-6: Shared Component Library

**Task 3.1: Create FieldModal Wrapper**
```typescript
// src/components/shared/FieldModal.tsx
interface FieldModalProps {
  fieldKey: string
  projectId: string
  isOpen: boolean
  onClose: () => void
  mode?: 'create' | 'edit' | 'view'
}

export function FieldModal({ fieldKey, projectId, isOpen, onClose, mode = 'edit' }: FieldModalProps) {
  const { data, isLoading } = useAnalysisField(projectId, fieldKey)
  const { component } = useFieldComponent(fieldKey, 'modal')

  return (
    <Modal isOpen={isOpen} onClose={onClose} size="large">
      <ModalHeader>
        <FieldIcon fieldKey={fieldKey} />
        <h2>{getFieldDisplayName(fieldKey)}</h2>
        <CloseButton onClick={onClose} />
      </ModalHeader>

      <ModalBody>
        <FieldErrorBoundary fieldKey={fieldKey}>
          <Suspense fallback={<FieldSkeleton />}>
            {React.createElement(component, {
              data,
              projectId,
              fieldKey,
              mode,
              onChange: (newData) => saveField(projectId, fieldKey, newData)
            })}
          </Suspense>
        </FieldErrorBoundary>
      </ModalBody>

      <ModalFooter>
        <FieldActions fieldKey={fieldKey} projectId={projectId} />
      </ModalFooter>
    </Modal>
  )
}
```

**Task 3.2: Create ClickToEdit Wrapper**
```typescript
// src/components/shared/ClickToEdit.tsx
interface ClickToEditProps {
  fieldKey: string
  projectId: string
  displayMode: 'inline' | 'badge' | 'chip'
  onEditStart?: () => void
}

export function ClickToEdit({ fieldKey, projectId, displayMode }: ClickToEditProps) {
  const [isEditing, setIsEditing] = useState(false)
  const { data } = useAnalysisField(projectId, fieldKey)
  const { component: ViewComponent } = useFieldComponent(fieldKey, 'chat')
  const { component: EditComponent } = useFieldComponent(fieldKey, 'full')

  if (isEditing) {
    return (
      <div className="click-to-edit editing">
        <EditComponent
          data={data}
          onChange={(newData) => {
            saveField(projectId, fieldKey, newData)
            setIsEditing(false)
          }}
          onCancel={() => setIsEditing(false)}
        />
      </div>
    )
  }

  return (
    <div
      className="click-to-edit view"
      onClick={() => setIsEditing(true)}
      role="button"
      aria-label={`Click to edit ${getFieldDisplayName(fieldKey)}`}
    >
      <ViewComponent data={data} />
      <EditIcon className="edit-affordance" />
    </div>
  )
}
```

**Task 3.3: Create ExpandableField Wrapper**
```typescript
// src/components/shared/ExpandableField.tsx
interface ExpandableFieldProps {
  fieldKey: string
  projectId: string
  initialState?: 'collapsed' | 'expanded'
}

export function ExpandableField({ fieldKey, projectId, initialState = 'collapsed' }: ExpandableFieldProps) {
  const [isExpanded, setIsExpanded] = useState(initialState === 'expanded')
  const { data } = useAnalysisField(projectId, fieldKey)
  const { component: CompactComponent } = useFieldComponent(fieldKey, 'compact')
  const { component: FullComponent } = useFieldComponent(fieldKey, 'full')

  return (
    <div className="expandable-field">
      <div className="expandable-header" onClick={() => setIsExpanded(!isExpanded)}>
        <FieldIcon fieldKey={fieldKey} />
        <h4>{getFieldDisplayName(fieldKey)}</h4>
        <ChevronIcon direction={isExpanded ? 'up' : 'down'} />
      </div>

      <div className={`expandable-content ${isExpanded ? 'expanded' : 'collapsed'}`}>
        {isExpanded ? (
          <FullComponent data={data} onChange={(newData) => saveField(projectId, fieldKey, newData)} />
        ) : (
          <CompactComponent data={data} />
        )}
      </div>
    </div>
  )
}
```

**Deliverables:**
- ✅ FieldModal wrapper (200 lines)
- ✅ ClickToEdit wrapper (150 lines)
- ✅ ExpandableField wrapper (100 lines)
- ✅ Storybook stories for all 3 wrappers
- ✅ Unit tests (80%+ coverage)

---

### Sprint 7-8: Refactor Existing Components to Use Wrappers

**Task 4.1: Migrate ColorScheme to New Pattern**
```typescript
// Before (900 lines with embedded modal logic)
export function ColorScheme({ data, onChange, projectId, fieldKey, inline }) {
  // 900 lines of modal, validation, state management
}

// After (250 lines, focused on color editing)
export function ColorScheme({ data, onChange, mode }) {
  // Pure color editing logic only
  // No modal, no error handling, no loading states
}

// Modal variant uses wrapper
export function ColorSchemeModal(props) {
  return <FieldModal {...props} component={ColorScheme} />
}
```

**Task 4.2: Migrate ItemsList to New Pattern**
- Extract modal logic to FieldModal wrapper
- Extract validation to JSON schema
- Reduce from 600 lines to 300 lines

**Task 4.3: Migrate ImageSet to New Pattern**
- Extract SignalR connection to shared hook
- Extract modal logic to FieldModal wrapper
- Reduce from 900 lines to 400 lines

**Deliverables:**
- ✅ ColorScheme refactored (900→250 lines)
- ✅ ItemsList refactored (600→300 lines)
- ✅ ImageSet refactored (900→400 lines)
- ✅ All existing functionality preserved
- ✅ Visual regression tests pass

---

## Phase 3: Modal Editor System (Weeks 9-12) - "The UX Revolution"

### Objective
Build dedicated modal editors for all field types with click-to-edit

### Sprint 9-10: Create Missing Modal Editors

**Task 5.1: Typography Modal Editor**
```typescript
// src/components/view/analysis/TypographyModal.tsx
export function TypographyModal({ data, onChange, projectId }: Props) {
  return (
    <div className="typography-modal">
      <section className="font-browser">
        <h3>Google Fonts</h3>
        <FontGrid fonts={googleFonts} onSelect={addFont} />
      </section>

      <section className="typography-rules">
        {data.fonts.map(font => (
          <TypographyRule
            key={font.key}
            font={font}
            onChange={(updated) => updateFont(font.key, updated)}
            onRemove={() => removeFont(font.key)}
          />
        ))}
      </section>

      <section className="live-preview">
        <h3>Preview</h3>
        <BrandPreview typography={data} />
      </section>
    </div>
  )
}
```

**Task 5.2: ImageSet/Logo Dedicated Modal**
```typescript
// src/components/view/analysis/LogoModal.tsx
export function LogoModal({ data, onChange, projectId, fieldKey }: Props) {
  return (
    <div className="logo-modal">
      <section className="logo-grid">
        {[0, 1, 2, 3].map(index => (
          <LogoSlot
            key={index}
            image={data.images[index]}
            isSelected={data.selectedIndex === index}
            onSelect={() => selectLogo(index)}
            onRegenerate={() => regenerateLogo(index)}
            onUpload={(file) => uploadLogo(index, file)}
            onDelete={() => deleteLogo(index)}
          />
        ))}
      </section>

      <section className="logo-preview">
        <h3>Usage Preview</h3>
        <LogoPreviewGrid selectedLogo={data.images[data.selectedIndex]} />
      </section>

      <section className="logo-generation">
        <h3>Generate New Variants</h3>
        <textarea placeholder="Describe your logo vision..." />
        <button onClick={generateAllLogos}>Generate 4 Variants</button>
      </section>
    </div>
  )
}
```

**Task 5.3: Text Field Modal Editors**
Create modals for all 8 text-only fields:
- BrandProfileModal (rich text editor)
- NarrativeModal (story builder with sections)
- TargetAudienceModal (persona builder)
- MissionModal (statement editor with examples)
- VisionModal (statement editor)
- SchemesOfWorkModal (structured list editor)
- BusinessDescriptionModal (rich text + tags)
- BrandStoryModal (timeline-based story editor)

**Deliverables:**
- ✅ 11 new modal editor components
- ✅ Each modal <400 lines
- ✅ Storybook stories for all modals
- ✅ Mobile-responsive (bottom sheet pattern)

---

### Sprint 11-12: Integrate Click-to-Edit Everywhere

**Task 6.1: Enable in Chat View**
```typescript
// src/components/containers/MessageItem.tsx
// Wrap analysis field renders with ClickToEdit
{payload.componentName && (
  <ClickToEdit
    fieldKey={payload.key}
    projectId={projectId}
    displayMode="inline"
  />
)}
```

**Task 6.2: Enable in Activities Sidebar**
```typescript
// src/components/view/Sidebar.tsx
// Replace direct field links with ExpandableField
<div className="analysis-fields">
  {fields.map(field => (
    <ExpandableField
      key={field.key}
      fieldKey={field.key}
      projectId={projectId}
      initialState="collapsed"
    />
  ))}
</div>
```

**Task 6.3: Add Keyboard Shortcuts**
- `E` - Edit focused field (opens modal)
- `Escape` - Close modal
- `Cmd/Ctrl + S` - Save field (if dirty)
- `Cmd/Ctrl + K` - Open field search palette

**Deliverables:**
- ✅ Click-to-edit in chat messages
- ✅ Expandable fields in sidebar
- ✅ Keyboard shortcuts
- ✅ Touch gestures (swipe to expand on mobile)
- ✅ Accessibility audit pass (WCAG 2.1 AA)

---

## Phase 4: Backend Optimization (Weeks 13-16) - "Scale & Perform"

### Objective
Optimize backend for performance, caching, AI cost reduction

### Sprint 13-14: Caching & Performance

**Task 7.1: Implement Redis Caching**
```csharp
// Services/CachedAnalysisFieldService.cs
public class CachedAnalysisFieldService : IAnalysisFieldService
{
    private readonly IAnalysisFieldService _inner;
    private readonly IDistributedCache _cache;

    public async Task<string?> GetFieldContentAsync(string projectId, string key)
    {
        var cacheKey = $"field:{projectId}:{key}";
        var cached = await _cache.GetStringAsync(cacheKey);

        if (cached != null) return cached;

        var content = await _inner.GetFieldContentAsync(projectId, key);
        await _cache.SetStringAsync(cacheKey, content, new DistributedCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5)
        });

        return content;
    }

    public async Task SaveFieldAsync(string projectId, string key, string content)
    {
        await _inner.SaveFieldAsync(projectId, key, content);
        await _cache.RemoveAsync($"field:{projectId}:{key}");
        await _cache.RemoveAsync($"project:{projectId}:fields"); // Invalidate list cache
    }
}
```

**Task 7.2: Implement React Query Caching**
```typescript
// src/hooks/useAnalysisField.ts
export function useAnalysisField(projectId: string, fieldKey: string) {
  return useQuery({
    queryKey: ['analysis-field', projectId, fieldKey],
    queryFn: () => fetchFieldContent(projectId, fieldKey),
    staleTime: 5 * 60 * 1000, // 5 minutes
    cacheTime: 10 * 60 * 1000, // 10 minutes
    retry: 2
  })
}

export function useFieldMutation(projectId: string, fieldKey: string) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (data: any) => saveFieldContent(projectId, fieldKey, data),
    onSuccess: () => {
      queryClient.invalidateQueries(['analysis-field', projectId, fieldKey])
      queryClient.invalidateQueries(['analysis-fields', projectId])
    }
  })
}
```

**Task 7.3: Code Splitting & Lazy Loading**
```typescript
// Lazy load all field components
const ColorScheme = lazy(() => import('./analysis/ColorScheme'))
const ItemsList = lazy(() => import('./analysis/ItemsList'))
const ImageSet = lazy(() => import('./analysis/ImageSet'))

// Dynamic registry with code splitting
export const dynamicComponents = {
  ColorScheme: () => import('./analysis/ColorScheme'),
  ItemsList: () => import('./analysis/ItemsList'),
  // ...
}
```

**Deliverables:**
- ✅ Redis caching layer (5min TTL)
- ✅ React Query integration
- ✅ Code splitting for all field components
- ✅ Performance metrics: <100ms field load time (from 200ms)

---

### Sprint 15-16: AI Cost Optimization

**Task 8.1: Intelligent Model Selection**
```typescript
// config/field-catalog.json
{
  "fields": [
    {
      "id": "color-scheme",
      "generation": {
        "model": "haiku",  // Simple structured data → Haiku
        "temperature": 0.7,
        "maxTokens": 300
      }
    },
    {
      "id": "brand-story",
      "generation": {
        "model": "sonnet",  // Complex narrative → Sonnet
        "temperature": 0.8,
        "maxTokens": 2000
      }
    },
    {
      "id": "business-plan",
      "generation": {
        "model": "opus",  // Multi-section strategic doc → Opus
        "temperature": 0.7,
        "maxTokens": 8000
      }
    }
  ]
}
```

**Projected Cost Savings:**
- Haiku for 8 simple fields (color, tags, lists) → 90% cheaper
- Sonnet for 4 medium fields (stories, descriptions) → baseline
- Opus only for 2 complex fields (business plan, fragments) → premium
- **Total savings: 60% reduction in AI costs**

**Task 8.2: Prompt Optimization**
```
Before (verbose prompt, 500 tokens):
"Please generate a comprehensive and detailed tone of voice descriptor list
for the brand based on the following information..."

After (concise prompt, 150 tokens):
"Generate 5-7 tone descriptors for {brand}. Include personality traits that
differentiate from competitors. Output format: ["descriptor1", "descriptor2", ...]"

Savings: 70% fewer input tokens per generation
```

**Deliverables:**
- ✅ Model selection per field type in catalog
- ✅ Optimized prompts (50% token reduction)
- ✅ Cost tracking dashboard
- ✅ Monthly cost report: $X → $Y (60% reduction)

---

## Phase 5: Advanced Features (Weeks 17-20) - "Power User Tools"

### Objective
Add field history, bulk operations, advanced UX features

### Sprint 17-18: Field History & Versioning

**Task 9.1: Field Version Storage**
```csharp
// Models/AnalysisFieldVersion.cs
public class AnalysisFieldVersion
{
    public string Id { get; set; } // GUID
    public string ProjectId { get; set; }
    public string FieldKey { get; set; }
    public string Content { get; set; }
    public DateTime CreatedAt { get; set; }
    public string CreatedBy { get; set; }
    public string ChangeType { get; set; } // "manual-edit", "ai-generated", "ai-regenerated"
    public string? Feedback { get; set; } // User feedback that led to regeneration
    public int Version { get; set; }
}

// On every save, create version record
await _versionRepository.CreateVersionAsync(new AnalysisFieldVersion {
    ProjectId = projectId,
    FieldKey = key,
    Content = content,
    CreatedAt = DateTime.UtcNow,
    CreatedBy = userId,
    ChangeType = "manual-edit",
    Version = currentVersion + 1
});
```

**Task 9.2: Version History UI**
```typescript
// src/components/view/FieldHistory.tsx
export function FieldHistory({ projectId, fieldKey }: Props) {
  const { data: versions } = useFieldVersions(projectId, fieldKey)

  return (
    <div className="field-history">
      <Timeline>
        {versions.map(version => (
          <TimelineItem key={version.id} timestamp={version.createdAt}>
            <VersionPreview version={version} />
            <button onClick={() => rollback(version.id)}>
              Restore This Version
            </button>
            <button onClick={() => compareWithCurrent(version.id)}>
              Compare
            </button>
          </TimelineItem>
        ))}
      </Timeline>
    </div>
  )
}
```

**Task 9.3: Diff Viewer**
```typescript
// Show before/after comparison
<DiffViewer
  before={previousVersion.content}
  after={currentVersion.content}
  fieldType={fieldKey}
  renderMode="side-by-side"
/>
```

**Deliverables:**
- ✅ Version storage (SQLite per-project)
- ✅ History timeline UI
- ✅ Rollback functionality
- ✅ Diff viewer component
- ✅ Export version history to CSV

---

### Sprint 19-20: Bulk Operations & Field Bundles

**Task 10.1: Field Bundle Definitions**
```json
// config/field-bundles.json
{
  "bundles": [
    {
      "id": "brand-identity",
      "displayName": { "en": "Brand Identity Bundle" },
      "description": "Complete brand identity setup",
      "fields": [
        "brand-profile",
        "core-values",
        "tone-of-voice",
        "color-scheme",
        "logo",
        "typography"
      ],
      "icon": "sparkles",
      "estimatedTime": "5 minutes"
    },
    {
      "id": "visual-design",
      "displayName": { "en": "Visual Design Bundle" },
      "fields": ["color-scheme", "typography", "logo"],
      "icon": "palette"
    }
  ]
}
```

**Task 10.2: Bulk Generation UI**
```typescript
// src/components/view/BundleGenerator.tsx
export function BundleGenerator({ projectId, bundleId }: Props) {
  const bundle = useBundleDefinition(bundleId)
  const [progress, setProgress] = useState<Record<string, GenerationStatus>>({})

  const generateAll = async () => {
    for (const fieldKey of bundle.fields) {
      setProgress(prev => ({ ...prev, [fieldKey]: 'generating' }))
      try {
        await generateField(projectId, fieldKey)
        setProgress(prev => ({ ...prev, [fieldKey]: 'complete' }))
      } catch (e) {
        setProgress(prev => ({ ...prev, [fieldKey]: 'error' }))
      }
    }
  }

  return (
    <div className="bundle-generator">
      <h2>{bundle.displayName}</h2>
      <p>{bundle.description}</p>

      <ProgressList>
        {bundle.fields.map(fieldKey => (
          <ProgressItem
            key={fieldKey}
            fieldKey={fieldKey}
            status={progress[fieldKey] || 'pending'}
          />
        ))}
      </ProgressList>

      <button onClick={generateAll} disabled={isGenerating}>
        Generate All ({bundle.estimatedTime})
      </button>
    </div>
  )
}
```

**Task 10.3: Multi-Field Export**
```typescript
// Export multiple fields as single PDF/HTML
await exportFieldsToDocument(projectId, {
  fields: ['brand-profile', 'core-values', 'color-scheme'],
  format: 'pdf',
  template: 'brand-guidelines',
  filename: 'Brand Guidelines.pdf'
})
```

**Deliverables:**
- ✅ 5 field bundles defined
- ✅ Bulk generation UI
- ✅ Multi-field export (PDF, HTML, DOCX)
- ✅ Progress tracking for batch operations

---

## Phase 6: Polish & Production (Weeks 21-24) - "Ship It"

### Objective
Final polish, documentation, training, monitoring

### Sprint 21-22: Monitoring & Analytics

**Task 11.1: Field Usage Analytics**
```typescript
// Track field interactions
trackEvent('field_viewed', { projectId, fieldKey })
trackEvent('field_generated', { projectId, fieldKey, model, duration })
trackEvent('field_edited', { projectId, fieldKey, changeType })
trackEvent('field_exported', { projectId, fieldKey, format })
```

**Task 11.2: Analytics Dashboard**
```typescript
// Admin dashboard showing:
- Most generated fields
- Average generation time per field
- AI cost per field type
- Error rates per field
- User satisfaction scores
```

**Task 11.3: Alerts & Monitoring**
```
Alerts:
- Field generation failure rate >5%
- Average generation time >10s
- Cache hit rate <80%
- Validation error rate >2%
```

**Deliverables:**
- ✅ OpenTelemetry integration
- ✅ Analytics dashboard (Grafana)
- ✅ PagerDuty alerts for critical failures
- ✅ Monthly usage reports

---

### Sprint 23-24: Documentation & Training

**Task 12.1: Technical Documentation**
```
Docs to create:
- Architecture overview (diagrams)
- Component template guide (how to create new templates)
- Field creation guide (add new field in 5 steps)
- API reference (all endpoints, schemas)
- Migration guide (v1 → v2)
```

**Task 12.2: User Documentation**
```
User guides:
- "Understanding Analysis Fields" (intro)
- "Editing Fields" (click-to-edit, modals)
- "Using Field Bundles" (bulk generation)
- "Field History & Rollback" (versioning)
- Video tutorials (5min each)
```

**Task 12.3: Developer Onboarding**
```
Dev resources:
- Storybook with all components
- Playwright E2E test suite
- Local development setup guide
- Contributing guidelines
```

**Deliverables:**
- ✅ 15+ documentation pages
- ✅ 5 video tutorials
- ✅ Storybook published
- ✅ E2E test coverage >80%

---

## Success Metrics

### Performance Targets
| Metric | Before | After | Target |
|--------|--------|-------|--------|
| Field load time | 200ms | <100ms | ✅ 50% faster |
| Code bundle size | 2.4MB | <1.8MB | ✅ 25% smaller |
| Cache hit rate | 0% | >80% | ✅ New capability |
| Field addition effort | 5 locations | 1 location | ✅ 80% less work |

### Cost Targets
| Metric | Before | After | Savings |
|--------|--------|-------|---------|
| AI cost per generation | $0.05 | $0.02 | ✅ 60% reduction |
| Server costs (caching) | $0 | +$50/mo | ✅ Net positive ROI |

### UX Targets
| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Clicks to edit field | 3 | 1 | ✅ 67% fewer |
| Time to edit simple field | 15s | 5s | ✅ 67% faster |
| Mobile usability score | 65/100 | 90/100 | ✅ +25 points |
| Accessibility score | 72/100 | 95/100 | ✅ WCAG AA compliant |

### Developer Metrics
| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Lines of code | 8,500 | 5,000 | ✅ 40% reduction |
| Component duplication | High | Low | ✅ DRY principles |
| Test coverage | 45% | 85% | ✅ +40 points |
| Time to add new field | 2 hours | 15 mins | ✅ 88% faster |

---

## Risk Mitigation

### Risk 1: Breaking Changes
**Mitigation:**
- Maintain v1 API alongside v2
- Feature flags for new UI
- Gradual rollout (5% → 25% → 50% → 100%)

### Risk 2: Data Migration Failures
**Mitigation:**
- Automated migration scripts with dry-run mode
- Rollback plan for every migration
- Backup all data before migration

### Risk 3: Performance Regression
**Mitigation:**
- Load testing before each phase
- Performance budgets enforced in CI
- Rollback if metrics degrade >10%

### Risk 4: User Adoption
**Mitigation:**
- User testing after Sprint 12, 20, 24
- Feedback loops every 2 weeks
- Training sessions for power users

---

## Rollout Strategy

### Phase-by-Phase Rollout

**Weeks 1-4 (Foundation):**
- Deploy to dev environment only
- Internal testing with dev team

**Weeks 5-8 (Component Refactor):**
- Deploy to staging
- Alpha testing with 2-3 friendly customers

**Weeks 9-12 (Modal System):**
- Deploy to 10% production (feature flag)
- Gather metrics, iterate

**Weeks 13-16 (Backend Optimization):**
- Deploy to 50% production
- Monitor costs, performance

**Weeks 17-20 (Advanced Features):**
- Deploy to 100% production
- Announce new features

**Weeks 21-24 (Polish):**
- GA (General Availability)
- Marketing campaign

---

## Team Requirements

**Minimum Team:**
- 1 Senior Frontend Engineer (React expert)
- 1 Senior Backend Engineer (C# + .NET)
- 1 UX Designer
- 1 QA Engineer
- 0.5 DevOps Engineer
- 0.25 Technical Writer

**Total:** 4.75 FTE for 6 months

---

## Estimated Total Effort

- **Backend:** 240 hours (6 weeks FTE)
- **Frontend:** 480 hours (12 weeks FTE)
- **Design:** 120 hours (3 weeks FTE)
- **QA:** 160 hours (4 weeks FTE)
- **DevOps:** 80 hours (2 weeks FTE)
- **Docs:** 40 hours (1 week FTE)
- **Total:** 1,120 hours (~28 weeks for 1 person, ~6 months for team)

---

## Conclusion

This incremental plan transforms the analysis field system from hardcoded chaos to template-based elegance over 6 months. Each phase delivers measurable value while maintaining backward compatibility. By Sprint 12, users will have click-to-edit everywhere. By Sprint 16, AI costs drop 60%. By Sprint 24, the system is production-ready, documented, and maintainable.

**Next Step:** Review this plan with stakeholders, adjust timeline/scope, then kick off Phase 1 Sprint 1.
