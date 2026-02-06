#!/usr/bin/env bash
# Dytto Context CLI — personal context API for AI agents
# Usage: dytto.sh <command> [args...]
set -euo pipefail

# Config: env vars > config file > defaults
CONFIG_FILE="${DYTTO_CONFIG:-${HOME}/.config/dytto/config.json}"

if [[ -f "$CONFIG_FILE" ]]; then
    _cfg() { python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('$1',''))" 2>/dev/null; }
    API_BASE="${DYTTO_API_BASE_URL:-$(_cfg api_base)}"
    USER_EMAIL="${DYTTO_EMAIL:-$(_cfg email)}"
    USER_PASSWORD="${DYTTO_PASSWORD:-$(_cfg password)}"
    API_KEY="${DYTTO_API_KEY:-$(_cfg api_key)}"
else
    API_BASE="${DYTTO_API_BASE_URL:-https://dytto.onrender.com}"
    USER_EMAIL="${DYTTO_EMAIL:-}"
    USER_PASSWORD="${DYTTO_PASSWORD:-}"
    API_KEY="${DYTTO_API_KEY:-}"
fi

# Fallback if api_base not in config
API_BASE="${API_BASE:-https://dytto.onrender.com}"

# Service key auth (for hosted agents) or user auth (for personal agents)
AGENT_SERVICE_KEY="${AGENT_SERVICE_KEY:-}"
DYTTO_USER_ID="${DYTTO_USER_ID:-}"
TOKEN_CACHE="/tmp/.dytto-token-cache"

# Detect auth mode: api_key > service > email/password
AUTH_MODE="user"
if [[ -n "$API_KEY" ]]; then
    AUTH_MODE="api_key"
elif [[ -n "$AGENT_SERVICE_KEY" && -n "$DYTTO_USER_ID" ]]; then
    AUTH_MODE="service"
fi

check_config() {
    if [[ "$AUTH_MODE" == "api_key" || "$AUTH_MODE" == "service" ]]; then
        return 0  # api key or service key auth — no email/password needed
    fi
    local missing=()
    [[ -z "$USER_EMAIL" ]] && missing+=("DYTTO_EMAIL")
    [[ -z "$USER_PASSWORD" ]] && missing+=("DYTTO_PASSWORD")
    if (( ${#missing[@]} > 0 )); then
        echo "ERROR: Missing Dytto credentials." >&2
        echo "Set env vars or create ${CONFIG_FILE}:" >&2
        printf '  %s\n' "${missing[@]}" >&2
        echo "" >&2
        echo "Auth options:" >&2
        echo "  1. API key: DYTTO_API_KEY=dyt_..." >&2
        echo "  2. Email/password: DYTTO_EMAIL + DYTTO_PASSWORD" >&2
        echo "  3. Config file: ~/.config/dytto/config.json" >&2
        echo "" >&2
        echo "Get an API key at https://dytto.app/settings/api-keys" >&2
        exit 1
    fi
}

get_token() {
    if [[ "$AUTH_MODE" == "api_key" ]]; then
        echo "$API_KEY"
        return
    fi
    if [[ "$AUTH_MODE" == "service" ]]; then
        echo "$AGENT_SERVICE_KEY"
        return
    fi
    if [[ -f "$TOKEN_CACHE" ]]; then
        local cached_age=$(( $(date +%s) - $(stat -c %Y "$TOKEN_CACHE" 2>/dev/null || echo 0) ))
        if (( cached_age < 3000 )); then
            cat "$TOKEN_CACHE"
            return
        fi
    fi
    check_config
    local response
    response=$(curl -s --max-time 60 -X POST "${API_BASE}/api/auth/login" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"${USER_EMAIL}\",\"password\":\"${USER_PASSWORD}\"}")
    local token
    token=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)
    if [[ -n "$token" && "$token" != "None" ]]; then
        echo "$token" > "$TOKEN_CACHE"
        echo "$token"
    else
        echo "Login failed. Check your email/password. Response: $response" >&2
        exit 1
    fi
}

api_get() {
    local endpoint="$1"
    local token
    token=$(get_token)
    curl -s --max-time 60 -H "Authorization: Bearer ${token}" \
         -H "Content-Type: application/json" \
         "${API_BASE}${endpoint}"
}

api_post() {
    local endpoint="$1"
    local data="$2"
    local token
    token=$(get_token)
    curl -s --max-time 60 -X POST -H "Authorization: Bearer ${token}" \
         -H "Content-Type: application/json" \
         -d "$data" \
         "${API_BASE}${endpoint}"
}

# Agent-specific API calls (service key auth, includes user_id)
agent_api_get() {
    local endpoint="$1"
    curl -s --max-time 60 -H "Authorization: Bearer ${AGENT_SERVICE_KEY}" \
         -H "Content-Type: application/json" \
         "${API_BASE}${endpoint}?user_id=${DYTTO_USER_ID}"
}

agent_api_post() {
    local endpoint="$1"
    local data="$2"
    curl -s --max-time 60 -X POST -H "Authorization: Bearer ${AGENT_SERVICE_KEY}" \
         -H "Content-Type: application/json" \
         -d "$data" \
         "${API_BASE}${endpoint}"
}

urlencode() {
    python3 -c "import urllib.parse; print(urllib.parse.quote('$1'))"
}

json_escape() {
    python3 -c "import json; print(json.dumps('$1')[1:-1])"
}

CMD="${1:-help}"
shift || true

case "$CMD" in
    context)
        if [[ "$AUTH_MODE" == "service" ]]; then
            agent_api_get "/api/agent/context"
        else
            api_get "/api/context"
        fi
        ;;
    summary)
        api_get "/api/context/summary"
        ;;
    patterns)
        api_get "/api/context/patterns"
        ;;
    insights)
        api_get "/api/context/insights"
        ;;
    search)
        query="${1:?Usage: dytto.sh search <query>}"
        api_post "/api/context/search" "{\"query\":\"${query}\"}"
        ;;
    story)
        date="${1:?Usage: dytto.sh story <YYYY-MM-DD>}"
        api_get "/api/stories/${date}"
        ;;
    search-stories)
        query="${1:?Usage: dytto.sh search-stories <query>}"
        api_get "/api/stories/search?q=$(urlencode "$query")"
        ;;
    weather)
        lat="${1:?Usage: dytto.sh weather <lat> <lon>}"
        lon="${2:?Usage: dytto.sh weather <lat> <lon>}"
        api_get "/api/weather/current?latitude=${lat}&longitude=${lon}"
        ;;
    news)
        lat="${1:?Usage: dytto.sh news <lat> <lon> [location_name]}"
        lon="${2:?Usage: dytto.sh news <lat> <lon> [location_name]}"
        location="${3:-}"
        url="/api/news/context?latitude=${lat}&longitude=${lon}"
        [[ -n "$location" ]] && url="${url}&location=$(urlencode "$location")"
        api_get "$url"
        ;;
    store-fact)
        desc="${1:?Usage: dytto.sh store-fact <description> [category]}"
        category="${2:-personal_info}"
        api_post "/api/mcp/update-context" "{\"interaction_summary\":\"Personal fact (${category}): ${desc}\",\"source_system\":\"agent\",\"discovered_insights\":[\"${desc}\"],\"behavioral_observations\":[],\"new_knowledge\":[]}"
        ;;
    observe)
        # New observe endpoint — accepts unstructured input, extracts facts via LLM
        input="${1:?Usage: dytto.sh observe <text>}"
        source="${2:-agent}"
        escaped_input=$(json_escape "$input")
        escaped_source=$(json_escape "$source")
        api_post "/api/v1/observe" "{\"input\":\"${escaped_input}\",\"source\":\"${escaped_source}\"}"
        ;;
    observe-legacy)
        # Old observe via mcp/update-context (kept for compatibility)
        pattern="${1:?Usage: dytto.sh observe-legacy <pattern>}"
        api_post "/api/mcp/update-context" "{\"interaction_summary\":\"Behavioral observation: ${pattern}\",\"source_system\":\"agent\",\"discovered_insights\":[],\"behavioral_observations\":[\"${pattern}\"],\"new_knowledge\":[]}"
        ;;
    update)
        summary="${1:?Usage: dytto.sh update <summary> [insights_json] [concepts_json] [notes_json]}"
        insights="${2:-[]}"
        concepts="${3:-[]}"
        notes="${4:-[]}"
        api_post "/api/mcp/update-context" "{\"interaction_summary\":\"${summary}\",\"source_system\":\"agent\",\"discovered_insights\":${insights},\"behavioral_observations\":${notes},\"new_knowledge\":${concepts}}"
        ;;
    notify)
        msg="${1:?Usage: dytto.sh notify <message> [title]}"
        title="${2:-Your agent}"
        if [[ "$AUTH_MODE" != "service" ]]; then
            echo "ERROR: notify requires service key auth (AGENT_SERVICE_KEY + DYTTO_USER_ID)" >&2
            exit 1
        fi
        agent_api_post "/api/agent/notify" "$(python3 -c "import json; print(json.dumps({'user_id':'${DYTTO_USER_ID}','title':'${title}','body':'${msg}'}))")"
        ;;
    event|events)
        summary="${1:?Usage: dytto.sh event <summary> [type]}"
        etype="${2:-activity}"
        if [[ "$AUTH_MODE" != "service" ]]; then
            echo "ERROR: events requires service key auth (AGENT_SERVICE_KEY + DYTTO_USER_ID)" >&2
            exit 1
        fi
        agent_api_post "/api/agent/events" "$(python3 -c "import json; print(json.dumps({'user_id':'${DYTTO_USER_ID}','source':'agent','events':[{'type':'${etype}','summary':'${summary}','importance':'medium'}]}))")"
        ;;
    scopes)
        # List available API key scopes
        api_get "/api/keys/scopes"
        ;;
    help|*)
        cat <<'EOF'
Dytto Context CLI — personal context API for AI agents

Usage: dytto.sh <command> [args...]

Read:
  context                      Full context profile (who is this person)
  summary                      Quick context summary
  patterns                     Behavioral patterns and routines
  insights                     Derived insights about the user
  search <query>               Semantic search across context
  story <YYYY-MM-DD>           Get journal/story for a date
  search-stories <query>       Search across stories

Write:
  observe <text> [source]      Push unstructured observations → auto-extracted facts
  store-fact <desc> [category] Store a learned fact (structured)
  update <summary> [insights] [concepts] [notes]  Comprehensive update

External:
  weather <lat> <lon>          Weather context
  news <lat> <lon> [name]      News context

Agent actions (service key auth only):
  notify <message> [title]     Send push notification to user
  event <summary> [type]       Report event (conversation/activity/social/milestone)

Auth (priority order):
  1. API Key:      DYTTO_API_KEY=dyt_...  (recommended)
  2. Service Key:  AGENT_SERVICE_KEY + DYTTO_USER_ID (hosted agents)
  3. Email/Pass:   DYTTO_EMAIL + DYTTO_PASSWORD
  4. Config file:  ~/.config/dytto/config.json

Get an API key: https://dytto.app/settings/api-keys
Optional: DYTTO_API_BASE_URL (default: https://dytto.onrender.com)
EOF
        ;;
esac
