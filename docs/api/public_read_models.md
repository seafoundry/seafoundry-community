# Public Read Models – Schema

Canonical JSON fields used by client + Functions for Visual Engagement.
Mirrored copies of `brand_profiles`/`media_assets` live under `public_orgs/{organizationId}` so the experience surfaces can read organization-specific data without auth.

## BrandProfile (`brand_profiles` → `public_orgs/{orgId}/brand_profiles`)
- id: string
- organizationId: string
- brandName: string
- logoUrl?: string
- heroImageUrl?: string
- accentColor?: string (hex, e.g., #00AEEF)
- kioskEnabled: boolean
- published: boolean
- publishedAt?: ISO8601 string
- createdAt/createdById/updatedAt/updatedById

> Use `PublicReadModelsService.streamBrandProfile` to keep the hero/theme rails synchronized with the mirrored brand profile document.

## MediaAsset (`media_assets` → `public_orgs/{orgId}/media`)
- id: string
- organizationId: string
- url: string
- assetType: "image" | "video"
- width?: number
- height?: number
- durationSeconds?: number
- altText?: string
- attribution?: string
- tags: string[]
- published: boolean
- publishedAt?: ISO8601 string
- createdAt/createdById/updatedAt/updatedById

## PublicPlaylist (`public_playlists` → `public_orgs/{orgId}/playlists`)
- id: string
- organizationId: string
- title: string
- description?: string
- items: Array<{ assetId: string, caption?: string, order: number }>
- published: boolean
- publishedAt?: ISO8601 string
- createdAt/createdById/updatedAt/updatedById

## PublicDigest (`public_digests` → `public_orgs/{orgId}/digests`)
- id: string
- organizationId: string
- weekOf: ISO8601 date (YYYY-MM-DD)
- highlightAssetIds: string[]
- summary?: string
- metrics?: { exposures: number, taps: number, shares: number, followClicks: number, qrScans: number }
- published: boolean
- publishedAt?: ISO8601 string
- createdAt/createdById/updatedAt/updatedById

## PublicImpactPoint (`public_orgs/{orgId}/impact_points`)
- id: string
- organizationId: string
- siteId?: string (source site identifier)
- latitude: number (sanitized centroid)
- longitude: number (sanitized centroid)
- pointType: "holding" | "outplant"
- magnitude: integer (aggregated quantity)
- label?: string (optional callout used in impact map legend)
- genetBreakdown?: { [genetId: string]: number } (optional, aggregated counts)
- provenanceIdBreakdown?: { [provenanceId: string]: number } (optional, aggregated counts)
- speciesBreakdown?: { [speciesId: string]: number } (optional, aggregated counts)
- createdAt/createdById/updatedAt/updatedById
