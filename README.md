# Apple Calendar MCP

<p align="center">
  <img src="docs/logo.png" alt="Apple Calendar MCP logo" width="900">
</p>

[![CI](https://github.com/orshemtov/apple-calendar-mcp/actions/workflows/ci.yml/badge.svg)](https://github.com/orshemtov/apple-calendar-mcp/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Swift](https://img.shields.io/badge/swift-6.2-orange)](https://swift.org)

An MCP server for Apple Calendar on macOS, built with Swift, the official MCP Swift SDK, and EventKit.

## Features

| Area | Tools |
| --- | --- |
| Sources | `list_sources`, `get_default_calendar` |
| Calendars | `list_calendars`, `get_calendar`, `create_calendar`, `update_calendar`, `delete_calendar` |
| Events | `list_events`, `list_upcoming_events`, `get_event`, `create_event`, `update_event`, `bulk_delete_events`, `bulk_move_events`, `delete_event` |

- Structured MCP responses for agent-friendly automation
- macOS-native calendar access through EventKit
- Event alarms, recurrence, structured location, and availability support in v1

## Requirements

- macOS 13+
- A local macOS user account with Calendar available on that machine
- Calendar permission granted to the executable that runs the server

## Homebrew

Install:

```bash
brew install orshemtov/brew/apple-calendar-mcp
```

Run:

```bash
apple-calendar-mcp --help
```

Upgrade after new releases:

```bash
brew update
brew upgrade apple-calendar-mcp
```

Homebrew does not update the binary on your machine automatically in the background. New versions become available after the tap formula is updated for a release, and users then upgrade with `brew upgrade`.

Maintainers can find the release and tap automation notes in `docs/homebrew.md`.

## MCP Client Setup

### Claude Code

Add the server with Claude Code's native MCP command:

```bash
claude mcp add --transport stdio apple-calendar -- apple-calendar-mcp
```

Check that it is available:

```bash
claude mcp list
```

### OpenCode

Add this to your `opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "apple-calendar": {
      "type": "local",
      "command": ["apple-calendar-mcp"],
      "enabled": true
    }
  }
}
```

### Codex

Add the server with Codex's native MCP command:

```bash
codex mcp add apple-calendar -- apple-calendar-mcp
```

You can also configure it manually in `~/.codex/config.toml`:

```toml
[mcp_servers.apple-calendar]
command = "apple-calendar-mcp"
```

### GitHub Copilot CLI

Use Copilot CLI's built-in MCP flow:

```text
/mcp add
```

Then enter:

- Server Name: `apple-calendar`
- Server Type: `STDIO`
- Command: `apple-calendar-mcp`
- Tools: `*`

If you prefer editing the config directly, add this to `~/.copilot/mcp-config.json`:

```json
{
  "mcpServers": {
    "apple-calendar": {
      "type": "local",
      "command": "apple-calendar-mcp",
      "args": [],
      "env": {},
      "tools": ["*"]
    }
  }
}
```

## Permissions

- This server reads and writes the Calendar database of the Mac where it is running.
- The Calendar app does not need to stay open, but calendar data must exist on that Mac through a local or synced account.
- On first run, macOS prompts for Calendar access.
- If access was denied before, re-enable it in `System Settings > Privacy & Security > Calendars` for the terminal or app that launches the server.

## Example Prompts

- "Show my events for tomorrow"
- "Create a meeting next Tuesday from 2pm to 3pm called Product Review"
- "Move these three events to my Travel calendar"
- "List upcoming all-day events this month"

## Notes

- v1 supports calendar CRUD, bounded event queries, event CRUD, bulk event move/delete, availability, alarms, recurrence, and structured locations.
- v1 exposes organizer and attendee metadata as read-only event fields.
- v1 does not currently expose invitation workflows, RSVP changes, arbitrary attachments, or provider-specific conferencing metadata.
- Event identifiers can change after some provider sync or cross-calendar move operations, so mutation responses always return the saved event snapshot.
