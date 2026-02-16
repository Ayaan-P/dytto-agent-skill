# Dytto API — Third-Party Agent Integration

Personal context API for AI agents. Get scoped access to user context based on your granted permissions.

**Base URL:** `https://dytto.onrender.com`

## Authentication

All requests require an API key in the Authorization header:

```
Authorization: Bearer dyt_your_api_key_here
```

API keys are scoped — you only see context categories your user has granted access to.

---

## Endpoints

### Get Context

```http
GET /api/context
```

Returns user context narrative filtered to your allowed scopes.

**Response:**
```json
{
  "content": "User prefers morning meetings...",
  "_scoped": true,
  "_allowed_categories": ["work", "schedule", "places", "projects"]
}
```

---

### Real-Time Snapshot

```http
GET /api/context/now
```

Quick snapshot of today's context — activities, upcoming schedule, current patterns.

**Response:**
```json
{
  "timestamp": "2026-02-12T16:00:00Z",
  "context_summary": "User is at work, has 2 meetings this afternoon...",
  "todays_activities": [],
  "upcoming_schedule": [],
  "patterns": {
    "temporal": ["Usually takes lunch at 12:30"],
    "locations": ["Office on Congress St"],
    "activities": ["Deep work in mornings"]
  }
}
```

---

### Task-Based Scoped Context

```http
POST /api/context/scope
Content-Type: application/json

{
  "task": "Schedule a meeting for the user",
  "agent_type": "calendar",
  "max_tokens": 2000
}
```

Describe your task, get only relevant context back.

**Response:**
```json
{
  "context": {
    "relevant_facts": [
      {"category": "schedule", "fact": "Prefers meetings after 2pm"},
      {"category": "work", "fact": "Wednesdays are no-meeting days"}
    ],
    "patterns": [],
    "preferences": ["Prefers 30-min meetings over 1-hour"]
  },
  "categories_used": ["schedule", "work", "preferences"],
  "token_count": 450
}
```

---

### Search Context

```http
POST /api/context/search
Content-Type: application/json

{
  "query": "meeting preferences"
}
```

Semantic search across user context.

**Response:**
```json
{
  "results": [
    {"text": "Prefers morning meetings on Tuesdays", "score": 0.92},
    {"text": "No meetings before 9am", "score": 0.87}
  ]
}
```

---

### Get Summary

```http
GET /api/context/summary
```

Quick summary of user context.

---

### Get Patterns

```http
GET /api/context/patterns
```

Behavioral patterns and routines.

---

### Stories

```http
GET /api/stories/dates
```

List dates that have stories (for calendar views).

```http
GET /api/stories/date/2026-02-12
```

Get story for a specific date.

```http
POST /api/stories/search
Content-Type: application/json

{"query": "trip to New York"}
```

Search across user stories.

---

### Push Observations (if scope allows)

```http
POST /api/v1/observe
Content-Type: application/json

{
  "input": "User mentioned they have a peanut allergy",
  "source": "your_agent_name"
}
```

Push context updates. Requires `observe` or `context:write` scope.

---

## Scopes

Your API key determines what you can access:

| Scope | What You See |
|-------|--------------|
| `work` | Job, projects, schedule, office location |
| `health` | Health, food, lifestyle, appointments |
| `transportation` | Commute, travel, places, schedule |
| `social` | Friends, family, events |
| `food` | Diet, restaurants, preferences |
| `home` | Home life, family, preferences |
| `entertainment` | Movies, music, hobbies |

**Example:** A `work` scoped key sees job info, projects, work schedule, and office location — but NOT health, financial, or relationship data.

---

## Rate Limits

- Default: 60 requests/minute
- Observe endpoint: 10 requests/minute

---

## Error Responses

```json
{"error": "Invalid or expired token"}  // 401 - Bad API key
{"error": "Insufficient scope"}         // 403 - Need different permissions
{"error": "Rate limit exceeded"}        // 429 - Slow down
```

---

## Quick Start

```bash
# Get user context
curl -s "https://dytto.onrender.com/api/context" \
  -H "Authorization: Bearer dyt_your_key"

# Task-based context
curl -s -X POST "https://dytto.onrender.com/api/context/scope" \
  -H "Authorization: Bearer dyt_your_key" \
  -H "Content-Type: application/json" \
  -d '{"task": "Help user plan their commute"}'
```

---

## Notes

- First request may take 20-30s (cold start). Subsequent requests are fast.
- Context is filtered server-side based on your scopes — you can't access data outside your permissions.
- All data belongs to the user. Handle with care.
