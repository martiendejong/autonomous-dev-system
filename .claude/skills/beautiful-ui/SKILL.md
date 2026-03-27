---
name: beautiful-ui
description: Generate Lovable.dev quality UIs with systematic design intelligence. Multi-pass generation with design system enforcement, visual hierarchy critique, and production-ready polish. Use when building beautiful, interactive UIs with animations and professional design patterns.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
user-invocable: true
---

# Beautiful UI Skill

Generate professional, production-ready UIs with systematic design intelligence based on patterns from real projects.

## Trigger Keywords
- "beautiful UI"
- "professional design"
- "luxury interface"
- "interactive gallery"
- "animated components"
- "parallax scroll"
- "morphing modal"

## Core Patterns Library

### 1. Parallax Scroll Effects (Curtain/Gordijn Pattern)

**Use case:** Hero section with gallery scrolling over it like a curtain

**Implementation:**
```tsx
// Hero: Fixed position with subtle parallax
<header className="fixed inset-0 overflow-hidden">
  <motion.div style={{ y: heroContentY }}>
    {/* Content moves -30 to -50px over scroll range */}
  </motion.div>
</header>

// Spacer for scroll
<div className="h-screen" />

// Gallery: Scrolls over hero like curtain
<div className="sticky top-0 z-30 bg-black">
  {/* Solid background - no transparency */}
</div>

// Parallax setup
const { scrollYProgress } = useScroll()
const heroContentY = useTransform(scrollYProgress, [0, 0.5], [0, -50])
```

**Key principles:**
- Hero: `fixed` with `overflow: hidden` (creates mask)
- Content: Subtle parallax (-30 to -50px max)
- Curtain: Solid gradient backgrounds
- Spacer: Allows scrolling

**Color opacity:**
- Background media: 0.25 (visible but not distracting)
- Floating elements: 0.35 (prominent)
- Curtain: solid gradients (black/70 → black/85)

---

### 2. Video + Image Integration

**Use case:** Background media rotation with mixed content types

**Implementation:**
```tsx
// Media items with type discriminator
const backgroundMedia = useMemo(() => {
  const media: Array<{ type: 'video' | 'image', src: string }> = []

  media.push({ type: 'video', src: '/banner-video.mp4' })

  uniqueImages.forEach(img => {
    media.push({ type: 'image', src: img })
  })

  return media
}, [uniqueImages])

// Conditional rendering
<AnimatePresence mode="wait">
  <motion.div key={mediaIndex}>
    {media[mediaIndex]?.type === 'video' ? (
      <video
        autoPlay
        loop
        muted
        playsInline
        className="w-full h-full object-cover"
        src={media[mediaIndex].src}
      />
    ) : (
      <div
        style={{
          backgroundImage: `url(${media[mediaIndex]?.src})`,
          backgroundSize: 'cover',
          backgroundPosition: 'center',
        }}
      />
    )}
  </motion.div>
</AnimatePresence>
```

**Critical attributes for video:**
- `autoPlay` - Start automatically
- `loop` - Continuous playback
- `muted` - Required for autoPlay
- `playsInline` - Mobile compatibility

**Animation timing:**
- Media rotation: 6 seconds per item
- Transition: 0.3s fade

---

### 3. Interactive Detail Cards Pattern

**Use case:** Cards with hover preview and click-to-detail view

**Three-state interaction model:**
1. **Hover:** Preview (image changes, no commitment)
2. **Click:** Select and navigate to detail view
3. **Detail view:** Full page with long-form content

**Implementation:**
```tsx
// State management
const [selectedSection, setSelectedSection] = useState(0)
const [hoveredSection, setHoveredSection] = useState<number | null>(null)
const [isDetailViewOpen, setIsDetailViewOpen] = useState(false)

// Content structure
const sections = [
  {
    title: 'Overview',
    icon: <Icon />,
    image: '/image1.jpg',
    content: 'Short preview',
    longContent: 'Full detailed text...'
  }
]

// Card with hover/click
<button
  onClick={() => {
    setSelectedSection(index)
    setIsDetailViewOpen(true)
  }}
  onMouseEnter={() => setHoveredSection(index)}
  onMouseLeave={() => setHoveredSection(null)}
  className={selectedSection === index ? 'active' : ''}
>
  {/* Active indicator */}
  {selectedSection === index && (
    <motion.div layoutId="activeSection" className="indicator" />
  )}

  {/* Card content */}
</button>

// Dynamic image (left side)
<AnimatePresence mode="wait">
  <motion.img
    key={hoveredSection ?? selectedSection}
    src={sections[hoveredSection ?? selectedSection]?.image}
  />
</AnimatePresence>

// Detail view with back button
{isDetailViewOpen && (
  <div>
    <button onClick={() => setIsDetailViewOpen(false)}>
      <ChevronLeft /> Back to Overview
    </button>
    <p>{sections[selectedSection]?.longContent}</p>
  </div>
)}
```

**Key principles:**
- Hover = Preview (reversible)
- Click = Commit (locked state)
- Back = Return to overview
- X = Exit completely
- Always keep close button visible (z-index)

---

### 4. Morphing Modal Pattern

**Use case:** Gallery card smoothly morphs into fullscreen modal

**Implementation:**
```tsx
// Gallery card
<motion.div
  layoutId={`card-${item.id}`}
  animate={{
    opacity: isSelected ? 0 : 1,  // Hide when selected
    scale: isSelected ? 0.95 : 1
  }}
  style={{ pointerEvents: isSelected ? 'none' : 'auto' }}
  onClick={() => setSelectedItem(item)}
>
  {/* Card content */}
</motion.div>

// Modal shares layoutId
<AnimatePresence mode="wait">
  {selectedItem && (
    <motion.div
      layoutId={`card-${selectedItem.id}`}
      className="fixed inset-0 z-50"
      transition={{
        type: "spring",
        stiffness: 300,
        damping: 30
      }}
    >
      {/* Modal content */}
    </motion.div>
  )}
</AnimatePresence>
```

**Critical points:**
- Same `layoutId` for morphing
- Card becomes `opacity: 0` when selected
- Card stays in DOM (prevents disappear/reappear)
- `pointerEvents: none` disables interaction
- Spring physics for smooth morphing

---

### 5. Highlighted Active State Pattern

**Use case:** Show selected item with gold border and animated indicator

**Implementation:**
```tsx
<button className={`
  ${isActive
    ? 'bg-gradient-to-r from-gold/20 to-yellow/10 border-gold shadow-gold/30'
    : 'bg-navy/20 border-gold/20 hover:border-gold/60'
  }
`}>
  {/* Animated left border indicator */}
  {isActive && (
    <motion.div
      layoutId="activeSection"
      className="absolute left-0 top-0 bottom-0 w-1 bg-gradient-to-b from-gold to-yellow rounded-l-2xl"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
    />
  )}

  {/* Icon changes color */}
  <div className={`p-3 rounded-xl ${
    isActive ? 'bg-gold text-black' : 'bg-navy/60 text-gold'
  }`}>
    {icon}
  </div>

  {/* Text transitions */}
  <h3 className={isActive ? 'text-gold' : 'text-cream/80'}>
    {title}
  </h3>

  {/* Chevron translates on hover/selection */}
  <ChevronRight className={`${
    isActive ? 'text-gold translate-x-2' : 'text-gold/40'
  }`} />
</button>
```

**Visual feedback:**
- Left vertical line (animated with layoutId)
- Gold border
- Icon background color change
- Text color transition
- Chevron translation

---

### 6. Long-form Content Architecture

**Use case:** Short preview with expandable long-form content

**Implementation:**
```tsx
// Data structure
const sections = [
  {
    title: 'Overview',
    content: 'Short preview for cards',
    longContent: `Full detailed text...

    Second paragraph...

    Third paragraph...`
  }
]

// Split and animate paragraphs
{sections[selected]?.longContent
  .split('\n\n')
  .map((paragraph, idx) => (
    <motion.p
      key={idx}
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.6 + idx * 0.1 }}
      className="text-cream/90 leading-relaxed mb-6"
    >
      {paragraph}
    </motion.p>
  ))
}
```

**Stagger timing:**
- Base delay: 0.6s
- Per-paragraph: +0.1s
- Creates smooth reveal

---

### 7. Animation Timing System

**Performance hierarchy:**
- **Instant:** Hover feedback (0ms)
- **Quick:** State changes (200-300ms)
- **Standard:** Transitions (400-500ms)
- **Slow:** Parallax (full scroll range)
- **Very slow:** Media rotation (6000ms)

**Stagger delays:**
```tsx
// Cards appearing
transition={{ delay: index * 0.08 }}

// Paragraphs revealing
transition={{ delay: 0.6 + idx * 0.1 }}

// Multi-element entrance
crown: 0.5s
badge: 0.6s
title: 0.7s
content: 0.9s
```

---

### 8. Code Quality Patterns

**Variable declaration order:**
```tsx
// ❌ Wrong - useEffect uses variable declared later
useEffect(() => {
  setIndex(prev => (prev + 1) % allImages.length)
}, [allImages])

const allImages = useMemo(...)  // Declared after useEffect!

// ✅ Correct - declare before use
const allImages = useMemo(...)

useEffect(() => {
  setIndex(prev => (prev + 1) % allImages.length)
}, [allImages])
```

**Use useMemo for derived state:**
```tsx
// Unique images from collection
const allUniqueImages = useMemo(() => {
  const imageSet = new Set<string>()
  data.forEach(item => {
    if (item.gallery) {
      item.gallery.forEach(img => imageSet.add(img))
    } else {
      imageSet.add(item.image)
    }
  })
  return Array.from(imageSet)
}, [])  // Empty deps - compute once
```

**Type discriminators for polymorphic data:**
```tsx
type MediaItem =
  | { type: 'video', src: string }
  | { type: 'image', src: string }

// Type-safe rendering
{media.type === 'video' ? (
  <video src={media.src} />
) : (
  <img src={media.src} />
)}
```

---

## Design System Guidelines

### Color Palette (Luxury Theme)
```tsx
const colors = {
  gold: '#D4AF37',      // Primary accent
  silver: '#C0C0C0',    // Secondary accent
  navy: '#0A1628',      // Dark background
  cream: '#F5F5DC',     // Text
  black: '#000000',     // Pure black
}

// Opacity ranges
background: 'opacity-25',     // 0.25
floating: 'opacity-35',       // 0.35
curtain: 'black/70',          // 0.70-0.85
```

### Typography
```tsx
// Display (headings)
font-display text-9xl font-black

// Body
font-sans text-xl font-light

// Labels
text-sm uppercase tracking-[0.3em]
```

### Spacing System
```tsx
gap-3    // 12px - Tight
gap-6    // 24px - Standard
gap-16   // 64px - Generous
px-16    // 64px - Container padding
py-32    // 128px - Section padding
```

---

## Best Practices Checklist

### Navigation & UX
- [ ] Close/exit button always visible (high z-index)
- [ ] Back button for nested views
- [ ] Breadcrumb navigation for context
- [ ] Hover = Preview (reversible)
- [ ] Click = Commit (locked state)

### Performance
- [ ] Use `opacity` for show/hide (not `display`)
- [ ] Stagger animations for perceived performance
- [ ] `useMemo` for expensive computations
- [ ] Proper dependency arrays
- [ ] `AnimatePresence mode="wait"` for sequential

### Accessibility
- [ ] Focus states (`focus-visible`)
- [ ] Keyboard navigation
- [ ] ARIA labels where needed
- [ ] Contrast ratios (WCAG AA)

### Code Quality
- [ ] Declare variables before use
- [ ] Type discriminators for polymorphic data
- [ ] Unique keys for lists
- [ ] Test with unique data sets (use `Set`)
- [ ] Videos have proper attributes

---

## Common Pitfalls

### ❌ Avoid
```tsx
// Variable used before declaration
useEffect(() => data.length, [data])
const data = useMemo(...)

// Display for show/hide (causes layout shift)
style={{ display: isOpen ? 'block' : 'none' }}

// Missing video attributes
<video src="/video.mp4" />  // Won't autoplay

// Duplicate images in rotation
images.concat(images)  // Use Set instead
```

### ✅ Prefer
```tsx
// Declare before use
const data = useMemo(...)
useEffect(() => data.length, [data])

// Opacity for show/hide (smooth)
style={{ opacity: isOpen ? 1 : 0 }}

// Complete video attributes
<video autoPlay loop muted playsInline src="/video.mp4" />

// Unique images only
const unique = Array.from(new Set(images))
```

---

## Git Workflow for UI Projects

### Commit Message Format
```
feat: <Brief description>

<Detailed explanation>
- Feature 1
- Feature 2
- Feature 3

Implementation details:
- Pattern used
- Animation timing
- Interaction model

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

### Example
```
feat: Add interactive detail view with parallax

- Clickable detail cards with hover preview
- Detail view page with long-form content
- Back button navigation
- Dynamic image switching based on hover/click

Implementation:
- Three-state interaction: hover → click → detail view
- Staggered paragraph animations (0.1s delay)
- Persistent close button (z-50)
- Smooth transitions (0.3-0.4s)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

---

## Pattern Index

1. **Parallax Scroll** - Curtain effect over fixed hero
2. **Video Integration** - Mixed media with type discriminators
3. **Detail Cards** - Hover preview, click to detail
4. **Morphing Modal** - Shared layoutId transitions
5. **Active Highlighting** - Animated indicators
6. **Long-form Content** - Expandable text with stagger
7. **Animation Timing** - Performance hierarchy
8. **Code Quality** - useMemo, proper deps, types

---

## Success Criteria

UI is production-ready when:
- ✅ Smooth 60fps animations
- ✅ Clear interaction feedback (hover, click, active)
- ✅ Proper navigation (back, close, breadcrumbs)
- ✅ Accessible (keyboard, focus, ARIA)
- ✅ Type-safe (discriminators, proper types)
- ✅ Performant (memoization, proper deps)
- ✅ Documented (clear commit messages)
- ✅ Tested (edge cases, unique data)

---

**Last Updated:** 2026-03-09
**Based on:** Perridon Collection project (luxury automotive gallery)
**Maintained by:** Claude Agent (Self-improving skill)
