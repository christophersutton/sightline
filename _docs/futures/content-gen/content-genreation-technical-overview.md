## 1. System Overview

### A. Development Environment

- Runtime: Bun for all local development and processing
- Storage:
  - Local: SQLite via Bun SQLite API
  - Cloud: Firebase Storage for assets, Firebase Realtime DB for production data

- APIs:
  - Perplexity API for content research/generation
  - Firebase APIs for cloud integration
  - Image APIs (TBD) for public image collection

### B. Core Processing Agents

1. Data Collection Agent

```typescript
interface Scraper {
  urls: string[];
  placeId: string;
  async scrape(): Promise<{
    placeData: PlaceData;
    recommendations: Recommendation[];
    images: ImageMetadata[];
  }>;
}

interface PlaceData {
  id: string;
  name: string;
  description: string;
  location: GeoPoint;
  primaryCategories: string[];
  lastUpdated: Date;
}

interface Recommendation {
  placeId: string;
  sourceUrl: string;
  content: string;
  sentiment: number;
  extractedAt: Date;
}
```

2. Content Summarization Agent

```typescript
interface ContentSummarizer {
  placeId: string;
  async generateSummary(): Promise<{
    summary: string;
    keyPoints: string[];
    localTips: string[];
    verifiedFacts: string[];
  }>;
}
```

3. Script Generation Agent

```typescript
interface ScriptGenerator {
  placeId: string;
  async generateScript(): Promise<{
    sections: ScriptSection[];
    requiredVisuals: VisualPrompt[];
    audioNotes: AudioDirection[];
  }>;
}
```

4. Video Production Agent

```typescript
interface VideoProducer {
  script: Script;
  assets: AssetCollection;
  async produce(): Promise<{
    videoUrl: string;
    segments: VideoSegment[];
    metadata: VideoMetadata;
  }>;
}
```

### C. Processing Pipeline

1. Data Collection Phase
   - Scrape configured URLs
   - Extract relevant content
   - Store in local SQLite
   - Download & cache images
   - Quality validation checks

2. Content Processing Phase
   - Generate place summaries
   - Cross-reference facts
   - Create content outline
   - Quality validation loop

3. Production Phase
   - Script generation
   - Asset preparation
   - Video generation
   - Final quality check

### D. Local Development UI

- Simple Bun-served web interface
- Basic CRUD operations
- Pipeline status monitoring
- Quality check interfaces
- Asset preview/management

## 2. Data Schema

```typescript
// Local SQLite Schema
interface Schema {
  places: {
    id: string;
    name: string;
    description: string;
    location: string; // JSON
    created_at: Date;
    updated_at: Date;
  };
  
  recommendations: {
    id: string;
    place_id: string;
    source_url: string;
    content: string;
    extracted_at: Date;
  };
  
  assets: {
    id: string;
    place_id: string;
    type: 'image' | 'video';
    url: string;
    metadata: string; // JSON
    created_at: Date;
  };
  
  scripts: {
    id: string;
    place_id: string;
    content: string; // JSON
    version: number;
    created_at: Date;
  };
}
```

## 3. Implementation Priorities

1. Core Infrastructure
   - Bun project setup
   - SQLite integration
   - Basic Firebase config

2. Data Collection
   - URL scraping system
   - Perplexity API integration
   - Image collection pipeline

3. Content Processing
   - Summary generation
   - Fact verification
   - Script generation

4. Video Production
   - Asset management
   - Video generation integration
   - Quality control system

5. Development UI
   - Basic status dashboard
   - Content preview/edit
   - Pipeline controls
