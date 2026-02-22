# Payment Integration Guide for SeaFoundry

## Purpose

Define a pragmatic, low-cost path to sell Pro/Scale upgrades while keeping the current license+feature flag model (`FeatureAccessService`, `config/tier_features.yaml`, `UpgradeCta`) and remaining compliant with App Store / Play policies. Full Stripe integration is not live yet; Community upgrades route to a beta waitlist form.

## Current context

- Tiers: Community (free), Pro, Scale. Community upgrade CTAs currently point to a beta waitlist email form (`config/tier_features.yaml`).
- License & entitlements: `FeatureAccessService` already consumes `organization.tier` / `organization.plan` and optional `organization.license` overrides (tier, expiresAt, feature booleans, signature).
- Backend: Firebase (Firestore, Functions, Auth). No payments or billing metadata in Firestore today.

## Options (researched)

| Option | Notes | Flutter effort | Fees (US baseline) | Fit |
| --- | --- | --- | --- | --- |
| Stripe Billing (Checkout + Customer Portal) | Best-documented, PCI scope minimized, supports subscriptions + invoices; use `flutter_stripe` only if doing in-app cards; hosted Checkout works everywhere. | Low/med (server + minimal UI) | 2.9% + $0.30; +1% for international/currency conversion | ✅ Recommended |
| Stripe Payment Links | Zero-code start; limited branding/control; still Stripe-hosted. | Low | Same as above | ✅ Fastest MVP |
| Firebase Extension (Stripe Payments) | Automates webhooks & customer creation; less flexible for custom entitlements/metadata. | Low/med | Stripe fees + Functions runtime | ⚠️ OK if we accept opinionated data model |
| PayPal/Braintree | Broader payment methods; weaker Flutter/billing docs; adds another gateway to operate. | Med | ~3.49% + $0.49 retail (varies) | 🚫 Only if Stripe is blocked |
| In-App Purchases / RevenueCat | Required if we allow upgrading inside the iOS/Android apps; RevenueCat simplifies receipt validation. | Med/high | Apple/Google 15% (Small Business Program) → 30% standard | ⚠️ Needed for in-app mobile sales |

Key updates vs prior notes:
- `stripe_payment` is deprecated; use `flutter_stripe` for any in-app card collection, but prefer hosted Checkout to avoid handling PCI scope.
- Apple/Google policies still restrict external purchase flows inside apps; if we surface “Upgrade” on mobile, either (a) route to platform IAP, or (b) position mobile as a companion to a web-purchased SaaS license and avoid in-app purchase prompts.

## Recommended architecture (Stripe-first, hybrid)

1) **Products & pricing in Stripe**
- Create Products for Pro and Scale; Prices for monthly and annual (use lookup keys for code readability).
- Enable Customer Portal (billing portal) for payment method changes and cancellations.

2) **Backend (Firebase Functions)**
- `createCheckoutSession` (callable HTTPS): validates `orgId` membership, ensures a Stripe Customer (by org), creates a Checkout Session in `subscription` mode with metadata `{orgId, userId, requestedTier, priceLookupKey}`. Returns the hosted URL.
- `stripeWebhook` (HTTP): verify Stripe-Signature header, handle `checkout.session.completed`, `customer.subscription.updated|deleted`, `invoice.payment_failed`. On success, write `organizations/{orgId}`:
  ```json
  {
    "tier": "pro",
    "license": {
      "provider": "stripe",
      "stripeCustomerId": "cus_...",
      "stripeSubscriptionId": "sub_...",
      "tier": "pro",
      "features": {"offline_sync": true, "monitoring_dialog": true},
      "expiresAt": 1719877200000,
      "signature": "base64-hmac", // using SF_LICENSE_SECRET to align with FeatureAccessService
      "trialEndsAt": null
    },
    "billing": {
      "priceLookupKey": "pro-monthly",
      "portalUrl": "https://billing.stripe.com/p/login/test_..."
    }
  }
  ```
- Security: keep Stripe secrets in `firebase functions:config:set stripe.secret=...`; deny client writes to `license`/`billing` via Firestore rules except through Functions.

Example (TypeScript outline):
```ts
export const createCheckoutSession = functions.https.onCall(async (data, ctx) => {
  requireAuth(ctx);
  assertOrgMember(ctx, data.orgId);
  const customer = await ensureCustomerForOrg(data.orgId, data.email);
  const session = await stripe.checkout.sessions.create({
    mode: 'subscription',
    customer: customer.id,
    line_items: [{price: priceIdFromLookup(data.priceLookupKey), quantity: 1}],
    success_url: `${appHost}/billing/return?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${appHost}/billing/cancel`,
    subscription_data: {metadata: {orgId: data.orgId, requestedTier: data.tier}},
    metadata: {orgId: data.orgId, requesterUid: ctx.auth.uid},
  });
  return {url: session.url};
});
```

3) **Frontend (Flutter)**
- Web/desktop: Until Stripe Checkout is live, route Community upgrade CTAs to the beta waitlist email form via `upgrade_url` in `config/tier_features.yaml`. Once live, `UpgradeCta` opens the Checkout Session URL returned by `PaymentService → createCheckoutSession`.
- Mobile (App Store / Play compliant): do **not** deep-link to Stripe/Payment Links from inside the app. Either (a) hide/soften the CTA and message “Upgrade on web” until IAP/RevenueCat is ready, or (b) implement platform billing and map receipts to the same license shape. External purchase flows surfaced in-app risk rejection.
- Entitlements refresh: after return from Checkout (web) or after app resume (mobile), refetch org metadata so `FeatureAccessService` picks up the new `license`.

4) **Ops & reporting**
- Use Stripe test mode with CLI webhook forwarding locally.
- Log billing events to BigQuery/Firestore audit collection for support.
- Expose billing status inside the Org admin screen (e.g., `subscription active · renews on <date>`).

## Implementation plan

### Phase 0 – Beta waitlist (now)
- Update `config/tier_features.yaml` Community `upgrade_url` to the beta email collection form (copy: "Add your name to the beta release").
- Ensure `UpgradeCta` allowlist includes the form host.
- Record submissions (CRM or shared sheet) and perform manual license upgrades in Firestore as needed.
- Add a short support runbook for reconciling beta requests to org IDs.

### Phase 1 – Payment Link pilot (when ready)
- Create Stripe account, Products, and Payment Links for Pro/Scale monthly.
- Replace `upgrade_url` in `config/tier_features.yaml` with the Link URLs and ship (web/desktop only). On mobile, hide or redirect the CTA to “Upgrade on web” to stay store-compliant. Keep manual license flips in Firestore for now.

### Phase 2 – Hosted Checkout + webhooks (approx. 1 week)
- Add Functions: `createCheckoutSession`, `stripeWebhook`, `ensureCustomerForOrg`, and a `signLicense` helper using `SF_LICENSE_SECRET`.
- Add `PaymentService` flow to call the callable and open the returned URL; handle success/cancel return routes on web.
- Update Firestore rules to block direct client writes to `license`/`billing`.
- QA with Stripe test cards + CLI webhook forwarding; ensure `FeatureAccessService.applyLicenseFromMetadata` reflects new data.

### Phase 3 – Billing portal & lifecycle (approx. 1 week)
- Expose “Manage billing” link (Stripe Customer Portal URL) in organization settings.
- Handle `customer.subscription.deleted` / payment_failed events with grace periods and downgrade to `community` on expiry.
- Add lightweight billing status UI + notifications.

### Phase 4 – Mobile policy compliance (2–4 weeks, when needed)
- If we must sell inside the mobile apps: integrate `in_app_purchase` or RevenueCat to broker App Store / Play receipts; map purchases to org IDs and write the same `license` shape.
- If we do **not** sell in-app: hide or soften upgrade CTA on mobile and defer users to web to purchase.

## Cost and compliance notes

- Stripe US pricing: 2.9% + $0.30 domestic cards, +1% cross-border, +1% currency conversion. ACH debits are cheaper (0.8% capped at $5) if we enable them.
- Apple/Google take 15% for most small dev programs; 30% standard. External purchase flows shown inside the app risk rejection unless the app clearly behaves as a signed-in companion to a pre-existing SaaS contract.
- Firebase Functions billing: negligible at current scale; keep cold-start impact minimal by using 2nd gen and region pinning.

## Security & reliability checklist

- Validate Stripe signatures on every webhook event; reject unsigned requests.
- Use idempotency keys when creating Checkout Sessions and when writing Firestore license data from webhooks.
- Store Stripe secrets and webhook secrets outside the repo (Firebase config or Secrets Manager).
- Rate-limit billing cloud functions; log all mutations to an audit collection.
- Do not store card PANs; lean on Stripe-hosted experiences.

## Reference implementation map

- `lib/widgets/common/upgrade_cta.dart`: opens `FeatureAccessService.upgradeUrl` (beta waitlist form now; Payment Link/Checkout once callable is wired).
- `lib/services/feature_access_service.dart`: already parses `organization.tier` and signed `license` payloads; reuse this shape to avoid client changes.
- `config/tier_features.yaml`: set per-tier payment/upgrade URL; keep feature map as the entitlement source of truth.

## Decision points before coding

1. Confirm Stripe as the primary processor (OK unless procurement requires PayPal/Braintree).
2. Confirm beta waitlist form URL and copy for Community upgrades.
3. Decide mobile posture now: hide upgrade on mobile (web-purchase only) vs. implement IAP/RevenueCat.
4. Choose SKUs/prices (monthly vs. annual) and trial/grace rules.
5. Confirm who owns ops runbook for failed payments and manual overrides.

## Resources

- Stripe Billing + Checkout: https://stripe.com/docs/billing/subscriptions/build-subscriptions?platform=web
- Stripe Flutter (PaymentSheet, if needed): https://pub.dev/packages/flutter_stripe
- Stripe CLI for webhook testing: https://stripe.com/docs/stripe-cli
- Apple App Review: https://developer.apple.com/app-store/review/guidelines/#payments
- Google Play Billing: https://developer.android.com/google/play/billing
