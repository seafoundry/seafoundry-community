# SeaFoundry Community Edition (OSS)

SeaFoundry Community Edition is a free, open-source web platform for coral restoration, providing a standard for inventory management and genetics tracking available to any practitioner.

## Features

*   **Coral Inventory**: Track coral holdings, fragmentation, and movements across nursery sites.
*   **Genetics & Lineage**: Manage genets, provenance chains, and fragmentation lineage.
*   **Outplanting**: Record where and when corals are outplanted to restoration sites.
*   **Transfers**: Log external transfers (sending/receiving organisms to/from other organizations).
*   **Public Holdings Map**: Visualize your sites and holdings on an interactive map.
*   **Data Portability**: Full CSV import/export capabilities.

## Site Limits

Community Edition supports 1 nursery site and 1 outplanting site per organization.

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

This build uses Flutter with Firestore for data persistence.
*   **Feature Gating**: Community-only constraints are enforced via `Tier` normalization and targeted guards (for example, `SiteLimitsService`).
*   **Services**: Uses standard Firestore repositories for data persistence.

## Community & Support

*   **Issues**: Please file issues in this repository for bugs or feature requests.
*   **Contributions**: We welcome PRs! Please see `CONTRIBUTING.md`.
