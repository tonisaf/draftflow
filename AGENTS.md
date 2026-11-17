# DraftFlow Project Guidelines & AI Integration

## DraftFlow Local MCP Server
This project includes a local Model Context Protocol (MCP) server located at `bin/draftflow_mcp.dart`.
External AI agents (Antigravity, Claude Code, Codex, Cursor) have direct access to the user's DraftFlow notes, pages, and relational databases.

### Key MCP Tools:
- `get_page`: Retrieve full page content in Markdown by UUID or exact page title (e.g. `get_page(pageId: "Название страницы")`).
- `search_notes`: Search notes by keyword across titles and blocks with Cyrillic support.
- `list_pages`: List all pages in the hierarchy.
- `update_page`: Update page content or append notes/tasks (`append: true`).
- `create_page`: Create a new note from Markdown.
- `list_databases`: List all relational databases and column schemas.
- `query_database_rows`: Filter and search database rows with column name mapping and Cyrillic support.
