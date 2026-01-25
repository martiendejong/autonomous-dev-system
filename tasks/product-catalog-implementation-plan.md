# Product Catalog Implementation Plan

## Overview
Implement comprehensive product catalog management for Brand2Boost with multi-platform import, manual management, and AI integration.

## User Requirements
- **Scope**: All features (Manual CRUD, WooCommerce, other platforms, AI content generation)
- **Data Model**: Per project (each Brand2Boost project has own catalog)
- **Use Cases**: Content generation, E-commerce sync, Product knowledge base

## Architecture Design

### 1. Database Models

```csharp
// Models/ProductCatalog/Product.cs
public class Product
{
    public int Id { get; set; }
    public string ProjectId { get; set; }  // Link to Brand2Boost project
    public string ExternalId { get; set; } // WooCommerce/Shopify product ID
    public string Platform { get; set; }   // "woocommerce", "shopify", "manual", etc.

    // Basic Info
    public string Name { get; set; }
    public string Slug { get; set; }
    public string SKU { get; set; }
    public string Description { get; set; }
    public string ShortDescription { get; set; }

    // Pricing
    public decimal? RegularPrice { get; set; }
    public decimal? SalePrice { get; set; }
    public string Currency { get; set; }

    // Inventory
    public bool InStock { get; set; }
    public int? StockQuantity { get; set; }
    public bool ManageStock { get; set; }

    // Media
    public string MainImageUrl { get; set; }
    public List<ProductImage> Images { get; set; }

    // Organization
    public List<ProductCategory> Categories { get; set; }
    public List<ProductTag> Tags { get; set; }
    public List<ProductAttribute> Attributes { get; set; }

    // SEO
    public string MetaTitle { get; set; }
    public string MetaDescription { get; set; }

    // Timestamps
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? LastSyncedAt { get; set; }

    // External URL
    public string ProductUrl { get; set; }

    // Status
    public string Status { get; set; } // "publish", "draft", "private"

    // AI-Generated Content (optional, can be regenerated)
    public string AiGeneratedCopy { get; set; }
    public DateTime? AiContentGeneratedAt { get; set; }
}

public class ProductImage
{
    public int Id { get; set; }
    public int ProductId { get; set; }
    public string Url { get; set; }
    public string Alt { get; set; }
    public int Position { get; set; }
}

public class ProductCategory
{
    public int Id { get; set; }
    public int ProductId { get; set; }
    public string Name { get; set; }
    public string Slug { get; set; }
    public int? ParentId { get; set; }
}

public class ProductTag
{
    public int Id { get; set; }
    public int ProductId { get; set; }
    public string Name { get; set; }
    public string Slug { get; set; }
}

public class ProductAttribute
{
    public int Id { get; set; }
    public int ProductId { get; set; }
    public string Name { get; set; }
    public string Value { get; set; }
    public bool IsVariation { get; set; }
}

// Integration Settings
public class ProductIntegration
{
    public int Id { get; set; }
    public string ProjectId { get; set; }
    public string Platform { get; set; } // "woocommerce", "shopify", "magento"

    // Connection
    public string StoreUrl { get; set; }
    public string ApiKey { get; set; }
    public string ApiSecret { get; set; }
    public string ConsumerKey { get; set; }    // WooCommerce
    public string ConsumerSecret { get; set; } // WooCommerce

    // Sync Settings
    public bool AutoSync { get; set; }
    public int SyncIntervalMinutes { get; set; }
    public DateTime? LastSyncedAt { get; set; }
    public string LastSyncStatus { get; set; }

    // Filters
    public string CategoryFilter { get; set; } // JSON array of category IDs to sync
    public bool SyncOnlyInStock { get; set; }

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
```

### 2. API Endpoints

```
Product CRUD:
POST   /api/products                    - Create product
GET    /api/products                    - List products (with filtering)
GET    /api/products/{id}               - Get product details
PUT    /api/products/{id}               - Update product
DELETE /api/products/{id}               - Delete product

Integration:
POST   /api/products/integrations       - Add integration
GET    /api/products/integrations       - List integrations
PUT    /api/products/integrations/{id}  - Update integration
DELETE /api/products/integrations/{id}  - Delete integration
POST   /api/products/sync/{integrationId} - Trigger manual sync
GET    /api/products/sync-status/{id}   - Get sync status

WooCommerce Specific:
POST   /api/products/woocommerce/test-connection - Test WooCommerce connection
GET    /api/products/woocommerce/categories     - Get WooCommerce categories
GET    /api/products/woocommerce/preview        - Preview products before import

AI Content:
POST   /api/products/{id}/generate-content - Generate AI marketing copy
POST   /api/products/batch-generate        - Batch generate for multiple products
```

### 3. Services

```csharp
// Services/ProductCatalog/ProductService.cs
- CRUD operations
- Filtering, searching, pagination
- Category/tag management

// Services/ProductCatalog/WooCommerceService.cs
- Connect to WooCommerce REST API
- Import products
- Sync product updates
- Handle pagination (WooCommerce API returns 100 items per page)

// Services/ProductCatalog/ShopifyService.cs
- Shopify Admin API integration

// Services/ProductCatalog/ProductSyncService.cs
- Background sync coordination
- Conflict resolution
- Sync status tracking

// Services/ProductCatalog/ProductAIService.cs
- Generate marketing copy from product data
- Generate social media posts
- SEO optimization
- Inject product knowledge into chat context
```

### 4. Frontend Components

```
ProductCatalog/
├── ProductList.tsx           - Main catalog view with grid/list
├── ProductDetail.tsx         - Single product view/edit
├── ProductForm.tsx           - Add/Edit product form
├── ProductImport.tsx         - Import wizard
├── IntegrationSetup.tsx      - Connect WooCommerce/Shopify
├── SyncStatus.tsx            - Sync progress indicator
├── ProductSelector.tsx       - Select products for content generation
└── ProductKnowledgePanel.tsx - Show products in chat context
```

## Implementation Phases

### Phase 1: Core Infrastructure (2-3 hours)
1. Database models + migrations
2. Basic ProductController + ProductService
3. Product CRUD endpoints
4. Basic frontend list/detail views

### Phase 2: WooCommerce Integration (3-4 hours)
1. WooCommerceService implementation
2. Connection testing endpoint
3. Product import (initial + incremental sync)
4. Integration settings UI
5. Sync status tracking

### Phase 3: Manual Management UI (2-3 hours)
1. Product form with image upload
2. Category/tag management
3. Bulk operations
4. Search and filtering

### Phase 4: AI Integration (2-3 hours)
1. ProductAIService
2. Generate content from product data
3. Inject products into chat context
4. Product-aware content suggestions

### Phase 5: Additional Platforms (3-4 hours)
1. Shopify integration
2. Generic REST API connector
3. CSV import/export

### Phase 6: Advanced Features (2-3 hours)
1. Background sync jobs (Hangfire)
2. Webhook support (product updates from store)
3. Product variations support
4. Multi-currency handling

## Technical Considerations

### WooCommerce REST API
- Base URL: `{store}/wp-json/wc/v3/products`
- Authentication: Consumer Key/Secret (OAuth1)
- Pagination: 100 items per page max
- Rate limiting: Typically 3000 requests/hour

### Data Storage
- SQLite database (existing IdentityDbContext)
- Store images: URLs only (not blob storage)
- Large catalogs: Implement pagination + search indexes

### AI Integration Points
1. **Chat Context**: Inject product catalog into system prompt
2. **Content Generation**: Use product details to generate posts
3. **Product Q&A**: Answer questions about products from catalog
4. **Marketing Copy**: Generate descriptions, taglines, USPs

### Security
- Encrypt API keys/secrets in database
- Validate external URLs
- Sanitize imported HTML descriptions
- Rate limit sync operations

## Success Criteria

1. ✅ User can manually add/edit products
2. ✅ User can connect WooCommerce store
3. ✅ Products auto-sync from WooCommerce
4. ✅ AI can generate content using product data
5. ✅ AI chat has access to product catalog
6. ✅ Support for 1000+ product catalogs
7. ✅ Sync completes in <5 minutes for 500 products

## Next Steps

**Decision Required:**
1. Start with Phase 1 (core infrastructure)?
2. Or show detailed technical design first?
3. Use worktree workflow for implementation?
