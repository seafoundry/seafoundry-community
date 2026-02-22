# SeaFoundry Community Edition (OSS)

SeaFoundry Community Edition is a free, open-source web platform for marine restoration, creating a standard for inventory management and genetics tracking available to any practitioner.

## Features (Community)

*   **Inventory & Husbandry**: Track organism holdings, fragmentation, and movements (Gene Bank, Nursery).
*   **Genetics & Lineage**: Manage sexual cohorts, wild collections, and parental lineage.
*   **Basic Monitoring**: Record environmental parameters (temperature, salinity, etc.) and observations for outplanted sites.
*   **Restoration Sites**: Create up to **5** outplanting/restoration sites to manage field operations.
*   **Maps**: Visualize your sites and holdings on an interactive map.
*   **Data Portability**: Full CSV import/export capabilities (compatible with SeaFoundry ecosystem).

## Limitations

This is the fully open-source Community build. Advanced features are available in **Pro** and **Scale** tiers:
*   **Unlimited Sites** (Community limited to 1 nursery + 5 outplanting sites)
*   **Photo Monitoring** (Image uploads/attachmnets)
*   **Mobile App** (Offline sync, field mode)
*   **Advanced Reporting** (Project deliverables, automated reports)
*   **Team Management** (Role-based access, workforce tracking)
*   **AI Tools** (Copilot, automated analysis)

## Getting Started

1.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```
2.  **Run Development Server**:
    ```bash
    flutter run -d chrome
    ```

## Architecture

This build uses the same core architecture as the full platform but is configured for the **Community** tier by default.
*   **Tier Source**: Main feature gating is handled via `FeatureAccessService` and `config/tier_features.yaml`.
*   **Services**: Uses standard Firestore repositories for data persistence.

## Community & Support

*   **Issues**: Please file issues in this repository for bugs or feature requests.
*   **Contributions**: We welcome PRs! Please see `CONTRIBUTING.md`.

---
*Generated Community Build*
