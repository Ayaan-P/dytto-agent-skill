---
name: dytto
description: "Give your agent persistent memory and real-time personal context via Dytto — the context API for AI agents. Use when you need to know about the user (who they are, what they care about, behavioral patterns, daily stories), search their life history, store new facts learned during conversation, or push context updates. Dytto collects location, weather, calendar, health, photos, and more from the user's phone and synthesizes it into queryable context. Think of it as Plaid, but for personal context."
---

# Dytto — Personal Context for Agents

Dytto gives your agent memory. Query it to know who your user is, what happened today, and what they care about.

**Base URL:** `https://dytto.onrender.com`

## Setup

### Option 1: API Key (Recommended)

Get an API key from https://dytto.app/settings/api-keys

```bash
export DYTTO_API_KEY="dyt_your_key_here"
```

Or add to `~/.config/dytto/config.json`:
```json
{
  "api_key": "dyt_your_key_here"
}
```

That's it. API keys are scoped — you control what the agent can access.

### Option 2: Email/Password (Legacy)

For personal agents that need full access:

```bash
export DYTTO_EMAIL="user@example.com"
export DYTTO_PASSWORD="your-password"
```

## CLI Commands

Run via: `bash scripts/dytto.sh <command> [args...]`

### Read Context

```bash
bash scripts/dytto.sh context          # Full profile — who is this person
bash scripts/dytto.sh summary          # Quick summary
bash scripts/dytto.sh patterns         # Behavioral patterns (routines, habits)
bash scripts/dytto.sh insights         # Derived insights
```

### Search

```bash
bash scripts/dytto.sh search "career goals"        # Semantic search
bash scripts/dytto.sh story 2026-01-30             # Journal for a date
bash scripts/dytto.sh search-stories "trip to NYC" # Search stories
```

### Write Context

```bash
# Observe — dump any text, Dytto extracts facts automatically
bash scripts/dytto.sh observe "User mentioned they prefer morning meetings. Had a chat about the robotaxi project."

# Structured fact storage (when you know exactly what to store)
bash scripts/dytto.sh store-fact "Prefers morning meetings" "work_preferences"
```

**Use observe for everything** — chat summaries, events, conversations, whatever. Just text in, context out.

### External Data

```bash
bash scripts/dytto.sh weather 42.37 -71.11
bash scripts/dytto.sh news 42.37 -71.11 "Cambridge MA"
```

---

## REST API Reference

All endpoints require `Authorization: Bearer <token>` header. Token can be:
- API key: `dyt_...`
- JWT from `/api/auth/login`
- Service key (for hosted agents)

### Context Endpoints

| Method | Endpoint | Description | Scopes |
|--------|----------|-------------|--------|
| GET | `/api/context` | Full context narrative | `context:read` or domain scopes |
| GET | `/api/context/summary` | Quick summary | `context:read` or domain scopes |
| GET | `/api/context/patterns` | Behavioral patterns | `patterns:read` or domain scopes |
| GET | `/api/context/insights` | Derived insights | `context:read` or domain scopes |
| GET | `/api/context/now` | Real-time snapshot (today's activities, upcoming schedule) | `context:read` or domain scopes |
| GET | `/api/context/quality` | Context quality assessment | `context:read` |
| GET | `/api/context/latest` | Latest context with timestamp | `context:read` or domain scopes |
| POST | `/api/context/search` | Semantic search `{"query": "..."}` | `search:execute` or domain scopes |
| POST | `/api/context/scope` | Task-based scoped context (see below) | domain scopes |
| POST | `/api/context/initialize` | Initialize context (first-time setup) | `context:write` |

#### Scoped Context (`/api/context/scope`)

Task-based context retrieval. Agent describes what it needs, Dytto returns only relevant facts.

```bash
curl -X POST "https://dytto.onrender.com/api/context/scope" \
  -H "Authorization: Bearer dyt_..." \
  -H "Content-Type: application/json" \
  -d '{
    "task": "Drive user home from work, optimize route and climate",
    "agent_type": "robotaxi",
    "max_tokens": 2000,
    "categories": ["location", "preferences"]
  }'
```

Response includes:
- `context`: Filtered facts, patterns, preferences
- `scoping_reasoning`: Why these categories were selected
- `categories_used`: Which fact categories were included
- `token_count`: Approximate token count

### Facts API (`/api/v1/facts`)

Structured fact storage and retrieval.

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/facts/query` | Query facts with filters |
| GET | `/api/v1/facts/categories` | List all fact categories |
| GET | `/api/v1/facts/<fact_id>` | Get specific fact by ID |

```bash
# Query facts by category
curl -X POST "https://dytto.onrender.com/api/v1/facts/query" \
  -H "Authorization: Bearer dyt_..." \
  -d '{"categories": ["work", "projects"], "limit": 20}'
```

### Observe Endpoint (`/api/v1/observe`)

**The universal "text in → context out" method.** Push any unstructured text — Dytto extracts meaning and stores it.

```bash
curl -X POST "https://dytto.onrender.com/api/v1/observe" \
  -H "Authorization: Bearer dyt_..." \
  -d '{
    "input": "Had a conversation about robotaxi integration. User prefers window seats and has a peanut allergy.",
    "source": "my_agent"
  }'
```

Dytto will:
1. Extract atomic facts: "Prefers window seats", "Has peanut allergy", "Discussed robotaxi integration"
2. Categorize: `preferences`, `health`, `projects`
3. Deduplicate against existing facts
4. Store with embeddings for search

**Use this for everything:** chat summaries, events, milestones, observations, whatever. Just dump text, Dytto makes sense of it.

### Stories API (`/api/stories`)

Daily journals/stories generated from user activity.

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/stories/<story_id>` | Get story by ID |
| GET | `/api/stories/date/<YYYY-MM-DD>` | Get story for a date |
| GET | `/api/stories/dates` | List available story dates |
| POST | `/api/stories/search` | Search stories `{"query": "..."}` |
| POST | `/api/stories/generate` | Generate story for date range |

### External Data

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/weather/current?latitude=X&longitude=Y` | Current weather |
| GET | `/api/weather/forecast?latitude=X&longitude=Y` | Weather forecast |
| GET | `/api/weather/context?latitude=X&longitude=Y` | Weather as context narrative |
| GET | `/api/news/context?latitude=X&longitude=Y&location=NAME` | Local news context |

### API Key Management (`/api/keys`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/keys/scopes` | List available scopes |
| POST | `/api/keys` | Create new API key |
| GET | `/api/keys` | List user's API keys |
| DELETE | `/api/keys/<key_id>` | Revoke an API key |

```bash
# Create a scoped API key
curl -X POST "https://dytto.onrender.com/api/keys" \
  -H "Authorization: Bearer <jwt>" \
  -d '{
    "name": "Robotaxi Agent",
    "scopes": ["transportation", "schedule", "preferences"],
    "rate_limit_per_minute": 60
  }'
```

### Agent Endpoints (`/api/agent`)

For hosted agents with service key auth.

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/agent/context?user_id=X` | Get user context |
| POST | `/api/agent/notify` | Send push notification |
| POST | `/api/agent/events` | Report events |
| GET | `/api/agent/messages?user_id=X` | Get agent messages |
| GET | `/api/agent/stories?user_id=X` | Get user stories |
| GET | `/api/agent/social?user_id=X` | Get social/relationship data |
| GET | `/api/agent/places?user_id=X` | Get frequent places |

### Auth Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/login` | Login with email/password, returns JWT |
| POST | `/api/auth/refresh` | Refresh JWT token |

### User Profile (`/api/user`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/user/profile` | Get user profile |
| POST | `/api/user/profile` | Update user profile |
| POST | `/api/user/notification-preferences` | Set notification prefs |
| POST | `/api/user/register-push-token` | Register push notification token |

### Social Links (`/api/sociallinks`)

Relationship tracking and social context.

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/sociallinks/relationships` | List relationships |
| POST | `/api/sociallinks/relationships` | Create relationship |
| POST | `/api/sociallinks/interactions` | Log interaction |
| GET | `/api/sociallinks/dashboard` | Social dashboard |
| GET | `/api/sociallinks/context/suggestions` | Get relationship suggestions |

### OAuth (`/api/v1/oauth`)

For third-party app integrations.

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/developers/applications` | Register OAuth app |
| GET | `/api/v1/developers/applications` | List your apps |
| GET | `/authorize` | OAuth authorization page |
| POST | `/api/v1/oauth/authorize` | Approve authorization |
| POST | `/api/v1/oauth/token` | Exchange code for token |
| GET | `/api/v1/oauth/scopes` | List OAuth scopes |
| GET | `/api/v1/user/connected-apps` | User's connected apps |

---

## API Key Scopes

### Domain Scopes (Use-Case Based)

These filter context to specific life domains:

| Scope | Access |
|-------|--------|
| `transportation` | Transport, places, schedule, preferences |
| `health` | Health, food, lifestyle, schedule |
| `social` | Friends, family, events, entertainment |
| `work` | Work, projects, schedule, places |
| `home` | Places, lifestyle, preferences, family |
| `entertainment` | Entertainment, preferences, lifestyle |
| `food` | Food, preferences, health |

### Technical Scopes

| Scope | Access |
|-------|--------|
| `context:read` | Full context narrative (all categories) |
| `context:write` | Write to context |
| `observe` | Use observe endpoint |
| `patterns:read` | Behavioral patterns |
| `stories:read` | Daily stories |
| `search:execute` | Semantic search |

### Fine-Grained Scopes

| Scope | Categories |
|-------|------------|
| `location` | places, transportation |
| `schedule` | schedule, events |
| `preferences` | preferences |
| `relationships` | family, friends |
| `lifestyle` | lifestyle |
| `financial` | financial |
| `travel` | places, transportation, schedule |

**Example:** A robotaxi agent with `transportation` scope can see location, route preferences, and schedule — but NOT health, financial, or relationship data.

---

## Auth Modes

| Mode | Setup | Use Case |
|------|-------|----------|
| **API Key** | `DYTTO_API_KEY=dyt_...` | Third-party agents (recommended) |
| **Email/Password** | `DYTTO_EMAIL` + `DYTTO_PASSWORD` | Personal agents with full access |
| **Service Key** | `AGENT_SERVICE_KEY` + `DYTTO_USER_ID` | Hosted agents on Dytto platform |

---

## Notes

- First call may take 20-30s (cold start on Render free tier). Subsequent calls are fast.
- Token cached for ~50 min at `/tmp/.dytto-token-cache`.
- The `observe` endpoint uses an LLM for extraction — expect ~10s latency.
- Domain-scoped API keys automatically filter responses to allowed categories.
- All data belongs to the user. Treat it with respect.
