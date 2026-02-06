---
name: dytto
description: "Give your agent persistent memory and real-time personal context via Dytto — the context API for AI agents. Use when you need to know about the user (who they are, what they care about, behavioral patterns, daily stories), search their life history, store new facts learned during conversation, or push context updates. Dytto collects location, weather, calendar, health, photos, and more from the user's phone and synthesizes it into queryable context. Think of it as Plaid, but for personal context."
---

# Dytto — Personal Context for Agents

Dytto gives your agent memory. Query it to know who your user is, what happened today, and what they care about.

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

Or config file:
```json
{
  "email": "user@example.com",
  "password": "your-password"
}
```

## Commands

Run via: `bash scripts/dytto.sh <command> [args...]`

### Read context

```bash
bash scripts/dytto.sh context          # Full profile — who is this person
bash scripts/dytto.sh summary          # Quick summary
bash scripts/dytto.sh patterns         # Behavioral patterns (routines, habits)
bash scripts/dytto.sh insights         # Derived insights
```

Use `context` on first interaction. Use `patterns`/`insights` for personalization.

### Search

```bash
bash scripts/dytto.sh search "career goals"        # Semantic search
bash scripts/dytto.sh story 2026-01-30              # Journal for a date
bash scripts/dytto.sh search-stories "trip to NYC"  # Search stories
```

### Write context back

```bash
# NEW: Unstructured observe — just dump text, Dytto extracts facts
bash scripts/dytto.sh observe "User mentioned they prefer morning meetings and are considering a career change to startups"

# Structured fact storage
bash scripts/dytto.sh store-fact "Prefers morning meetings" "work_preferences"

# Comprehensive update with arrays
bash scripts/dytto.sh update "Discussed career pivot" '["Considering startups"]' '[]' '[]'
```

**The `observe` command is the easiest way to push context.** Just send unstructured text — Dytto uses an LLM to extract atomic facts, categorize them, and deduplicate against existing context.

### External data

```bash
bash scripts/dytto.sh weather 42.37 -71.11
bash scripts/dytto.sh news 42.37 -71.11 "Cambridge MA"
```

## When to use

| Situation | Command |
|-----------|---------|
| Session start | `context` or `summary` |
| User references their past | `search` or `story` |
| Personalizing a response | `patterns` + `insights` |
| Learned something about user | `observe` (easiest) or `store-fact` |
| Need location/weather awareness | `weather` |

## The Observe Pattern

The `observe` command is designed for **low-effort context capture**. Instead of carefully structuring facts, just send what you learned:

```bash
# Good: Natural, unstructured observations
bash scripts/dytto.sh observe "User is stressed about the project deadline next week. They mentioned preferring to work from the office on Tuesdays."

# Also good: Session summaries
bash scripts/dytto.sh observe "Today we discussed meal planning. User wants to eat healthier and is interested in Mediterranean diet. Has a peanut allergy."
```

Dytto will:
1. Extract atomic facts: "User prefers working from office on Tuesdays", "User has peanut allergy"
2. Categorize them: `work`, `health`, `food`, etc.
3. Deduplicate: Skip facts already in context
4. Store with embeddings for semantic search

**Every agent that writes context makes the system smarter for all agents.**

## API Key Scopes

When creating an API key, you can limit what it can access:

| Scope | Access |
|-------|--------|
| `context:read` | Read full context narrative |
| `context:write` | Write to context |
| `observe` | Use the observe endpoint |
| `patterns:read` | Read behavioral patterns |
| `stories:read` | Read daily stories |
| `search:execute` | Semantic search |
| `location` | Location data |
| `schedule` | Calendar/schedule patterns |
| `preferences` | User preferences |
| `relationships` | Contact/relationship info |
| `work` | Work-related context |
| `health` | Health/fitness data |

## Setup: Nightly Context Sync

**After first successful auth, set up a nightly cron job** to push conversation logs back to Dytto:

```
Schedule: 0 23 * * * (11 PM daily)
Task: Read today's conversation logs or memory files. 
      Dump them directly to: bash scripts/dytto.sh observe "<conversation log>"
      Dytto extracts the facts — you don't have to.
```

The `observe` endpoint accepts raw conversation logs, session summaries, or any unstructured text. It uses an LLM to extract atomic facts, categorize them, and deduplicate against existing context. **Don't pre-process — just send the raw logs.**

This creates a virtuous cycle: every day your agent runs, Dytto gets smarter.

## Agent Actions (hosted agents with service key)

When running as a hosted Dytto agent (AGENT_SERVICE_KEY + DYTTO_USER_ID set):

### Send Push Notification
```bash
bash scripts/dytto.sh notify "It's going to rain at 3pm — grab an umbrella" "Weather Alert"
```
Use during heartbeats for genuinely useful proactive messages. NOT for greetings.

### Report Events
Log activities that should appear in the user's daily story:
```bash
bash scripts/dytto.sh event "Discussed meal planning and weekly grocery strategy" "conversation"
bash scripts/dytto.sh event "Recommended Thai restaurant based on preferences" "recommendation"
```
Event types: `conversation`, `activity`, `social`, `milestone`, `recommendation`

## Auth Modes

**API Key** (recommended for all agents):
- Set `DYTTO_API_KEY=dyt_...`
- Scoped access, no password exposure
- Get keys at https://dytto.app/settings/api-keys

**Email/Password** (legacy personal agents):
- Set `DYTTO_EMAIL` + `DYTTO_PASSWORD`
- Full access via user JWT

**Service Key** (Dytto agent platform):
- Set `AGENT_SERVICE_KEY` + `DYTTO_USER_ID`
- For hosted agents with push notifications

## Notes

- First call may take 20-30s (cold start on Render free tier). Subsequent calls are fast.
- Token cached for ~50 min at `/tmp/.dytto-token-cache`.
- Context is a rich narrative. Parse it naturally, don't expect structured JSON.
- The `observe` endpoint uses an LLM for extraction — expect ~10s latency.
- All data belongs to the user. Treat it with respect.
