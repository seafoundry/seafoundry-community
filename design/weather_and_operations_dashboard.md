# Weather & Operations Dashboard Proposal

## Overview
This proposal outlines the design for a new "Home Screen" for organizations in SeaFoundry. The goal is to transform the current list-based view into an operational dashboard that integrates real-time environmental data, logistical planning, and spatial visualization.

## 1. New Home Screen Layout (`OrganizationDashboardScreen`)

The `OrganizationNodeScreen` will be evolved into a dashboard layout with three main sections:

### A. Interactive Map Dashboard (Top / Primary View)
*   **Component:** `OrgMapDashboard` (Evolution of `PublicHoldingsMapScreen`)
*   **Features:**
    *   **Private Data Layer:** Shows all organization sites (Nurseries & Outplant sites) with real-time status indicators.
    *   **Weather Overlays:** Toggleable layers for:
        *   **Sea Surface Temperature (SST):** Heatmap overlay.
        *   **Wind & Waves:** Vector fields or directional arrows.
        *   **Currents:** Flow lines.
    *   **Connectivity:** Visual lines indicating modeled reef connectivity (larval dispersal paths).
    *   **Interactive Pins:** Clicking a site shows a summary card with current conditions and "Work Window" status.

### B. Work Window Forecaster (Middle Section)
*   **Component:** `WorkWindowWidget`
*   **Function:** Suggests optimal times for field operations based on combined criteria.
*   **UI:**
    *   **Calendar/Timeline View:** Color-coded days/hours (Green = Go, Yellow = Caution, Red = No Go).
    *   **Criteria Selector:** "Plan for: Outplanting" vs "Plan for: Monitoring".
        *   *Outplanting:* Low wave height, low wind, moderate current.
        *   *Monitoring:* Clear visibility (low turbidity), calm surface.
    *   **Forecast:** 7-14 day lookahead using weather API data.

### C. Logistics & Environmental Timeline (Bottom Section)
*   **Component:** `OperationsTimeline`
*   **Features:**
    *   **Deliverables:** Upcoming due dates for reports, grant milestones, or production quotas.
    *   **Field Ops:** Scheduled boat days or dive team deployments.
    *   **Environmental Events:** Historical and active markers for:
        *   Bleaching events (user-reported + satellite alerts).
        *   Disease outbreaks.
        *   Run-off events (rain gauge data).
    *   **Correlation:** Visually align environmental events with reef health data to see cause-and-effect.

---

## 2. Data Models

### Environmental Models
```dart
enum EnvironmentalFactor { wind, waveHeight, current, temperature, turbidity }

class WeatherCondition {
  final DateTime timestamp;
  final double windSpeedKnots;
  final double waveHeightMeters;
  final double seaSurfaceTempC;
  final double currentSpeedKnots;
  // ... other factors
}

class EnvironmentalEvent {
  final String id;
  final String type; // 'bleaching', 'disease', 'runoff', 'storm'
  final DateTime startDate;
  final DateTime? endDate;
  final String severity; // 'low', 'medium', 'high', 'critical'
  final String source; // 'user_report', 'satellite', 'news'
  final String? description;
  final List<String> affectedSiteIds;
}
```

### Operational Models
```dart
class WorkWindow {
  final DateTime start;
  final DateTime end;
  final double suitabilityScore; // 0.0 to 1.0
  final Map<EnvironmentalFactor, String> constraints; // e.g., {wind: 'Too high'}
}

class Deliverable {
  final String id;
  final String title;
  final DateTime dueDate;
  final String type; // 'report', 'production', 'field_work'
  final bool isCompleted;
}
```

---

## 3. Services Architecture

### `WeatherService`
*   **Responsibility:** Fetch and cache weather data from external APIs (e.g., NOAA, OpenWeatherMap, Marine weather providers).
*   **Methods:**
    *   `getCurrentConditions(LatLng location)`
    *   `getForecast(LatLng location, Duration period)`

### `ForecastingService`
*   **Responsibility:** Analyze weather data against operational constraints to identify "Work Windows".
*   **Logic:**
    *   Configurable thresholds (e.g., "Max Wave Height for Outplanting = 1.5m").
    *   Returns a list of `WorkWindow` objects.

### `EnvironmentalMonitoringService`
*   **Responsibility:** Manage `EnvironmentalEvent` records.
*   **Sources:**
    *   User input (via "Add Event" dialog).
    *   Automated ingestion (optional future: satellite bleaching alerts).

---

## 4. User Experience (UX) Flow

1.  **Login:** User lands on the new **Organization Dashboard**.
2.  **At a Glance:**
    *   Map shows the org's sites.
    *   "Traffic Light" status on the map indicates if *today* is a good work day at each site.
3.  **Planning:**
    *   User clicks "Plan Field Ops".
    *   `WorkWindowWidget` expands.
    *   User selects "Outplanting".
    *   Calendar highlights next Tuesday and Wednesday as "Green" (Good conditions).
4.  **Contextualizing:**
    *   User scrolls to `OperationsTimeline`.
    *   Notices a "High Temp / Bleaching Risk" warning for next month.
    *   Decides to schedule a "Monitoring" dive during the "Green" window to establish a baseline before the heatwave.
5.  **Action:**
    *   User creates a `ScheduledEvent` (new model) for the dive, linking it to the site and the team.

## 5. Implementation Phases

1.  **Phase 1: Foundation**
    *   Create `WeatherService` and basic `WeatherCondition` models.
    *   Implement `OrgMapDashboard` (private map view).
    *   Display current weather on the map.

2.  **Phase 2: Forecasting**
    *   Implement `ForecastingService` and logic.
    *   Build `WorkWindowWidget` UI.

3.  **Phase 3: Environmental Tracking**
    *   Create `EnvironmentalEvent` models and repository.
    *   Build `OperationsTimeline` UI.
    *   Allow users to manually log environmental events.

4.  **Phase 4: Integration**
    *   Connect Deliverables/Tasks to the timeline.
    *   Advanced map layers (connectivity, heatmaps).

## 6. Activity Feed & Social Media Integration

### A. Activity Feed
*   **Component:** `ActivityFeedWidget`
*   **Location:** Integrated into the Dashboard (likely sidebar or dedicated tab) and Public Organization Page.
*   **Content:**
    *   **Nursery Updates:** Automated events from nursery feeds (e.g., "New batch of 500 Acropora cervicornis outplanted").
    *   **News & Mentions:** Posts that tag the organization or relevant news articles.
    *   **Social Media:** Aggregated posts from linked social media accounts.

### B. Social Media Links
*   **Integration:** Added to `BrandProfile` and managed via the Brand Setup Dialog.
*   **Supported Platforms:** Facebook, Instagram, Twitter/X, LinkedIn, YouTube.
*   **Display:** Icons in the Organization Header and Public Page footer.

