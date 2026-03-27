---
name: integration-testing
description: End-to-end integration testing using Playwright browser automation. Tests any project, creates ClickUp issues for findings, moves failing tasks back with evidence, self-improves test patterns. Use when user says "integration test", "test the app", "QA this board", "browser test", or "run E2E tests".
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task, Skill, WebSearch
user-invocable: true
version: 1.0.0
created: 2026-03-13
---

# Integration Testing - Playwright Browser Automation + ClickUp QA

**Purpose:** Test any application end-to-end using Playwright browser automation, create ClickUp issues for findings, move failing tasks back with evidence, and self-improve testing patterns over time.

## When to Use This Skill

**Use when:**
- User says "integration test [project]", "test the app", "QA this board"
- User says "browser test", "run E2E tests", "test [project] in browser"
- User wants to verify TESTING tasks actually work
- User wants exploratory testing of an application
- After a deployment to verify everything works
- User says "smoke test" or "regression test"

**Don't use when:**
- Running unit tests or dotnet test (use integration-testing-workflow memory)
- Simple API testing (use curl/Bash directly)
- Task management only (use ClickUp workflow skills)

## Prerequisites

- Playwright MCP tools available (browser_navigate, browser_snapshot, etc.)
- ClickUp API configured in `C:\scripts\_machine\clickup-config.json`
- Project configured in clickup-config.json `projects` section
- State file: `C:\scripts\agentidentity\state\integration-testing-state.yaml`

## Input Parsing

Parse the user's command to extract:
1. **Project name** - match against clickup-config.json keys (fuzzy: "personality" → "personalitytest")
2. **Scope** - "all", specific task ID, or "exploratory"
3. **Mode** - "qa" (test TESTING tasks), "exploratory" (page-by-page), "smoke" (critical paths only)

Default: If only project name given, use "qa" mode (test TESTING tasks first, then exploratory).

---

## Phase 1: Project Discovery

**Objective:** Identify the project, its configuration, and current state.

```
1. Read C:\scripts\_machine\clickup-config.json
2. Find project by name/alias (fuzzy match against projects keys and names)
3. Extract:
   - list_id (for ClickUp API)
   - type (fullstack/wordpress/frontend)
   - local_path
   - ports (api, frontend)
   - statuses (for status name matching)
   - github repo URL
4. Read integration-testing-state.yaml for cached project knowledge
5. Check if project has known pages, login flows, navigation structure
```

**Output: Project Profile**
```markdown
## Project Profile
**Name:** [name]
**Type:** [fullstack/wordpress/frontend]
**List ID:** [id]
**Ports:** API=[port], Frontend=[port]
**Local Path:** [path]
**Known Pages:** [count from state] or "First run - will discover"
```

---

## Phase 2: Application Startup & Health Check

**Objective:** Ensure the application is running and accessible.

**Strategy: Check first, start only if needed.**

### Step 1: Check if already running

```
For each port in project config:
  - browser_navigate to http://localhost:[port]
  - If page loads → mark as RUNNING
  - If connection refused → mark as NOT RUNNING
```

### Step 2: Start services if needed

**ASP.NET + React (fullstack type):**
```
Backend:
  - cd [local_path]
  - dotnet run --urls "http://localhost:[api_port]" &
  - Wait up to 60s, check health: browser_navigate http://localhost:[api_port]/health
  - Or check: browser_navigate http://localhost:[api_port]/swagger

Frontend:
  - cd [local_path]/frontend (or ClientApp, client, etc.)
  - npm run dev -- --port [frontend_port] &
  - Wait up to 60s, check: browser_navigate http://localhost:[frontend_port]
```

**WordPress (wordpress type):**
```
  - Verify Apache running: browser_navigate to http://localhost/[project]
  - If 404/503: warn user XAMPP Apache needs to be started manually
```

**React SPA (frontend type):**
```
  - cd [local_path]
  - npm run dev &
  - Wait up to 60s for Vite ready message
```

### Step 3: Health verification

```
For EACH service that should be running:
  1. browser_navigate to expected URL
  2. browser_snapshot to verify content loaded (not error page)
  3. browser_console_messages(level: "error") to check for startup errors
  4. If health check fails after 60s → Create BLOCKED finding, abort that service
```

**IMPORTANT:** If the application is NOT running and cannot be started, report this clearly
and switch to code-only analysis mode (grep through source for obvious issues).

---

## Phase 3: ClickUp Task Analysis

**Objective:** Build a test plan from TESTING tasks.

### Step 1: Fetch TESTING tasks

```python
# Use ClickUp API to get tasks in TESTING status
GET https://api.clickup.com/api/v2/list/{list_id}/task?statuses[]=testing

# Handle status name variations per board:
# Some boards use "testing", others "Testing", others have different casing
# Use the statuses array from clickup-config.json to find the exact match
```

### Step 2: For each TESTING task, extract test scenarios

```
Read task description and comments. Look for:
- "Testing Steps" or "Test Steps" section
- "Acceptance Criteria" section
- "How to Test" section
- Numbered lists that describe user actions
- URLs or page references

If task has structured test steps → use them directly
If task has acceptance criteria only → derive test steps from criteria
If task has neither → derive test steps from task title and description
```

### Step 3: Build test plan

```
For each task:
  - task_id
  - task_name
  - test_scenarios: [{description, steps, expected_result}]
  - priority (from ClickUp priority field)
  - relevant_pages (extracted from description)

Order by: priority (urgent first), then by dependency (login before protected pages)
```

### Step 4: If NO TESTING tasks found

Switch to **Exploratory Testing Mode**:
- No specific tasks to verify
- Will systematically test every reachable page
- Focus on: navigation, forms, console errors, network failures, responsive design

---

## Phase 4: Playwright Testing

### 4A: Task-Based Testing (QA Mode)

**For each task in the test plan:**

```
1. LOG: "Testing task: [task_name] ([task_id])"

2. NAVIGATE to relevant page:
   - browser_navigate(url)
   - browser_wait_for(text: expected_content, time: 10)

3. CAPTURE baseline:
   - browser_snapshot() → save accessibility tree
   - browser_take_screenshot(type: "png") → visual evidence

4. EXECUTE test scenarios:
   For each scenario:
     a. Perform actions: browser_click, browser_type, browser_fill_form, browser_select_option
     b. Wait for result: browser_wait_for(text/textGone)
     c. Verify state: browser_snapshot()
     d. Check errors: browser_console_messages(level: "error")
     e. Check network: browser_network_requests(includeStatic: false)
     f. Screenshot result: browser_take_screenshot(type: "png")

5. VERDICT per scenario:
   - PASS: Expected result achieved, no console errors, no failed requests
   - FAIL: Expected result NOT achieved OR console errors OR failed network requests
   - PARTIAL: Some expectations met, others not
   - BLOCKED: Cannot test (page not accessible, prerequisite failed)

6. AGGREGATE task verdict:
   - All scenarios PASS → task PASS
   - Any scenario FAIL → task FAIL
   - Mix → task PARTIAL
   - Cannot test → task BLOCKED

7. COLLECT evidence:
   - Screenshots (before/after)
   - Console error messages
   - Failed network requests (URL, status code, response)
   - Accessibility snapshot of failure state
```

### 4B: Exploratory Testing Mode

**Systematic page-by-page exploration:**

```
1. START at application root:
   - browser_navigate(root_url)
   - browser_snapshot() → extract ALL links and navigation elements

2. BUILD site map:
   - Extract all <a href>, button[onclick], nav links from snapshot
   - Categorize: navigation, forms, actions, external links
   - Filter: only internal links (same domain/port)

3. FOR EACH discovered page:
   a. browser_navigate(page_url)
   b. browser_snapshot() → check page loaded
   c. browser_console_messages(level: "error") → check for JS errors
   d. browser_network_requests(includeStatic: false) → check for failed API calls
   e. browser_take_screenshot(type: "png") → visual evidence
   f. Test interactive elements:
      - Click buttons (non-destructive ones)
      - Check form validation (submit empty, submit invalid)
      - Test dropdowns and selectors
   g. Record: page_url, title, has_errors, error_details, interactive_elements

4. RESPONSIVE testing (on key pages):
   - browser_resize(width: 375, height: 812)  → mobile
   - browser_snapshot() + browser_take_screenshot()
   - browser_resize(width: 768, height: 1024) → tablet
   - browser_snapshot() + browser_take_screenshot()
   - browser_resize(width: 1920, height: 1080) → desktop
   - browser_snapshot() + browser_take_screenshot()

5. COMMON FLOW testing:
   - Login flow (if applicable): navigate to login, fill credentials, submit
   - CRUD operations: create, read, update, delete (if safe/testable)
   - Search functionality: search for known term, verify results
   - Navigation: verify all nav links work, breadcrumbs, back button
   - Error handling: navigate to /nonexistent, verify 404 page
```

### Console Error Severity Classification

```
CRITICAL (blocks task):
  - Uncaught TypeError / ReferenceError / SyntaxError
  - Failed to fetch / NetworkError (on primary API calls)
  - React/Vue error boundaries triggered
  - White screen / blank page

HIGH (fails task):
  - 4xx/5xx API responses on user actions
  - Missing required elements in snapshot
  - Form submission failures
  - Authentication/authorization errors

MEDIUM (noted, doesn't fail):
  - Console warnings about deprecated APIs
  - Non-critical resource loading failures (fonts, analytics)
  - React hydration warnings
  - Minor CSS/layout issues

LOW (informational):
  - Development-mode warnings
  - Source map loading failures
  - Third-party script errors (ads, analytics)
```

---

## Phase 5: Issue Discovery & Task Management

### 5A: Decision Tree for Tested Tasks

```
For each tested ClickUp task:

IF verdict == PASS:
  → Leave in TESTING status
  → Add comment:
    "INTEGRATION TEST PASSED

    **Tested:** [date]
    **Scenarios:** [count] passed
    **Evidence:**
    - All test scenarios verified successfully
    - No console errors detected
    - No failed network requests
    - Screenshots attached

    **Tested scenarios:**
    1. [scenario description] - PASS
    2. [scenario description] - PASS
    ..."

IF verdict == FAIL (bug in implementation):
  → Move task to "todo" status
  → Add comment:
    "INTEGRATION TEST FAILED - Returning to TODO

    **Tested:** [date]
    **Failed scenarios:**
    1. [scenario]: [what went wrong]
       - Expected: [expected]
       - Actual: [actual]
       - Console errors: [errors]
       - Network failures: [failures]

    **Steps to reproduce:**
    1. Navigate to [url]
    2. [action]
    3. [observe failure]

    **Evidence:** [screenshot references]

    **Suggested fix:** [if obvious from error messages]"

IF verdict == FAIL (unclear spec / ambiguous requirement):
  → Move task to "feedback" or "needs input" status
  → Add comment:
    "INTEGRATION TEST - NEEDS CLARIFICATION

    **Issue:** Cannot determine if behavior is correct or incorrect.
    **Observed behavior:** [description]
    **Possible interpretations:**
    1. [interpretation A] → would be a PASS
    2. [interpretation B] → would be a FAIL

    **Question:** [specific question about expected behavior]"

IF verdict == BLOCKED:
  → Move task to "blocked" status
  → Add comment:
    "INTEGRATION TEST BLOCKED

    **Reason:** [why testing was impossible]
    **Blocker:** [specific blocker - service down, prerequisite missing, etc.]
    **Required to unblock:** [specific action needed]"

IF verdict == PARTIAL:
  → Move task to "todo" status
  → Add comment:
    "INTEGRATION TEST PARTIAL - Returning to TODO

    **Passed:**
    1. [scenario] - PASS
    2. [scenario] - PASS

    **Failed:**
    1. [scenario] - FAIL: [details]

    **Action needed:** Fix the failing scenarios while keeping passing ones intact."
```

### 5B: New Issue Discovery (not related to existing tasks)

```
For issues found during testing that don't belong to any TESTING task:

1. Create NEW ClickUp task:
   POST https://api.clickup.com/api/v2/list/{list_id}/task
   {
     "name": "[QA] [Concise bug title]",
     "description": "## Bug Report (Integration Test)\n\n**Discovered:** [date]\n**Severity:** [CRITICAL/HIGH/MEDIUM/LOW]\n**Page:** [URL]\n\n## Steps to Reproduce\n1. Navigate to [URL]\n2. [action]\n3. [observe]\n\n## Expected Behavior\n[what should happen]\n\n## Actual Behavior\n[what actually happens]\n\n## Evidence\n- Console errors: [errors]\n- Network failures: [failures]\n- Screenshot: [reference]\n\n## Environment\n- Browser: Chromium (Playwright)\n- Viewport: [dimensions]\n- Testing mode: [qa/exploratory]",
     "priority": [1-4 based on severity],
     "tags": ["qa-discovered", "integration-test"],
     "status": "todo"
   }

2. Priority mapping:
   CRITICAL → priority: 1 (Urgent) - App crashes, data loss, security issues
   HIGH     → priority: 2 (High)   - Feature broken, blocking user flow
   MEDIUM   → priority: 3 (Normal) - UI issues, non-blocking errors
   LOW      → priority: 4 (Low)    - Cosmetic issues, minor improvements
```

### 5C: Absolute Rules

```
NEVER:
  - Move a task to "done" (only the user/manual QA does this)
  - Skip adding evidence to comments
  - Act on a task without reading its latest comments first
  - Create duplicate tasks (check existing tasks by title similarity first)
  - Test destructive operations without confirmation (delete, reset, etc.)

ALWAYS:
  - Add detailed comments with evidence for every verdict
  - Include steps to reproduce for every failure
  - Include console errors and network failures in evidence
  - Use Python with requests for ClickUp API calls (batch operations)
  - Read the task's latest comment before deciding on action
  - Check if a similar [QA] task already exists before creating new ones
```

---

## Phase 6: Self-Improvement

**After each testing session, update knowledge:**

### 6A: Update State File

```yaml
# Update C:\scripts\agentidentity\state\integration-testing-state.yaml

project_knowledge:
  [project_name]:
    pages_discovered:
      - url: "/admin"
        title: "Admin Dashboard"
        has_login: true
        interactive_elements: ["form#login", "button.submit"]
    navigation_structure:
      - label: "Home"
        url: "/"
        children: [...]
    login_flow:
      url: "/login"
      username_field: "input[name=email]"
      password_field: "input[name=password]"
      submit_button: "button[type=submit]"
    common_errors:
      - pattern: "Failed to fetch"
        cause: "Backend not running"
        frequency: 3
    ports:
      api: 5000
      frontend: 5173
    last_tested: "2026-03-13"
```

### 6B: Pattern Learning (Kaizen Integration)

```
After each session, classify signals:

ERROR signals:
  - Test that was expected to pass but failed → log as ERROR
  - Application startup failure → log as ERROR
  - ClickUp API failure → log as ERROR

SUCCESS signals:
  - Clean pass on all tasks → log as SUCCESS
  - New page discovered and tested → log as SUCCESS
  - Issue correctly identified and reported → log as SUCCESS

PATTERN signals:
  - Same console error across multiple pages → log as PATTERN
  - Same network failure pattern → log as PATTERN
  - Same UI issue across responsive breakpoints → log as PATTERN

When a pattern reaches 3+ occurrences:
  → Promote from candidates to learned_patterns in state YAML
  → Log kaizen STANDARD signal for codification
```

### 6C: Expert Analysis for Ambiguous Failures

```
IF a failure cannot be classified (not clearly a bug or spec issue):
  → Invoke expert-analysis skill with:
    - Failure description
    - Console errors
    - Network traces
    - Expected vs actual behavior
    - Task description context
  → Use mastermind verdict to determine: bug, spec gap, or environment issue
```

---

## Phase 7: Reporting

**Generate comprehensive test report after all testing is complete.**

```markdown
# Integration Test Report - [Project Name]

**Date:** [date]
**Mode:** [qa/exploratory/smoke]
**Duration:** [time taken]

## Summary
- **Tasks Tested:** [count]
- **Passed:** [count] ([percentage]%)
- **Failed:** [count] ([percentage]%)
- **Blocked:** [count]
- **New Issues Created:** [count]

## Task Results

| Task | Status | Verdict | Details |
|------|--------|---------|---------|
| [name] | [old status → new status] | PASS/FAIL | [1-line summary] |

## New Issues Discovered

| Issue | Severity | Page | Status |
|-------|----------|------|--------|
| [QA] [title] | CRITICAL/HIGH/MEDIUM/LOW | [url] | Created |

## Page Coverage

| Page | Tested | Console Errors | Network Errors | Responsive |
|------|--------|---------------|----------------|------------|
| / | Yes | 0 | 0 | Yes |
| /admin | Yes | 2 | 1 | No |

## Console Errors Summary
[List all unique console errors found, grouped by severity]

## Network Failures Summary
[List all failed network requests, grouped by endpoint]

## Recommendations
1. [Priority recommendation based on findings]
2. [Secondary recommendation]

## Self-Improvement Notes
- Patterns learned: [count new, count promoted]
- Pages cached: [count]
- Coverage: [tested pages] / [known pages] ([percentage]%)
```

---

## ClickUp API Patterns

### Fetch tasks by status

```python
import json, requests

with open('C:/scripts/_machine/clickup-config.json', 'r') as f:
    config = json.load(f)

api_key = config['api_key']
headers = {'Authorization': api_key, 'Content-Type': 'application/json'}
list_id = config['projects'][PROJECT_NAME]['list_id']

# Get tasks in testing status
response = requests.get(
    f'https://api.clickup.com/api/v2/list/{list_id}/task',
    headers=headers,
    params={'statuses[]': ['testing'], 'include_closed': 'false'}
)
tasks = response.json().get('tasks', [])
```

### Update task status

```python
def update_task_status(task_id, new_status):
    response = requests.put(
        f'https://api.clickup.com/api/v2/task/{task_id}',
        headers=headers,
        json={'status': new_status}
    )
    return response.status_code in [200, 201]
```

### Add comment to task

```python
def add_task_comment(task_id, comment_text):
    response = requests.post(
        f'https://api.clickup.com/api/v2/task/{task_id}/comment',
        headers=headers,
        json={'comment_text': comment_text}
    )
    return response.status_code in [200, 201]
```

### Create new task

```python
def create_qa_task(list_id, name, description, priority, tags):
    response = requests.post(
        f'https://api.clickup.com/api/v2/list/{list_id}/task',
        headers=headers,
        json={
            'name': name,
            'description': description,
            'priority': priority,
            'tags': tags,
            'status': 'todo'
        }
    )
    if response.status_code in [200, 201]:
        task = response.json()
        return task['id'], task['url']
    return None, None
```

### Get task comments (read latest before acting)

```python
def get_task_comments(task_id):
    response = requests.get(
        f'https://api.clickup.com/api/v2/task/{task_id}/comment',
        headers=headers
    )
    return response.json().get('comments', [])
```

---

## Error Recovery

### Application won't start
```
1. Check if port is already in use (another process)
2. Check for build errors: dotnet build / npm run build
3. Report as BLOCKED with specific error message
4. Switch to code-only analysis mode if possible
```

### Playwright can't reach page
```
1. Verify URL is correct (check port, path)
2. Check if CORS or auth is blocking
3. Try with/without trailing slash
4. Report as BLOCKED with connection error
```

### ClickUp API errors
```
1. Check API key validity
2. Check list_id exists
3. Check status name matches exactly (case-sensitive)
4. Fall back to finding correct status name from list statuses endpoint
5. If persistent failure, report errors but continue testing
```

### Unexpected dialog/popup
```
1. browser_handle_dialog(accept: true) to dismiss
2. Log the dialog text as a finding
3. Continue testing
```

---

## Integration Points

```
integration-testing (this skill - orchestrator)
  |
  +-- Playwright MCP (browser_*) ......... UI testing, screenshots, interaction
  +-- ClickUp API (REST via Python) ...... Task management, comments, new issues
  +-- expert-analysis (Skill) ............ Ambiguous failure diagnosis
  +-- kaizen (MICRO signals) ............. Learning after each session
  +-- continuous-retrospective ........... Session data feeds pattern mining
  +-- clickup-refinement (Skill) ......... Refine newly discovered [QA] issues
  +-- implement-todo (Skill) ............. Consumes rework tasks returned to TODO
  +-- task-review (Skill) ................ Re-reviews after rework complete
```

---

## Quick Reference

| Command | Action |
|---------|--------|
| `/integration-testing personalitytest` | QA mode: test TESTING tasks + exploratory |
| `/integration-testing bliek exploratory` | Exploratory: page-by-page testing |
| `/integration-testing datadrivenai smoke` | Smoke: critical paths only |
| `/integration-testing personalitytest 86abcdef` | Test specific task ID |
