# Personal Micro Webapp Stack — AI Agent Reference

This document is the complete reference for building, running, debugging, and extending personal micro webapps. It is written for an AI agent. Every instruction is concrete, verifiable, and self-contained. When in doubt, prefer the simplest interpretation.

---

## Table of Contents

1. [Philosophy and Constraints](#philosophy-and-constraints)
2. [Tech Stack Overview](#tech-stack-overview)
3. [Installation and Setup](#installation-and-setup)
4. [Project Structure](#project-structure)
5. [Canonical App Template](#canonical-app-template)
6. [Pocketbase Reference](#pocketbase-reference)
7. [Alpine.js Reference](#alpinejs-reference)
8. [HTMX Reference](#htmx-reference)
9. [Tailwind Reference](#tailwind-reference)
10. [Observability and Feedback Loop](#observability-and-feedback-loop)
11. [Debugging Playbook](#debugging-playbook)
12. [Auth Patterns](#auth-patterns)
13. [File Upload Patterns](#file-upload-patterns)
14. [Realtime Patterns](#realtime-patterns)
15. [Common App Recipes](#common-app-recipes)
16. [Extending the Stack](#extending-the-stack)
17. [What to Never Do](#what-to-never-do)

---

## Philosophy and Constraints

These rules are non-negotiable. They exist so an AI agent can always read the entire app in one pass, verify its own work without human input, and make targeted edits without side effects.

**Rule 1 — One file per app.**
The entire frontend lives in `pb_public/index.html`. No component files. No separate CSS. No JS modules. One file.

**Rule 2 — No build step.**
There is no compiler, bundler, or transpiler. The browser runs the file as-is. Editing the file and refreshing the browser is the entire deployment pipeline.

**Rule 3 — The running system is the source of truth.**
Do not infer state from reading code. Query Pocketbase directly to know what data exists. Make HTTP requests to verify that writes worked. Observe actual HTTP responses, not expected ones.

**Rule 4 — Every failure is structured text.**
All errors come back as JSON over HTTP. An agent must always read the response body, not just the status code.

**Rule 5 — Verify, do not assume.**
After every write operation, issue a read to confirm the record exists. After every schema change, query the collection to confirm the schema matches expectations.

---

## Tech Stack Overview

| Layer | Technology | Version | Delivery |
|---|---|---|---|
| Backend + DB + Auth + Files | Pocketbase | Latest stable | Single binary |
| Frontend interactivity | Alpine.js | 3.x | CDN |
| Server communication | HTMX | 2.x | CDN |
| Styling | Tailwind CSS | 3.x | CDN (Play) |
| PocketBase client SDK | PocketBase JS SDK | Latest | CDN |

**All frontend dependencies are loaded from CDN. There is no `package.json`, no `node_modules`, no build output.**

---

## Installation and Setup

### 1. Download Pocketbase

```bash
# macOS (Apple Silicon)
curl -L https://github.com/pocketbase/pocketbase/releases/latest/download/pocketbase_darwin_arm64.zip -o pb.zip
unzip pb.zip && rm pb.zip

# macOS (Intel)
curl -L https://github.com/pocketbase/pocketbase/releases/latest/download/pocketbase_darwin_amd64.zip -o pb.zip
unzip pb.zip && rm pb.zip

# Linux (amd64)
curl -L https://github.com/pocketbase/pocketbase/releases/latest/download/pocketbase_linux_amd64.zip -o pb.zip
unzip pb.zip && rm pb.zip

# Windows (amd64) — run in PowerShell
Invoke-WebRequest -Uri "https://github.com/pocketbase/pocketbase/releases/latest/download/pocketbase_windows_amd64.zip" -OutFile pb.zip
Expand-Archive pb.zip -DestinationPath .
```

To find the exact latest release URL:
```bash
curl -s https://api.github.com/repos/pocketbase/pocketbase/releases/latest \
  | grep browser_download_url
```

### 2. Create the Project Directory

```bash
mkdir my-app
cd my-app
mv /path/to/pocketbase .
mkdir -p pb_public
chmod +x pocketbase   # macOS/Linux only
```

### 3. Start Pocketbase

```bash
./pocketbase serve
# Windows: pocketbase.exe serve
```

Expected output:
```
Server started at http://127.0.0.1:8090
├─ REST API: http://127.0.0.1:8090/api/
└─ Admin UI: http://127.0.0.1:8090/_/
```

If port 8090 is in use:
```bash
./pocketbase serve --http="127.0.0.1:8091"
```

### 4. Create the Admin Account

On first run, visit `http://127.0.0.1:8090/_/` in a browser — or use the API:

```bash
# Create admin via CLI (works on all versions):
./pocketbase superuser upsert admin@local.dev password1234
```

Store these credentials. They are needed for schema operations.

### 5. Create `pb_public/index.html`

Create the file and Pocketbase serves it automatically at `http://127.0.0.1:8090/`.

```bash
touch pb_public/index.html
```

### 6. Optional — Live Reload

Install `browser-sync` for automatic browser refresh on file save:

```bash
npm install -g browser-sync

browser-sync start \
  --proxy "localhost:8090" \
  --files "pb_public/**" \
  --port 3000
```

Access the app at `http://localhost:3000` instead of `http://localhost:8090`. All API calls still go to port 8090 internally.

### 7. Verify the Setup

```bash
# Pocketbase is running
curl http://127.0.0.1:8090/api/health
# Expected: {"code":200,"message":"API is healthy."}

# Static file serving works
echo "<h1>Hello</h1>" > pb_public/index.html
curl http://127.0.0.1:8090/
# Expected: <h1>Hello</h1>
```

If either check fails, stop and diagnose before proceeding.

---

## Project Structure

```
my-app/
├── pocketbase              ← binary, never edit
├── pb_data/                ← auto-generated, never edit manually
│   ├── data.db             ← SQLite database
│   ├── logs.db             ← request logs
│   └── storage/            ← uploaded files
└── pb_public/
    └── index.html          ← THE ENTIRE APP — only file to edit
```

**An agent should only ever edit `pb_public/index.html`.** Everything else is managed by Pocketbase.

---

## Canonical App Template

This is the starting point for every app. Copy it verbatim, then modify.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>App Name</title>

  <!-- Tailwind CSS — utility classes, no build step -->
  <script src="https://cdn.tailwindcss.com"></script>

  <!-- HTMX — server interactions in HTML attributes -->
  <script src="https://unpkg.com/htmx.org@2.0.4"></script>

  <!-- Alpine.js — local reactive state in HTML -->
  <script defer src="https://unpkg.com/alpinejs@3.x.x/dist/cdn.min.js"></script>

  <!-- PocketBase JS SDK — typed client for the API -->
  <script src="https://cdn.jsdelivr.net/npm/pocketbase/dist/pocketbase.umd.js"></script>
</head>
<body class="bg-gray-50 min-h-screen font-sans">

  <!-- ============================================================
       GLOBAL ERROR TOAST
       Catches HTMX errors and surfaces them as visible messages.
       Agents: do not remove this block.
  ============================================================ -->
  <div id="toast"
       class="fixed top-4 right-4 z-50 hidden bg-red-500 text-white px-4 py-2 rounded shadow-lg text-sm">
  </div>

  <!-- ============================================================
       APP ROOT
       All state is declared here. All UI is inside this div.
       Agents: x-data is the single source of truth for this page.
  ============================================================ -->
  <div x-data="app()" x-init="init()" class="max-w-2xl mx-auto p-6">

    <!-- Loading state -->
    <div x-show="loading" class="text-center text-gray-400 py-12">Loading...</div>

    <!-- Error state -->
    <div x-show="error"
         x-text="error"
         class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded mb-4">
    </div>

    <!-- Main content — replace this with your app UI -->
    <div x-show="!loading">

      <h1 class="text-2xl font-bold text-gray-800 mb-6">App Name</h1>

      <!-- Items list -->
      <ul class="space-y-2 mb-6">
        <template x-for="item in items" :key="item.id">
          <li class="flex items-center justify-between bg-white border border-gray-200 rounded px-4 py-2">
            <span x-text="item.name"></span>
            <button @click="remove(item.id)"
                    class="text-red-400 hover:text-red-600 text-sm">
              Delete
            </button>
          </li>
        </template>
        <li x-show="items.length === 0" class="text-gray-400 text-sm">No items yet.</li>
      </ul>

      <!-- Add form -->
      <div class="flex gap-2">
        <input x-model="newName"
               @keydown.enter="add()"
               type="text"
               placeholder="New item..."
               class="flex-1 border border-gray-300 rounded px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
        <button @click="add()"
                class="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded text-sm font-medium">
          Add
        </button>
      </div>

    </div>
  </div>

  <!-- ============================================================
       SCRIPTS
       One PocketBase instance. One app() function.
       Agents: all data logic belongs in this block.
  ============================================================ -->
  <script>
    // PocketBase client — singleton, used everywhere
    const pb = new PocketBase(window.location.origin);

    // Global error display utility
    function showToast(msg) {
      const el = document.getElementById('toast');
      el.textContent = msg;
      el.classList.remove('hidden');
      setTimeout(() => el.classList.add('hidden'), 4000);
    }

    // HTMX global error handler
    document.body.addEventListener('htmx:responseError', e => {
      showToast(`Request failed: ${e.detail.xhr.status} ${e.detail.xhr.responseText}`);
    });

    // ── Debug logging ───────────────────────────────────────
    // Agents: wrap all SDK calls with console.log for observability.
    // Pattern: log the operation, the response, and any errors.
    // Users can check browser console (F12) to see what the agent sees.
    function debugLog(label, data) {
      console.log(`[${label}]`, data);
    }

    // Alpine app — all state and logic lives here
    function app() {
      return {
        // ── State ──────────────────────────────────────────────
        items: [],
        newName: '',
        loading: true,
        error: null,

        // ── Lifecycle ──────────────────────────────────────────
        async init() {
          try {
            const page = await pb.collection('items').getList(1, 200, {
              sort: '-id',
            });
            debugLog('init', { count: page.items.length, total: page.totalItems });
            this.items = page.items;
          } catch (err) {
            debugLog('init error', err);
            this.error = err.message;
          } finally {
            this.loading = false;
          }
        },

        // ── Actions ────────────────────────────────────────────
        async add() {
          if (!this.newName.trim()) return;
          try {
            const record = await pb.collection('items').create({
              name: this.newName.trim(),
            });
            this.items.unshift(record);
            this.newName = '';
          } catch (err) {
            showToast(err.message);
          }
        },

        async remove(id) {
          try {
            await pb.collection('items').delete(id);
            this.items = this.items.filter(i => i.id !== id);
          } catch (err) {
            showToast(err.message);
          }
        },
      }
    }
  </script>

</body>
</html>
```

---

## Pocketbase Reference

> **Version note:** This section reflects PocketBase v0.39+. Key changes from earlier versions:
> - Admin auth moved to `/api/collections/_superusers/auth-with-password` (old `/api/admins/auth-with-password` returns 404)
> - Schema management uses `fields` key (not `schema`) in collection create/PATCH requests
> - `getFullList()` sends `perPage=1000` which exceeds the v0.39 max of 200 — use `getList(1, 200, ...)` instead
> - Admin creation via CLI: `./pocketbase superuser upsert EMAIL PASS`

### Authentication

```bash
# Authenticate as admin (needed for schema operations)
# PocketBase v0.39+ uses the _superusers collection:
ADMIN_TOKEN=$(curl -s -X POST http://127.0.0.1:8090/api/collections/_superusers/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity":"admin@local.dev","password":"password1234"}' \
  | jq -r '.token')

# Verify token was retrieved (non-empty string)
echo "token len: ${#ADMIN_TOKEN}"
```

```javascript
// Authenticate a regular user in the frontend
await pb.collection('users').authWithPassword('user@example.com', 'password123');

// Check if currently authenticated
pb.authStore.isValid   // true or false
pb.authStore.model     // the user record, or null
pb.authStore.token     // the JWT token, or null

// Sign out
pb.authStore.clear();
```

### Schema Management via API

```bash
# List all collections
curl -s http://127.0.0.1:8090/api/collections \
  -H "Authorization: $ADMIN_TOKEN" | jq '.items[].name'

# Inspect a single collection (fields, rules, indexes)
curl -s http://127.0.0.1:8090/api/collections/todos \
  -H "Authorization: $ADMIN_TOKEN" | jq .

# Create a collection
# NOTE: Use "fields" (not "schema") for PocketBase v0.39+
curl -s -X POST http://127.0.0.1:8090/api/collections \
  -H "Content-Type: application/json" \
  -H "Authorization: $ADMIN_TOKEN" \
  -d '{
    "name": "todos",
    "type": "base",
    "fields": [
      { "name": "text",    "type": "text",    "required": true },
      { "name": "done",    "type": "bool" }
    ],
    "listRule": "",
    "viewRule": "",
    "createRule": "",
    "updateRule": "",
    "deleteRule": ""
  }'

# Add fields to an existing collection (PATCH appends new fields)
# NOTE: Only include NEW fields in the array, not existing ones.
# Existing fields are preserved. To modify an existing field,
# you must include ALL fields in the full array.
curl -s -X PATCH http://127.0.0.1:8090/api/collections/todos \
  -H "Content-Type: application/json" \
  -H "Authorization: $ADMIN_TOKEN" \
  -d '{"fields": [
    { "name": "priority", "type": "number" }
  ]}'

# Delete a collection
curl -s -X DELETE http://127.0.0.1:8090/api/collections/todos \
  -H "Authorization: $ADMIN_TOKEN"
```

### Field Types

| Type | Options | Example value |
|---|---|---|
| `text` | `min`, `max`, `pattern` | `"Buy milk"` |
| `number` | `min`, `max`, `noDecimal` | `42` |
| `bool` | — | `true` |
| `email` | — | `"user@example.com"` |
| `url` | — | `"https://example.com"` |
| `date` | `min`, `max` | `"2024-01-15 10:00:00"` |
| `select` | `values[]`, `maxSelect` | `"pending"` |
| `relation` | `collectionId`, `maxSelect` | `"recordid123"` |
| `file` | `maxSelect`, `maxSize`, `mimeTypes[]` | (multipart form) |
| `json` | — | `{"key": "value"}` |
| `editor` | — | `"<p>rich text</p>"` |

### CRUD via REST

```bash
# List records (paginated)
curl "http://127.0.0.1:8090/api/collections/todos/records?page=1&perPage=30"

# List records (paginated, max 200 per page in PB v0.39)
curl "http://127.0.0.1:8090/api/collections/todos/records?page=1&perPage=200"

# Filter records
curl "http://127.0.0.1:8090/api/collections/todos/records?filter=(done=false)"
curl "http://127.0.0.1:8090/api/collections/todos/records?filter=(text~'milk')"

# Sort records
# WARNING: Only sort by fields that exist on the collection.
# If the collection has no "created" field, use "id" instead.
curl "http://127.0.0.1:8090/api/collections/todos/records?sort=-id"
curl "http://127.0.0.1:8090/api/collections/todos/records?sort=+priority,-id"

# Expand a relation field
curl "http://127.0.0.1:8090/api/collections/todos/records?expand=user"

# Get a single record
curl "http://127.0.0.1:8090/api/collections/todos/records/RECORD_ID"

# Create a record
curl -X POST "http://127.0.0.1:8090/api/collections/todos/records" \
  -H "Content-Type: application/json" \
  -d '{"text": "Buy milk", "done": false}'

# Update a record (partial update)
curl -X PATCH "http://127.0.0.1:8090/api/collections/todos/records/RECORD_ID" \
  -H "Content-Type: application/json" \
  -d '{"done": true}'

# Delete a record
curl -X DELETE "http://127.0.0.1:8090/api/collections/todos/records/RECORD_ID"
```

### CRUD via PocketBase JS SDK

```javascript
const pb = new PocketBase('http://127.0.0.1:8090');

// Fetch records (paginated — max 200 per page in PB v0.39)
// NOTE: getFullList sends perPage=1000 which returns 400 on PB v0.39.
// Always use getList instead.
const page = await pb.collection('todos').getList(1, 200, {
  filter: 'done = false',
  sort: '-id',
});
// page.items, page.totalItems, page.totalPages

// For "get all" behavior, use getList with perPage=200 and loop if needed:
let all = [];
let page = 1;
while (true) {
  const result = await pb.collection('todos').getList(page, 200, { sort: '-id' });
  all = all.concat(result.items);
  if (result.items.length < 200) break;
  page++;
}

// Fetch one record
const record = await pb.collection('todos').getOne('RECORD_ID');

// Create
const newRecord = await pb.collection('todos').create({ text: 'Buy milk', done: false });

// Update
const updated = await pb.collection('todos').update('RECORD_ID', { done: true });

// Delete
await pb.collection('todos').delete('RECORD_ID');

// Filter syntax examples (use with getList — getFullList is broken on PB v0.39)
await pb.collection('todos').getList(1, 200, { filter: 'done = false' });
await pb.collection('todos').getList(1, 200, { filter: 'text ~ "milk"' });
await pb.collection('todos').getList(1, 200, { filter: 'created >= "2024-01-01"' });
```

### Filter Syntax

| Operator | Meaning | Example |
|---|---|---|
| `=` | equals | `done = true` |
| `!=` | not equals | `status != "archived"` |
| `>` `<` `>=` `<=` | comparison | `priority > 2` |
| `~` | contains (text) | `name ~ "milk"` |
| `!~` | not contains | `name !~ "deleted"` |
| `&&` | and | `done = false && priority > 1` |
| `\|\|` | or | `status = "active" \|\| status = "pending"` |

### API Rules

Rules control who can read/write records. An empty string `""` means anyone (including unauthenticated). A `null` means nobody.

```json
{
  "listRule":   "",                        
  "viewRule":   "",                        
  "createRule": "@request.auth.id != ''",  
  "updateRule": "@request.auth.id = user", 
  "deleteRule": "@request.auth.id = user"  
}
```

### Realtime Subscriptions

```javascript
// Subscribe to all changes in a collection
pb.collection('todos').subscribe('*', (e) => {
  console.log(e.action);  // "create" | "update" | "delete"
  console.log(e.record);  // the affected record
});

// Subscribe to a single record
pb.collection('todos').subscribe('RECORD_ID', (e) => {
  console.log(e.record);
});

// Unsubscribe
pb.collection('todos').unsubscribe();
```

---

## Alpine.js Reference

### Core Directives

```html
<!-- Declare state -->
<div x-data="{ count: 0, name: 'World' }">

  <!-- Bind events -->
  <button @click="count++">Click</button>
  <input @keydown.enter="submit()">
  <form @submit.prevent="handleSubmit()">

  <!-- Display values -->
  <span x-text="count"></span>
  <span x-html="'<b>' + name + '</b>'"></span>

  <!-- Bind attributes -->
  <input :value="name" :disabled="count === 0" :class="count > 5 ? 'text-red-500' : ''">

  <!-- Conditionals -->
  <div x-show="count > 0">Visible when count > 0</div>
  <div x-if="count > 0">Removed from DOM when false</div>

  <!-- Loops -->
  <template x-for="item in items" :key="item.id">
    <div x-text="item.name"></div>
  </template>

  <!-- Two-way binding -->
  <input x-model="name" type="text">
  <input x-model="checked" type="checkbox">
  <select x-model="selected">
    <option value="a">A</option>
  </select>

  <!-- Init hook -->
  <div x-init="console.log('mounted')"></div>

  <!-- Ref (access DOM element) -->
  <input x-ref="nameInput">
  <button @click="$refs.nameInput.focus()">Focus</button>

  <!-- Transition -->
  <div x-show="open" x-transition>Animated</div>

</div>
```

### Structuring the app() Function

```javascript
function app() {
  return {
    // ── Primitive state
    loading: false,
    error: null,
    filter: 'all',

    // ── Array state
    items: [],
    selected: [],

    // ── Computed (use getters)
    get filteredItems() {
      if (this.filter === 'all') return this.items;
      return this.items.filter(i => i.status === this.filter);
    },

    get isEmpty() {
      return this.items.length === 0;
    },

    // ── Lifecycle
    async init() {
      this.loading = true;
      try {
        const page = await pb.collection('items').getList(1, 200, { sort: '-id' });
        this.items = page.items;
      } catch (err) {
        this.error = err.message;
      } finally {
        this.loading = false;
      }
    },

    // ── Actions
    async create(data) { /* ... */ },
    async update(id, data) { /* ... */ },
    async remove(id) { /* ... */ },
  }
}
```

### Reading Alpine State for Debugging

```javascript
// In browser console: get the live state of the root Alpine component
Alpine.$data(document.querySelector('[x-data]'))
```

---

## HTMX Reference

HTMX is optional in this stack — the PocketBase JS SDK handles most interactions. Use HTMX when you want the server to return HTML fragments (useful for complex rendered lists).

### Core Attributes

```html
<!-- GET request, swap response into target -->
<div hx-get="/api/collections/todos/records"
     hx-target="#list"
     hx-swap="innerHTML"
     hx-trigger="load">
</div>

<!-- POST on click -->
<button hx-post="/api/collections/todos/records"
        hx-vals='{"text": "New todo", "done": false}'
        hx-target="#list"
        hx-swap="beforeend">
  Add
</button>

<!-- DELETE on click -->
<button hx-delete="/api/collections/todos/records/RECORD_ID"
        hx-target="#item-RECORD_ID"
        hx-swap="outerHTML swap:0.3s">
  Delete
</button>

<!-- Trigger on input with 300ms debounce -->
<input hx-get="/api/collections/todos/records"
       hx-trigger="input delay:300ms"
       hx-target="#list"
       name="filter">
```

### HTMX Swap Strategies

| Value | Effect |
|---|---|
| `innerHTML` | Replace target's content |
| `outerHTML` | Replace target element itself |
| `beforeend` | Insert before target's last child |
| `afterend` | Insert after target element |
| `delete` | Remove target from DOM |
| `none` | No DOM change |

### HTMX Global Event Listeners

Add these to the template once to capture all request lifecycle events:

```html
<script>
  document.body.addEventListener('htmx:beforeRequest', e => {
    console.log('[htmx] request:', e.detail.requestConfig);
  });
  document.body.addEventListener('htmx:afterRequest', e => {
    console.log('[htmx] response:', e.detail.xhr.status);
  });
  document.body.addEventListener('htmx:responseError', e => {
    console.error('[htmx] error:', e.detail.xhr.status, e.detail.xhr.responseText);
    showToast(`Error ${e.detail.xhr.status}: ${e.detail.xhr.responseText}`);
  });
</script>
```

---

## Tailwind Reference

This stack uses **Tailwind CDN (Play mode)**. All utility classes are available. Custom config can be added inline:

```html
<script>
  tailwind.config = {
    theme: {
      extend: {
        colors: {
          brand: '#6366f1',
        }
      }
    }
  }
</script>
```

### Most Common Utilities

```
Layout:     flex, grid, block, hidden, relative, absolute, fixed
Spacing:    p-4, px-6, py-2, m-4, mx-auto, gap-4, space-y-2
Sizing:     w-full, w-64, h-screen, min-h-screen, max-w-2xl
Colors:     bg-white, bg-gray-50, text-gray-800, text-red-500
Border:     border, border-gray-200, rounded, rounded-lg, shadow
Typography: text-sm, text-lg, font-bold, font-medium, truncate
State:      hover:bg-blue-600, focus:ring-2, disabled:opacity-50
```

---

## Observability and Feedback Loop

This is the core of how an AI agent verifies its own work.

### Step 1 — Check Pocketbase Health

```bash
curl -s http://127.0.0.1:8090/api/health
# Expected: {"code":200,"message":"API is healthy."}
```

If this fails: Pocketbase is not running. Start it with `./pocketbase serve`.

### Step 1.5 — Run the Verification Script

Every micro-app includes a `verify.sh` script. **Run it after every change.** It autonomously checks server health, auth, schema, sort field existence, and full CRUD — catching the most common bugs before they hit the browser.

```bash
./verify.sh
```

Expected output: `Results: 12 passed, 0 failed` / `ALL PASSED — app is healthy`

If any step fails, the script tells you exactly what's wrong and how to fix it. **Do not proceed until verify.sh exits 0.**

### Step 2 — Inspect the Schema

```bash
# Get admin token first (PB v0.39 uses _superusers collection)
ADMIN_TOKEN=$(curl -s -X POST http://127.0.0.1:8090/api/collections/_superusers/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity":"admin@local.dev","password":"password1234"}' | jq -r '.token')

# Verify token works — expect non-empty string
echo "token len: ${#ADMIN_TOKEN}"

# List all collections
curl -s http://127.0.0.1:8090/api/collections \
  -H "Authorization: $ADMIN_TOKEN" | jq '.items[].name'

# Inspect a single collection's fields
curl -s http://127.0.0.1:8090/api/collections/todos \
  -H "Authorization: $ADMIN_TOKEN" | jq '.fields[] | {name, type, required, system}'
```

**CRITICAL: Verify field names and types match what your code uses.** If your JS sorts by `-created`, the collection MUST have a `created` field. If it doesn't, use `-id` or add the field.

Use this to confirm collections exist before testing CRUD.

### Step 3 — Verify a Write Succeeded

Always read back after writing:

```bash
# Write
curl -s -X POST http://127.0.0.1:8090/api/collections/todos/records \
  -H "Content-Type: application/json" \
  -d '{"text": "test item", "done": false}' | jq .

# Read to confirm
curl -s "http://127.0.0.1:8090/api/collections/todos/records?filter=(text='test item')" \
  | jq '.items | length'
# Expected: 1
```

### Step 4 — Inspect Request Logs

Pocketbase logs every HTTP request. Query them:

```bash
# View recent API requests
curl -s "http://127.0.0.1:8090/api/logs/requests?perPage=20" \
  -H "Authorization: $ADMIN_TOKEN" | jq '.items[] | {method, url, status, remoteIp}'

# Filter to errors only
curl -s "http://127.0.0.1:8090/api/logs/requests?filter=(status>=400)&perPage=20" \
  -H "Authorization: $ADMIN_TOKEN" | jq '.items[] | {method, url, status, error}'
```

### Step 5 — Decode an Error Response

Pocketbase validation errors are structured:

```json
{
  "code": 400,
  "message": "Failed to create record.",
  "data": {
    "text": {
      "code": "validation_required",
      "message": "Cannot be blank."
    },
    "priority": {
      "code": "validation_number_out_of_range",
      "message": "Must be between 1 and 5."
    }
  }
}
```

The `data` field contains per-field errors. Fix each field before retrying.

### Step 6 — Read the Current File State

When in doubt about what the app currently does, read the file:

```bash
cat pb_public/index.html
```

The file is ground truth. The code in the browser is this file.

### Step 7 — End-to-End Smoke Test

**Always run this after creating or modifying a collection.** It catches schema mismatches, missing fields, and sort/filter errors before they hit the browser.

```bash
# 1. Create a test record
CREATE=$(curl -s -X POST http://127.0.0.1:8090/api/collections/todos/records \
  -H "Content-Type: application/json" \
  -d '{"text": "smoke test", "done": false}')
echo "$CREATE" | jq '{id: .id, text: .text, done: .done}'
ID=$(echo $CREATE | jq -r '.id')

# 2. Read it back
curl -s "http://127.0.0.1:8090/api/collections/todos/records/$ID" | jq '{id: .id, text: .text}'

# 3. List with the SAME sort your app uses (catches missing sort field)
curl -s "http://127.0.0.1:8090/api/collections/todos/records?page=1&perPage=200&sort=-id" | jq '.items | length'

# 4. Update it
curl -s -X PATCH "http://127.0.0.1:8090/api/collections/todos/records/$ID" \
  -H "Content-Type: application/json" \
  -d '{"done": true}' | jq '.done'

# 5. Delete it
curl -s -X DELETE "http://127.0.0.1:8090/api/collections/todos/records/$ID" -w " (HTTP %{http_code})"

# 6. Verify deletion (expect 404)
curl -s "http://127.0.0.1:8090/api/collections/todos/records/$ID" | jq '.message'
```

All 6 steps must pass. If any fails, fix the schema or code before proceeding.

### Step 8 — Confirm the Feedback Loop

The full loop (edit → verify) takes under 10 seconds:

```
1. Edit pb_public/index.html
2. Run the e2e smoke test (Step 7)
3. Confirm all 6 steps pass
4. Optionally: refresh the browser (or browser-sync does it automatically)
```

No build. No deploy. No waiting.

---

## Debugging Playbook

### Problem: "Failed to fetch" / network error in the browser

**Diagnosis:**
1. Is Pocketbase running? `curl http://127.0.0.1:8090/api/health`
2. Is the PocketBase URL in the code correct? Look for `new PocketBase('...')` — confirm the port matches the running server.
3. CORS issue? Pocketbase allows all origins by default. Check for custom `--corsOrigins` flag.

**Fix:** Confirm the PocketBase URL and that the server is running. Restart with `./pocketbase serve`.

---

### Problem: 400 Bad Request on create

**Diagnosis:**
```bash
curl -s -X POST http://127.0.0.1:8090/api/collections/COLLECTION/records \
  -H "Content-Type: application/json" \
  -d '{"field": "value"}' | jq '.data'
```
The `data` field shows which fields failed validation and why.

**Fix:** Check the schema — field names, required fields, type constraints. Confirm the payload matches the schema exactly (field names are case-sensitive).

---

### Problem: 400 Bad Request on list (getList / getFullList)

**Diagnosis:**
This usually means a sort field doesn't exist on the collection, or `perPage` exceeds the max (200 in PB v0.39).

```bash
# Check what fields exist
ADMIN_TOKEN=$(curl -s -X POST http://127.0.0.1:8090/api/collections/_superusers/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity":"admin@local.dev","password":"password1234"}' | jq -r '.token')
curl -s http://127.0.0.1:8090/api/collections/COLLECTION_NAME \
  -H "Authorization: $ADMIN_TOKEN" | jq '.fields[] | .name'

# Test the exact list query your app uses (replace -created with your sort field)
curl -s "http://127.0.0.1:8090/api/collections/COLLECTION_NAME/records?page=1&perPage=200&sort=-id" | jq '.items | length'

# If sort=-created fails but sort=-id works, the collection lacks a "created" field.
```

**Fix:** Either add a `created` autodate field to the collection, or change the sort in your JS to use a field that exists (e.g., `-id`). Also ensure `perPage` ≤ 200.

---

### Problem: 404 on a collection

**Diagnosis:**
```bash
curl -s http://127.0.0.1:8090/api/collections \
  -H "Authorization: $ADMIN_TOKEN" | jq '[.items[].name]'
```
Check if the collection exists and the name is spelled correctly.

**Fix:** Create the collection if missing (see Schema Management above). Fix the name if misspelled.

---

### Problem: 403 Forbidden

**Diagnosis:**
```bash
# Check the collection's API rules
curl -s http://127.0.0.1:8090/api/collections/COLLECTION_NAME \
  -H "Authorization: $ADMIN_TOKEN" \
  | jq '{listRule, viewRule, createRule, updateRule, deleteRule}'
```

If a rule is `null`, that operation is disabled for everyone. If a rule requires auth and the user is unauthenticated, it returns 403.

**Fix:** For personal apps with no auth, set all rules to `""` (empty string = public access). For auth-required apps, ensure `pb.authStore.isValid` is true before making requests.

---

### Problem: Alpine state not updating after an SDK call

**Diagnosis:**
The SDK call probably threw an error that was silently caught. Always log errors:

```javascript
async add() {
  try {
    const record = await pb.collection('todos').create({ text: this.newName });
    debugLog('add', { id: record.id, text: record.text });
    this.items.unshift(record);
  } catch (err) {
    debugLog('add error', err);
    showToast(err.message);
  }
}
```

**How to check:** Open browser console (F12 → Console tab). Look for `[add]` or `[add error]` entries. The error message points to the root cause.

**Agent action:** Ask the user to open browser console and paste any `[error]` lines. This gives the agent direct visibility into SDK failures.

---

### Problem: Records exist in the DB but UI shows empty

**Diagnosis:**
1. Confirm records exist: `curl http://127.0.0.1:8090/api/collections/todos/records?perPage=200 | jq '.items | length'`
2. Confirm the collection name in the JS matches exactly.
3. Confirm the API rule allows listing (should be `""` for public apps).
4. **Most common cause:** `init()` list query fails silently (e.g., sort field doesn't exist). Check browser console for `[init error]` entries.
5. Verify the sort field exists: `curl -s http://127.0.0.1:8090/api/collections/todos -H "Authorization: $ADMIN_TOKEN" | jq '.fields[] | .name'`

**Fix:** Use `debugLog('init error', err)` in the catch block. Check browser console. If sort field is missing, either add it to the collection or change the sort in JS to use an existing field.

---

### Problem: App works but changes disappear on refresh

**Diagnosis:**
State is being stored in Alpine's `x-data` but not persisted to Pocketbase. The create/update call is either missing or not awaited.

**Fix:** Confirm every mutation calls `await pb.collection(...).create/update/delete(...)` before updating local state. Local state (the `items` array) is always derived from what's in the database.

---

### Problem: Unsure if an edit to index.html took effect

**Diagnosis:**
```bash
# Check the file's last modified time
ls -la pb_public/index.html

# Check what's actually in the file
grep -n "keyword" pb_public/index.html
```

**Fix:** Hard-refresh the browser (Cmd+Shift+R / Ctrl+Shift+R) to bypass any cache.

---

## Auth Patterns

### Email/Password Auth (Single User Personal App)

```javascript
function app() {
  return {
    authed: false,
    email: '',
    password: '',
    authError: null,

    async init() {
      this.authed = pb.authStore.isValid;
      if (this.authed) await this.loadData();
    },

    async login() {
      try {
        await pb.collection('users').authWithPassword(this.email, this.password);
        this.authed = true;
        this.authError = null;
        await this.loadData();
      } catch (err) {
        this.authError = 'Invalid email or password.';
      }
    },

    logout() {
      pb.authStore.clear();
      this.authed = false;
      this.items = [];
    },

    async loadData() {
      this.items = await pb.collection('todos').getFullList();
    },
  }
}
```

```html
<!-- Login form — shown when not authed -->
<div x-show="!authed" class="max-w-sm mx-auto mt-20 space-y-4">
  <input x-model="email"    type="email"    placeholder="Email"    class="w-full border rounded px-3 py-2">
  <input x-model="password" type="password" placeholder="Password" class="w-full border rounded px-3 py-2">
  <p x-show="authError" x-text="authError" class="text-red-500 text-sm"></p>
  <button @click="login()" class="w-full bg-blue-500 text-white rounded py-2">Sign In</button>
</div>

<!-- App — shown when authed -->
<div x-show="authed">
  <button @click="logout()" class="text-sm text-gray-400">Sign out</button>
  <!-- ... rest of app ... -->
</div>
```

### Register a New User via API

```bash
curl -X POST http://127.0.0.1:8090/api/collections/users/records \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password1234",
    "passwordConfirm": "password1234"
  }'
```

### User-Scoped Data (Records Belong to a User)

When creating a record, attach the user's ID:

```javascript
await pb.collection('todos').create({
  text: this.newName,
  user: pb.authStore.model.id,  // attach current user
});
```

Set the API rule so users only see their own records:

```json
{
  "listRule":   "@request.auth.id = user",
  "viewRule":   "@request.auth.id = user",
  "createRule": "@request.auth.id != ''",
  "updateRule": "@request.auth.id = user",
  "deleteRule": "@request.auth.id = user"
}
```

---

## File Upload Patterns

### Schema Setup

```bash
curl -s -X POST http://127.0.0.1:8090/api/collections \
  -H "Content-Type: application/json" \
  -H "Authorization: $ADMIN_TOKEN" \
  -d '{
    "name": "wardrobe",
    "type": "base",
    "schema": [
      { "name": "name",  "type": "text" },
      { "name": "photo", "type": "file", "options": { "maxSelect": 1, "maxSize": 5242880, "mimeTypes": ["image/jpeg","image/png","image/webp"] } }
    ],
    "listRule": "", "viewRule": "", "createRule": "", "updateRule": "", "deleteRule": ""
  }'
```

### Upload via JS SDK

```javascript
async addItem(name, fileInput) {
  const formData = new FormData();
  formData.append('name', name);
  formData.append('photo', fileInput.files[0]);

  const record = await pb.collection('wardrobe').create(formData);
  this.items.unshift(record);
}
```

### Display an Uploaded File

```javascript
// Get the URL for a file field
const url = pb.files.getUrl(record, record.photo);
// Returns: http://127.0.0.1:8090/api/files/wardrobe/RECORD_ID/filename.jpg

// Get a thumbnail (resize on the fly)
const thumb = pb.files.getUrl(record, record.photo, { thumb: '100x100' });
```

```html
<img :src="pb.files.getUrl(item, item.photo, {thumb: '200x200'})"
     class="w-full h-48 object-cover rounded">
```

---

## Realtime Patterns

### Live Updates (Shopping List Sync Across Devices)

```javascript
async init() {
  this.items = await pb.collection('shopping').getFullList();

  // Subscribe to all changes
  pb.collection('shopping').subscribe('*', (e) => {
    if (e.action === 'create') {
      this.items.unshift(e.record);
    }
    if (e.action === 'update') {
      const idx = this.items.findIndex(i => i.id === e.record.id);
      if (idx !== -1) this.items[idx] = e.record;
    }
    if (e.action === 'delete') {
      this.items = this.items.filter(i => i.id !== e.record.id);
    }
  });
},
```

Realtime works over SSE (Server-Sent Events). No configuration required. The subscription is automatically cleaned up when the page unloads.

---

## Common App Recipes

### Todo List

Collections needed:
```
todos: { text: text/required, done: bool }
```

Key patterns: toggle `done` on click, filter by `done = false`.

### Recipe Book

Collections needed:
```
recipes:      { title: text/required, description: text, servings: number, photo: file }
ingredients:  { recipe: relation(recipes)/required, name: text/required, amount: text, unit: text }
steps:        { recipe: relation(recipes)/required, order: number, instruction: text }
```

Key patterns: expand relations, display steps sorted by `order`, file upload for photos.

### Closet Manager

Collections needed:
```
clothing: { name: text/required, category: select(tops/bottoms/shoes/accessories), color: text, photo: file, worn_count: number }
```

Key patterns: file upload, select filter by category, increment `worn_count` on "wear today" action.

### Shopping List

Collections needed:
```
lists:     { name: text/required }
list_items: { list: relation(lists)/required, name: text/required, quantity: text, checked: bool }
```

Key patterns: realtime subscription (sync across devices), group by `checked`, batch-uncheck all.

### Reading Tracker

Collections needed:
```
books: { title: text/required, author: text, status: select(to-read/reading/finished), rating: number, notes: text, cover: file, started: date, finished: date }
```

Key patterns: filter by `status`, star rating UI with Alpine, date tracking.

---

## Extending the Stack

### Add a Second Page (Without a Router Library)

```javascript
function app() {
  return {
    page: 'list',   // 'list' | 'detail' | 'settings'
    selected: null,
    // ...

    showDetail(item) {
      this.selected = item;
      this.page = 'detail';
    },
    back() {
      this.page = 'list';
      this.selected = null;
    }
  }
}
```

```html
<div x-show="page === 'list'">   <!-- list view --> </div>
<div x-show="page === 'detail'"> <!-- detail view --> </div>
```

### Add a Web Component for Reuse

```html
<script>
  class StarRating extends HTMLElement {
    connectedCallback() {
      const rating = parseInt(this.getAttribute('value') || 0);
      this.innerHTML = [1,2,3,4,5]
        .map(n => `<span style="cursor:pointer;color:${n<=rating?'gold':'#ccc'}"
                        onclick="this.dispatchEvent(new CustomEvent('rate',{bubbles:true,detail:${n}}))"
                   >★</span>`)
        .join('');
    }
  }
  customElements.define('star-rating', StarRating);
</script>

<!-- Usage -->
<star-rating value="3" @rate="item.rating = $event.detail"></star-rating>
```

### Sync URL with App State (Bookmarkable URLs)

```javascript
init() {
  // Read state from URL on load
  const params = new URLSearchParams(window.location.search);
  this.filter = params.get('filter') || 'all';
  this.page   = params.get('page')   || 'list';
},

// Call this whenever state changes
updateURL() {
  const params = new URLSearchParams({ filter: this.filter, page: this.page });
  history.replaceState({}, '', '?' + params.toString());
},
```

---

## What to Never Do

These patterns break the stack's core properties and must be avoided.

| Never do this | Reason |
|---|---|
| Split code into multiple `.js` or `.css` files | Breaks the single-file constraint; agents lose context |
| Use React, Vue, or Svelte | Requires a build step; generates many files by default |
| Use TypeScript | Requires a compiler; adds a failure point between edit and verify |
| Use `localStorage` as primary storage | Data isn't queryable, isn't shared across devices, isn't structured |
| Use an ORM or query builder | Pocketbase's REST API already is an ORM |
| Build a custom backend | Pocketbase already provides auth, CRUD, files, and realtime |
| Add a Docker container | Pocketbase is a single binary; Docker adds friction with no benefit |
| Store secrets in `index.html` | The file is served publicly; never put API keys or admin passwords here |
| Mutate `pb_data/` directly | Always go through the API or admin UI; direct DB edits bypass validation |
| Ignore error responses | Always read `err.message` and `err.data`; never assume a request succeeded |
| Skip verification after changes | Always run `./verify.sh` after editing code or schema; catches bugs in 5 seconds |

---

## Quick Reference Card

```bash
# Start Pocketbase
./pocketbase serve

# Health check
curl http://127.0.0.1:8090/api/health

# Get admin token (PB v0.39+)
ADMIN_TOKEN=$(curl -s -X POST http://127.0.0.1:8090/api/collections/_superusers/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity":"admin@local.dev","password":"password1234"}' | jq -r '.token')

# List collections
curl -s http://127.0.0.1:8090/api/collections \
  -H "Authorization: $ADMIN_TOKEN" | jq '[.items[].name]'

# List records
curl -s "http://127.0.0.1:8090/api/collections/COLLECTION/records" | jq '.items'

# Create record
curl -s -X POST "http://127.0.0.1:8090/api/collections/COLLECTION/records" \
  -H "Content-Type: application/json" -d '{"field": "value"}' | jq .

# Update record
curl -s -X PATCH "http://127.0.0.1:8090/api/collections/COLLECTION/records/ID" \
  -H "Content-Type: application/json" -d '{"field": "new_value"}' | jq .

# Delete record
curl -s -X DELETE "http://127.0.0.1:8090/api/collections/COLLECTION/records/ID"

# View recent errors
curl -s "http://127.0.0.1:8090/api/logs/requests?filter=(status>=400)&perPage=10" \
  -H "Authorization: $ADMIN_TOKEN" | jq '.items[] | {method,url,status}'

# Edit the app
# (just open pb_public/index.html)

# Live reload (optional)
npx browser-sync start --proxy "localhost:8090" --files "pb_public/**"
```
