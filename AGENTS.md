# Apple Calendar MCP Agents

This repository exposes a local MCP server named `apple_calendar` through `opencode.json`.

## Local validation guidance

- Prefer read operations first.
- If testing write operations, create clearly labeled temporary calendars or events and clean them up afterward.
- Prefer temporary test events over modifying existing recurring or attendee-bearing events.
- If macOS Calendar permission is denied, report that explicitly instead of treating it as a generic MCP failure.

## Expected tool scope

The server exposes tools for:

- calendar sources and default calendar discovery
- calendar CRUD
- bounded event queries
- event CRUD
- bulk event mutations
