# Sightline App Overview

## Vision
Sightline transforms urban exploration through a gamified "treasure hunt" experience where users:
- Unlock location-based content by discovering landmarks
- Build a crowdsourced knowledge base through video contributions
- Earn access to premium features via content creation
- Access curated city guides ("Treasure Maps") with optimal exploration routes

## Architecture Overview
- **Frontend:**  
  - **Platform:** iOS  
  - **Language/Framework:** Swift Native (chosen for superior camera integration, real-time performance, and native UI components).
- **Backend:**  
  - **Platform:** Firebase  
  - **Services:**  
    - Authentication (starting with anonymous sessions and upgrading to full user accounts)
    - Real-time data synchronization
    - Cloud Functions supporting AI integrations for content categorization and moderation

- **Monorepo Organization:**  
  - `/ios` – Contains the Swift native iOS project.
  - `/firebase` – Contains Firebase Cloud Functions, authentication configurations, and other backend setups.
  - `/content-gen` – Bun-powered service for:
    - AI video processing pipelines
    - Treasure map generation algorithms
    - Reward system automation

## Key Features for MVP & Beyond
- **Gamified Discovery Engine:**
  - Landmark detection unlocks local video feeds
  - Progressive access system (landmark → district → city)
  - "Treasure Map" guided tours 

- **User-Generated Content Ecosystem:**
  - Contribution rewards system:
    - 1 quality video → Unlock nearby landmarks
    - 3 videos → District access
    - 5 videos → Full city unlock
  - AI-powered quality assessment and moderation

- **Monetization Infrastructure:**
  - Freemium model with premium city guides
  - Tiered access through:
    - Direct purchases
    - Content contributions
    - Community participation

## Roadmap
- **MVP (2 Weeks):**
  - Implement core discovery features and the landmark-triggered video feed.
  - Set up Firebase backend for authentication, real-time sync, and server-side processing via Cloud Functions.
  - Implement user video recording / review recording
  - Integrate AI services for content categorization and basic content moderation.
  
- **Phase 2 (Next 6 Months):**
  - Implement treasure map marketplace
  - Develop AR route guidance
  - Launch contributor reward programs
  - Introduce premium subscription tiers

- **Long-Term Vision:**
  - Crowdsourced city reputation system
  - Local business partnerships via promoted content
  - Cross-city exploration challenges
  - Advanced AI features:
    - Predictive content recommendations
    - Dynamic difficulty adjustment for treasure hunts
    - Multi-landmark combo rewards