# DraftFlow Project Guidelines & AI Integration

## DraftFlow Local MCP Server
This project includes a local Model Context Protocol (MCP) server located at `bin/draftflow_mcp` (with Dart source at `bin/draftflow_mcp.dart` and native macOS runner `bin/draftflow_mcp.rb`).
External AI agents (Antigravity, Claude Code, Codex, Cursor) have direct access to the user's DraftFlow notes, pages, and relational databases.

### Configuration
- **Antigravity**: configured in `~/.gemini/config/mcp_config.json`:
  ```json
  {
    "mcpServers": {
      "draftflow": {
        "command": "/Users/toni/GitHub/draftflow/bin/draftflow_mcp",
        "args": []
      }
    }
  }
  ```
- **Self-Test**:
  ```bash
  ./bin/draftflow_mcp --test
  ```

### Key MCP Tools:
- `get_page`: Retrieve full page content in Markdown by UUID or exact page title (e.g. `get_page(pageId: "Название страницы")`).
- `search_notes`: Search notes by keyword across titles and blocks with Cyrillic support.
- `list_pages`: List all pages in the hierarchy.
- `update_page`: Update page content or append notes/tasks (`append: true`).
- `create_page`: Create a new note from Markdown.
- `list_databases`: List all relational databases and column schemas.
- `query_database_rows`: Filter and search database rows with column name mapping and Cyrillic support.

### Hybrid Architecture
1. **Online (GUI open)**: Transparent proxy to local loopback HTTP server (`POST 127.0.0.1:port/mcp` + Bearer token from `~/.draftflow/mcp.json`). Triggers Drift in-memory streams (`notifyUpdates`) for instant UI re-rendering and invokes `NotesSyncEngine.sync()` to push changes to Supabase immediately.
2. **Offline / Headless (GUI closed)**: Automatic fallback to direct SQLite WAL access (`DraftFlowDbClient`) for 24/7 agent availability.

