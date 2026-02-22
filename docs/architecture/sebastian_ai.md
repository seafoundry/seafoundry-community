# Sebastian AI Architecture

Sebastian is SeaFoundry's AI assistant powered by Google Gemini 1.5 Pro. This document describes the architecture, security model, and integration patterns.

## Overview

Sebastian provides context-aware AI assistance for marine restoration workflows:
- Nursery health insights and recommendations
- Outplanting planning and guidance
- Monitoring data analysis
- Task management suggestions
- Natural language queries about inventory

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter App                               │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ SebastianFAB    │  │ SebastianPanel  │  │ SebastianScreen │  │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘  │
│           │                    │                    │            │
│           └────────────────────┼────────────────────┘            │
│                                ▼                                 │
│                    ┌───────────────────────┐                     │
│                    │  SebastianChatCubit   │                     │
│                    └───────────┬───────────┘                     │
│                                │                                 │
│                    ┌───────────┴───────────┐                     │
│                    │  SebastianService     │                     │
│                    └───────────┬───────────┘                     │
└────────────────────────────────┼─────────────────────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │   Firebase Functions    │
                    │                         │
                    │  ┌───────────────────┐  │
                    │  │  sebastianChat    │  │  ← Callable Function
                    │  └─────────┬─────────┘  │
                    │            │            │
                    │  ┌─────────┴─────────┐  │
                    │  │sebastianChatStream│  │  ← SSE Endpoint
                    │  └─────────┬─────────┘  │
                    │            │            │
                    │  ┌─────────┴─────────┐  │
                    │  │  gemini-service   │  │  ← Gemini API
                    │  └─────────┬─────────┘  │
                    │            │            │
                    │  ┌─────────┴─────────┐  │
                    │  │  budget / rate    │  │  ← Usage Control
                    │  └───────────────────┘  │
                    └─────────────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │    Google Gemini API    │
                    │    (gemini-1.5-pro)     │
                    └─────────────────────────┘
```

## Components

### Flutter Client

| Component | File | Purpose |
|-----------|------|---------|
| `SebastianService` | `lib/services/sebastian/sebastian_service.dart` | API calls to Cloud Functions |
| `SebastianChatCubit` | `lib/cubits/sebastian/sebastian_chat_cubit.dart` | State management for chat |
| `SebastianChatState` | `lib/cubits/sebastian/sebastian_chat_state.dart` | Immutable state classes |
| `SebastianFAB` | `lib/widgets/sebastian/sebastian_fab.dart` | Floating action button |
| `SebastianChatPanel` | `lib/widgets/sebastian/sebastian_chat_panel.dart` | Main chat interface |
| `SebastianMessageBubble` | `lib/widgets/sebastian/sebastian_message_bubble.dart` | Message display |
| `SebastianBudgetIndicator` | `lib/widgets/sebastian/sebastian_budget_indicator.dart` | Usage meter |

### Cloud Functions

| Function | File | Purpose |
|----------|------|---------|
| `sebastianChat` | `functions/src/sebastian/chat.ts` | Callable function for chat |
| `sebastianChatStream` | `functions/src/sebastian/chat-stream.ts` | SSE streaming endpoint |
| `sendMessage` | `functions/src/sebastian/gemini-service.ts` | Gemini API integration |
| `canMakeRequest` | `functions/src/sebastian/budget.ts` | Budget enforcement |
| `checkRateLimit` | `functions/src/sebastian/rate-limiter.ts` | Rate limiting |

### Data Models

| Model | File | Purpose |
|-------|------|---------|
| `SebastianMessage` | `lib/models/sebastian/sebastian_message.dart` | Chat message |
| `SebastianConversation` | `lib/models/sebastian/sebastian_conversation.dart` | Conversation metadata |
| `SebastianUsage` | `lib/models/sebastian/sebastian_usage.dart` | Usage tracking |
| `SebastianContext` | `lib/models/sebastian/sebastian_context.dart` | Navigation context |

## Security Model

### Authentication
- User must be authenticated via Firebase Auth
- User must belong to the organization making the request
- Verified via `verifyUserOrganization()` in `auth-validator.ts`

### Authorization
- Feature access checked via `isFeatureEnabledForOrg('ai_copilot')`
- Requires Pro tier subscription OR `ai_copilot` feature purchase

### Rate Limiting
- Per-organization rate limits prevent abuse
- Configurable in `rate-limiter.ts`
- Default: 60 requests/minute per org

### Budget Management
- Per-organization monthly budget limits
- Token usage tracked per request
- Cost calculated based on Gemini pricing
- Stored in Firestore: `organizations/{orgId}/sebastian_usage`

### Input Validation
- Message content sanitized via `sanitizeMessage()`
- Conversation IDs validated
- History validated for injection attacks

## API Key Management

### Production
```bash
# Set secret in Firebase Secret Manager
firebase functions:secrets:set GEMINI_API_KEY

# Deploy functions
firebase deploy --only functions:sebastianChat,functions:sebastianChatStream
```

### Local Development
```bash
# Add to functions/.env (gitignored)
GEMINI_API_KEY=your-api-key-here

# Start emulators
firebase emulators:start --only functions,firestore,auth
```

## Streaming Implementation

Sebastian supports SSE (Server-Sent Events) for real-time streaming responses:

1. **Client** calls `SebastianService.sendMessageStream()`
2. **Service** opens HTTP connection to `sebastianChatStream` endpoint
3. **Function** streams tokens from Gemini API
4. **Client** parses SSE events and updates UI in real-time

```dart
// Client-side streaming
await for (final event in sebastianService.sendMessageStream(...)) {
  if (event.type == 'content') {
    // Append to message
  } else if (event.type == 'done') {
    // Finalize message
  }
}
```

## Context-Aware Help

Sebastian uses navigation context to provide relevant assistance:

```dart
final context = SebastianContext(
  currentPath: '/organizations/org123/sites/site456',
  currentNodeType: 'site',
  currentNodeId: 'site456',
  organizationId: 'org123',
);
```

This context is passed to the LLM system prompt, enabling questions like:
- "What's the health of this site?" (knows which site)
- "How many corals are here?" (scoped to current location)

## Budget Tiers

| Tier | Monthly Budget | Rate Limit |
|------|---------------|------------|
| Pro | $10 | 60/min |
| Scale | $50 | 120/min |
| Enterprise | Custom | Custom |

## Testing

```bash
# Run Sebastian unit tests
flutter test test/unit/cubits/sebastian/
flutter test test/unit/services/sebastian/
flutter test test/unit/models/sebastian/

# Test Cloud Functions
cd functions && npm test
```

## Troubleshooting

### "GEMINI_API_KEY secret is not configured"
- Ensure secret is set: `firebase functions:secrets:set GEMINI_API_KEY`
- Redeploy functions after setting secret

### "Budget exceeded"
- Check usage in Firebase Console → Firestore → `organizations/{orgId}/sebastian_usage`
- Budget resets monthly

### "Rate limit exceeded"
- Wait 1 minute and retry
- Consider upgrading to Scale tier for higher limits

### Streaming not working
- Check browser supports SSE (all modern browsers do)
- Verify CORS settings in `sebastianChatStream` function
- Check network tab for connection issues

## Related Documentation

- [Secrets Management](../../functions/SECRETS.md)
- [Feature Access Service](../../lib/services/feature_access_service.dart)
- [Tier Configuration](../../config/tiers.yaml)
- [Per-Feature Purchases](../../config/features.yaml)
