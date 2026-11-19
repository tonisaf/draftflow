#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'sqlite3'
require 'securerandom'
require 'net/http'
require 'uri'

class DraftFlowMcp
  VERSION = '1.0.14'

  attr_reader :db, :db_path

  def initialize(explicit_path = nil)
    @db_path = find_database_path(explicit_path)
    raise "DraftFlow SQLite database not found. Start DraftFlow or specify --db-path" unless @db_path

    @db = SQLite3::Database.new(@db_path)
    @db.results_as_hash = true
    @db.execute('PRAGMA journal_mode = WAL;')
    @db.execute('PRAGMA busy_timeout = 5000;')
  end

  def find_database_path(explicit = nil)
    return explicit if explicit && File.exist?(explicit)

    env_path = ENV['DRAFTFLOW_DB_PATH']
    return env_path if env_path && File.exist?(env_path)

    home = ENV['HOME'] || ENV['USERPROFILE'] || ''
    candidate_dirs = [
      "#{home}/Library/Containers/com.draftflow.app/Data/Documents",
      "#{home}/Library/Containers/com.noteshere.notesHere/Data/Documents",
      "#{home}/Library/Application Support/com.draftflow.app",
      "#{home}/Library/Application Support/notes_here",
      "#{home}/Documents",
      "#{home}/AppData/Roaming/com.draftflow.app",
      "#{home}/AppData/Roaming/notes_here"
    ]

    found = []
    candidate_dirs.each do |do_dir|
      next unless Dir.exist?(do_dir)
      begin
        Dir.glob("#{do_dir}/*.sqlite").each do |file|
          base = File.basename(file)
          found << file if base.start_with?('notes_here_')
        end
      rescue SystemCallError, StandardError
        # ignore directories without access
      end
    end

    return nil if found.empty?

    # Sort account databases first, then newest modified
    found.sort do |a, b|
      a_acc = a.include?('notes_here_account_') ? 1 : 0
      b_acc = b.include?('notes_here_account_') ? 1 : 0
      if a_acc != b_acc
        b_acc <=> a_acc
      else
        File.mtime(b) <=> File.mtime(a)
      end
    end.first
  end

  # =========================================================================
  # Pages & Notes
  # =========================================================================

  def search_notes(query, limit: 10)
    clean = "%#{query.strip.downcase}%"
    sql = <<-SQL
      SELECT p.id, p.title, p.icon, p.parent_id, p.created_at, b.type, b.content
      FROM pages p
      LEFT JOIN blocks b ON b.page_id = p.id AND b.trashed_at IS NULL
      WHERE p.trashed_at IS NULL AND p.database_id IS NULL
        AND (
          (p.title_folded IS NOT NULL AND p.title_folded LIKE ?)
          OR LOWER(p.title) LIKE ?
          OR LOWER(b.content) LIKE ?
        )
      GROUP BY p.id
      ORDER BY p.created_at DESC
      LIMIT ?
    SQL

    rows = @db.execute(sql, [clean, clean, clean, limit])
    rows.map do |r|
      raw = r['content']
      snippet = ''
      if raw && !raw.empty?
        snippet = extract_text_from_block_json(raw)
      end
      {
        'id' => r['id'],
        'title' => (r['title'] && !r['title'].empty?) ? r['title'] : 'Untitled',
        'icon' => r['icon'],
        'parentId' => r['parent_id'],
        'createdAt' => r['created_at'],
        'snippet' => snippet
      }
    end
  end

  def list_pages(parent_id: nil)
    sql = if parent_id
      <<-SQL
        SELECT id, title, icon, parent_id, created_at, order_key
        FROM pages
        WHERE database_id IS NULL AND trashed_at IS NULL AND parent_id = ?
        ORDER BY order_key, created_at
      SQL
    else
      <<-SQL
        SELECT id, title, icon, parent_id, created_at, order_key
        FROM pages
        WHERE database_id IS NULL AND trashed_at IS NULL AND parent_id IS NULL
        ORDER BY order_key, created_at
      SQL
    end

    args = parent_id ? [parent_id] : []
    rows = @db.execute(sql, args)
    rows.map do |r|
      {
        'id' => r['id'],
        'title' => (r['title'] && !r['title'].empty?) ? r['title'] : 'Untitled',
        'icon' => r['icon'],
        'parentId' => r['parent_id'],
        'createdAt' => r['created_at']
      }
    end
  end

  def get_page(page_id_or_title)
    rows = @db.execute(
      'SELECT id, title, icon, cover, parent_id, database_id, created_at FROM pages WHERE id = ? AND trashed_at IS NULL',
      [page_id_or_title]
    )
    if rows.empty?
      folded = page_id_or_title.strip.downcase
      rows = @db.execute(
        <<-SQL,
        SELECT id, title, icon, cover, parent_id, database_id, created_at
        FROM pages
        WHERE (title = ? OR title_folded = ?) AND trashed_at IS NULL
        ORDER BY created_at DESC
        LIMIT 1
        SQL
        [page_id_or_title.strip, folded]
      )
    end
    return nil if rows.empty?

    p = rows.first
    real_id = p['id']
    blocks = @db.execute(
      'SELECT id, type, content, order_key FROM blocks WHERE page_id = ? AND trashed_at IS NULL ORDER BY order_key',
      [real_id]
    )

    lines = []
    blocks.each do |b|
      md = block_json_to_markdown(b['type'], b['content'] || '{}')
      lines << md unless md.empty?
    end

    {
      'id' => p['id'],
      'title' => (p['title'] && !p['title'].empty?) ? p['title'] : 'Untitled',
      'icon' => p['icon'],
      'cover' => p['cover'],
      'parentId' => p['parent_id'],
      'databaseId' => p['database_id'],
      'createdAt' => p['created_at'],
      'markdown' => lines.join("\n").strip,
      'blocksCount' => blocks.length
    }
  end

  def create_page(title:, parent_id: nil, content: nil, icon: nil)
    page_id = SecureRandom.uuid
    now = Time.now.to_i
    page_key = generate_fractional_key(nil, nil)

    @db.execute(
      <<-SQL,
      INSERT INTO pages (id, title, parent_id, icon, order_key, title_folded, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      SQL
      [page_id, title, parent_id, icon, page_key, title.downcase, now]
    )

    markdown = (content || '').strip
    entries = markdown_to_block_entries(markdown)

    if entries.empty?
      block_id = SecureRandom.uuid
      b_key = generate_fractional_key(nil, nil)
      empty_json = JSON.generate({'type' => 'paragraph', 'data' => {'delta' => []}})
      @db.execute(
        'INSERT INTO blocks (id, page_id, type, content, order_key) VALUES (?, ?, ?, ?, ?)',
        [block_id, page_id, 'paragraph', empty_json, b_key]
      )
    else
      prev_key = nil
      entries.each do |entry|
        block_id = SecureRandom.uuid
        key = generate_fractional_key(prev_key, nil)
        prev_key = key
        @db.execute(
          'INSERT INTO blocks (id, page_id, type, content, order_key) VALUES (?, ?, ?, ?, ?)',
          [block_id, page_id, entry[:type], JSON.generate(entry[:json]), key]
        )
      end
    end

    {'success' => true, 'pageId' => page_id, 'title' => title}
  end

  def update_page(page_id, title: nil, content: nil, append: false)
    existing = @db.execute('SELECT id, title FROM pages WHERE id = ? AND trashed_at IS NULL', [page_id])
    raise ArgumentError, "Page with id #{page_id} not found" if existing.empty?

    if title
      @db.execute(
        'UPDATE pages SET title = ?, title_folded = ? WHERE id = ?',
        [title, title.downcase, page_id]
      )
    end

    if content
      entries = markdown_to_block_entries(content)
      @db.execute('DELETE FROM blocks WHERE page_id = ?', [page_id]) unless append

      last_key = nil
      if append
        k_rows = @db.execute('SELECT order_key FROM blocks WHERE page_id = ? ORDER BY order_key DESC LIMIT 1', [page_id])
        last_key = k_rows.first['order_key'] unless k_rows.empty?
      end

      entries.each do |entry|
        block_id = SecureRandom.uuid
        key = generate_fractional_key(last_key, nil)
        last_key = key
        @db.execute(
          'INSERT INTO blocks (id, page_id, type, content, order_key) VALUES (?, ?, ?, ?, ?)',
          [block_id, page_id, entry[:type], JSON.generate(entry[:json]), key]
        )
      end
    end

    {'success' => true, 'pageId' => page_id}
  end

  def delete_page(page_id)
    now = Time.now.to_i
    @db.execute('UPDATE pages SET trashed_at = ? WHERE id = ?', [now, page_id])
    @db.execute('UPDATE blocks SET trashed_at = ? WHERE page_id = ?', [now, page_id])
    {'success' => true, 'pageId' => page_id}
  end

  # =========================================================================
  # Databases
  # =========================================================================

  def list_databases
    dbs = @db.execute('SELECT id, title, icon, parent_page_id, created_at FROM databases WHERE trashed_at IS NULL ORDER BY created_at')
    dbs.map do |d|
      db_id = d['id']
      cols = @db.execute('SELECT id, name, type, options, order_key FROM database_columns WHERE database_id = ? ORDER BY order_key', [db_id])
      cnt = @db.execute('SELECT COUNT(*) as count FROM pages WHERE database_id = ? AND trashed_at IS NULL', [db_id]).first['count']

      {
        'id' => db_id,
        'title' => (d['title'] && !d['title'].empty?) ? d['title'] : 'Untitled Database',
        'icon' => d['icon'],
        'parentPageId' => d['parent_page_id'],
        'createdAt' => d['created_at'],
        'rowCount' => cnt,
        'columns' => cols.map do |c|
          opts = nil
          if c['options'] && !c['options'].empty?
            begin
              opts = JSON.parse(c['options'])
            rescue StandardError
              nil
            end
          end
          {
            'id' => c['id'],
            'name' => c['name'],
            'type' => c['type'],
            'options' => opts
          }
        end
      }
    end
  end

  def query_database_rows(database_id, search: nil, limit: 50)
    cols = @db.execute('SELECT id, name, type FROM database_columns WHERE database_id = ? ORDER BY order_key', [database_id])
    col_map = {}
    cols.each { |c| col_map[c['id']] = c['name'] }

    rows = if search && !search.strip.empty?
      clean = "%#{search.strip.downcase}%"
      @db.execute(
        <<-SQL,
        SELECT id, title, properties, created_at, order_key
        FROM pages
        WHERE database_id = ? AND trashed_at IS NULL
          AND (
            (title_folded IS NOT NULL AND title_folded LIKE ?)
            OR (properties_folded IS NOT NULL AND properties_folded LIKE ?)
            OR LOWER(title) LIKE ?
            OR LOWER(properties) LIKE ?
          )
        ORDER BY order_key, created_at DESC
        LIMIT ?
        SQL
        [database_id, clean, clean, clean, clean, limit]
      )
    else
      @db.execute(
        <<-SQL,
        SELECT id, title, properties, created_at, order_key
        FROM pages
        WHERE database_id = ? AND trashed_at IS NULL
        ORDER BY order_key, created_at DESC
        LIMIT ?
        SQL
        [database_id, limit]
      )
    end

    rows.map do |r|
      props = {}
      if r['properties'] && !r['properties'].empty?
        begin
          decoded = JSON.parse(r['properties'])
          decoded.each do |k, v|
            props[col_map[k] || k] = v
          end
        rescue StandardError
          nil
        end
      end
      {
        'id' => r['id'],
        'title' => r['title'] || '',
        'properties' => props,
        'createdAt' => r['created_at']
      }
    end
  end

  def create_database_row(database_id, title:, properties: nil)
    row_id = SecureRandom.uuid
    now = Time.now.to_i

    cols = @db.execute('SELECT id, name FROM database_columns WHERE database_id = ?', [database_id])
    name_to_id = {}
    cols.each { |c| name_to_id[c['name'].downcase] = c['id'] }

    mapped = {}
    if properties.is_a?(Hash)
      properties.each do |k, v|
        col_id = name_to_id[k.to_s.downcase] || k.to_s
        mapped[col_id] = v
      end
    end

    k_rows = @db.execute('SELECT order_key FROM pages WHERE database_id = ? ORDER BY order_key DESC LIMIT 1', [database_id])
    last_key = k_rows.empty? ? nil : k_rows.first['order_key']
    row_key = generate_fractional_key(last_key, nil)
    props_json = JSON.generate(mapped)

    @db.execute(
      <<-SQL,
      INSERT INTO pages (id, title, database_id, properties, order_key, title_folded, properties_folded, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      SQL
      [row_id, title, database_id, props_json, row_key, title.downcase, props_json.downcase, now]
    )

    b_id = SecureRandom.uuid
    b_key = generate_fractional_key(nil, nil)
    empty_p = JSON.generate({'type' => 'paragraph', 'data' => {'delta' => []}})
    @db.execute(
      'INSERT INTO blocks (id, page_id, type, content, order_key) VALUES (?, ?, ?, ?, ?)',
      [b_id, row_id, 'paragraph', empty_p, b_key]
    )

    {'success' => true, 'rowId' => row_id, 'title' => title}
  end

  def update_database_row(row_id, title: nil, properties: nil)
    rows = @db.execute(
      'SELECT id, title, database_id, properties FROM pages WHERE id = ? AND database_id IS NOT NULL AND trashed_at IS NULL',
      [row_id]
    )
    raise ArgumentError, "Database row with id #{row_id} not found" if rows.empty?

    row = rows.first
    db_id = row['database_id']

    cols = @db.execute('SELECT id, name FROM database_columns WHERE database_id = ?', [db_id])
    name_to_id = {}
    cols.each { |c| name_to_id[c['name'].downcase] = c['id'] }

    current = {}
    if row['properties'] && !row['properties'].empty?
      begin
        current = JSON.parse(row['properties'])
      rescue StandardError
        nil
      end
    end

    if properties.is_a?(Hash)
      properties.each do |k, v|
        col_id = name_to_id[k.to_s.downcase] || k.to_s
        current[col_id] = v
      end
    end

    new_title = title || row['title']
    new_json = JSON.generate(current)

    @db.execute(
      <<-SQL,
      UPDATE pages
      SET title = ?, properties = ?, title_folded = ?, properties_folded = ?
      WHERE id = ?
      SQL
      [new_title, new_json, new_title.downcase, new_json.downcase, row_id]
    )

    {'success' => true, 'rowId' => row_id}
  end

  def delete_database_row(row_id)
    now = Time.now.to_i
    @db.execute('UPDATE pages SET trashed_at = ? WHERE id = ? AND database_id IS NOT NULL', [now, row_id])
    {'success' => true, 'rowId' => row_id}
  end

  # =========================================================================
  # Helpers
  # =========================================================================

  def generate_fractional_key(prev_key, next_key)
    # Simple fractional index generator (digits a-z0-9)
    if prev_key.nil? && next_key.nil?
      'a00000'
    elsif prev_key.nil?
      # insert before next_key
      "a#{next_key}"
    elsif next_key.nil?
      # insert after prev_key
      if prev_key =~ /^([a-z]+)(\d+)$/
        prefix, num = $1, $2.to_i
        sprintf("%s%05d", prefix, num + 1)
      else
        "#{prev_key}1"
      end
    else
      "#{prev_key}a"
    end
  end

  def extract_text_from_block_json(raw_json)
    parsed = JSON.parse(raw_json) rescue nil
    return '' unless parsed.is_a?(Hash)
    delta = parsed.dig('data', 'delta')
    return '' unless delta.is_a?(Array)
    delta.map { |op| op['insert'].to_s }.join.strip
  rescue StandardError
    ''
  end

  def block_json_to_markdown(type, raw_json)
    parsed = JSON.parse(raw_json) rescue {}
    data = parsed['data'] || {}
    delta = data['delta'] || []
    
    text = delta.map do |op|
      t = op['insert'].to_s
      attrs = op['attributes'] || {}
      t = "`#{t}`" if attrs['code']
      t = "**#{t}**" if attrs['bold']
      t = "*#{t}*" if attrs['italic']
      t = "~~#{t}~~" if attrs['strikethrough']
      t = "[#{t}](#{attrs['href']})" if attrs['href']
      t
    end.join.strip

    text = extract_text_from_block_json(raw_json) if text.empty?

    case type
    when 'heading'
      level = data['level'] || 1
      "#{'#' * level} #{text}\n"
    when 'bulleted_list'
      "- #{text}"
    when 'numbered_list'
      "1. #{text}"
    when 'todo_list'
      data['checked'] ? "- [x] #{text}" : "- [ ] #{text}"
    when 'quote'
      "> #{text}"
    when 'code'
      lang = data['language'] || ''
      "```#{lang}\n#{text}\n```\n"
    when 'divider'
      "---\n"
    when 'paragraph'
      text.empty? ? '' : "#{text}\n"
    else
      text.empty? ? '' : "#{text}\n"
    end
  rescue StandardError
    ''
  end

  def markdown_to_block_entries(markdown)
    entries = []
    in_code = false
    code_lang = ''
    code_lines = []

    markdown.lines.each do |line|
      trimmed = line.strip

      if trimmed.start_with?('```')
        if in_code
          entries << {
            type: 'code',
            json: {
              'type' => 'code',
              'data' => {
                'delta' => [{'insert' => code_lines.join("\n")}],
                'language' => code_lang
              }
            }
          }
          in_code = false
          code_lines.clear
          code_lang = ''
        else
          in_code = true
          code_lang = trimmed.sub(/^```/, '').strip
          code_lines.clear
        end
        next
      end

      if in_code
        code_lines << line.chomp
        next
      end

      next if trimmed.empty?

      if trimmed == '---' || trimmed == '***' || trimmed == '___'
        entries << {
          type: 'divider',
          json: {
            'type' => 'divider',
            'data' => {}
          }
        }
        next
      end

      if trimmed =~ /^(\#{1,6})\s+(.*)$/
        level = $1.length
        heading_text = $2
        entries << {
          type: 'heading',
          json: {
            'type' => 'heading',
            'data' => {
              'level' => level,
              'delta' => [{'insert' => heading_text}]
            }
          }
        }
      elsif trimmed =~ /^-\s+\[([ xX])\]\s+(.*)$/
        checked = $1.downcase == 'x'
        todo_text = $2
        entries << {
          type: 'todo_list',
          json: {
            'type' => 'todo_list',
            'data' => {
              'checked' => checked,
              'delta' => [{'insert' => todo_text}]
            }
          }
        }
      elsif trimmed =~ /^[-*+]\s+(.*)$/
        bullet_text = $1
        entries << {
          type: 'bulleted_list',
          json: {
            'type' => 'bulleted_list',
            'data' => {'delta' => [{'insert' => bullet_text}]}
          }
        }
      elsif trimmed =~ /^\d+\.\s+(.*)$/
        num_text = $1
        entries << {
          type: 'numbered_list',
          json: {
            'type' => 'numbered_list',
            'data' => {'delta' => [{'insert' => num_text}]}
          }
        }
      elsif trimmed =~ /^>\s+(.*)$/
        quote_text = $1
        entries << {
          type: 'quote',
          json: {
            'type' => 'quote',
            'data' => {'delta' => [{'insert' => quote_text}]}
          }
        }
      else
        entries << {
          type: 'paragraph',
          json: {
            'type' => 'paragraph',
            'data' => {'delta' => [{'insert' => trimmed}]}
          }
        }
      end
    end

    entries
  end
end

# MCP Server JSON-RPC Protocol
class McpServer
  TOOLS = [
    {
      name: 'search_notes',
      description: 'Search pages and notes by keyword or full text across titles and blocks in DraftFlow',
      inputSchema: {
        type: 'object',
        properties: {
          query: { type: 'string', description: 'Keyword or phrase to search for' },
          limit: { type: 'integer', description: 'Maximum number of results to return (default: 10)' }
        },
        required: ['query']
      }
    },
    {
      name: 'list_pages',
      description: 'List note pages with hierarchy (parent/child) and creation timestamps in DraftFlow',
      inputSchema: {
        type: 'object',
        properties: {
          parentId: { type: 'string', description: 'Optional parent page UUID to filter subpages' }
        }
      }
    },
    {
      name: 'get_page',
      description: 'Get full content of a note page formatted in Markdown. Accepts either the page UUID or the page title (e.g. "Rules" or "Описание проекта").',
      inputSchema: {
        type: 'object',
        properties: {
          pageId: { type: 'string', description: 'UUID or title of the page to retrieve' }
        },
        required: ['pageId']
      }
    },
    {
      name: 'create_page',
      description: 'Create a new note page in DraftFlow with title and Markdown content (headings, lists, code, quotes)',
      inputSchema: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Title of the new page' },
          content: { type: 'string', description: 'Markdown content for page body' },
          parentId: { type: 'string', description: 'Optional parent page UUID for nested hierarchy' },
          icon: { type: 'string', description: 'Optional emoji icon (e.g. 📝, 💡, 🚀)' }
        },
        required: ['title']
      }
    },
    {
      name: 'update_page',
      description: 'Update title and/or body content of an existing note page in DraftFlow',
      inputSchema: {
        type: 'object',
        properties: {
          pageId: { type: 'string', description: 'UUID of the page to update' },
          title: { type: 'string', description: 'Optional new title for the page' },
          content: { type: 'string', description: 'Optional Markdown body content' },
          append: { type: 'boolean', description: 'If true, appends content to existing blocks; if false (default), replaces blocks' }
        },
        required: ['pageId']
      }
    },
    {
      name: 'delete_page',
      description: 'Move a note page and its blocks to Trash in DraftFlow',
      inputSchema: {
        type: 'object',
        properties: {
          pageId: { type: 'string', description: 'UUID of the page to trash' }
        },
        required: ['pageId']
      }
    },
    {
      name: 'list_databases',
      description: 'List all Notion-like relational databases in DraftFlow with column definitions and row counts',
      inputSchema: {
        type: 'object',
        properties: {}
      }
    },
    {
      name: 'query_database_rows',
      description: 'Query rows from a relational database with cell values and optional keyword search in DraftFlow',
      inputSchema: {
        type: 'object',
        properties: {
          databaseId: { type: 'string', description: 'UUID of the database to query' },
          search: { type: 'string', description: 'Optional keyword to filter rows across title and cell properties' },
          limit: { type: 'integer', description: 'Maximum rows to return (default: 50)' }
        },
        required: ['databaseId']
      }
    },
    {
      name: 'create_database_row',
      description: 'Add a new row to a relational database in DraftFlow with column values',
      inputSchema: {
        type: 'object',
        properties: {
          databaseId: { type: 'string', description: 'UUID of the database' },
          title: { type: 'string', description: 'Primary title/name of the row item' },
          properties: { type: 'object', description: 'Key-value map of column names (or IDs) to cell values' }
        },
        required: ['databaseId', 'title']
      }
    },
    {
      name: 'update_database_row',
      description: 'Update title or column properties of an existing row in a DraftFlow database',
      inputSchema: {
        type: 'object',
        properties: {
          rowId: { type: 'string', description: 'UUID of the database row to update' },
          title: { type: 'string', description: 'Optional updated title' },
          properties: { type: 'object', description: 'Key-value map of column names to updated values' }
        },
        required: ['rowId']
      }
    },
    {
      name: 'delete_database_row',
      description: 'Delete a row from a relational database in DraftFlow',
      inputSchema: {
        type: 'object',
        properties: {
          rowId: { type: 'string', description: 'UUID of the row to delete' }
        },
        required: ['rowId']
      }
    }
  ].freeze

  def initialize(client)
    @client = client
  end

  def self.load_mcp_config
    home = ENV['HOME'] || ENV['USERPROFILE'] || '.'
    config_file = File.join(home, '.draftflow', 'mcp.json')
    return nil unless File.exist?(config_file)
    JSON.parse(File.read(config_file))
  rescue StandardError, SystemCallError
    nil
  end

  def self.forward_to_gui(line, config)
    require 'net/http'
    require 'uri'
    port = config['port']
    token = config['token']
    uri = URI("http://127.0.0.1:#{port}/mcp")
    req = Net::HTTP::Post.new(uri)
    req['Host'] = "127.0.0.1:#{port}"
    req['Authorization'] = "Bearer #{token}"
    req['Content-Type'] = 'application/json'
    req.body = line

    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 0.4
    http.read_timeout = 5.0
    res = http.request(req)
    if res.code.to_i == 200
      puts res.body.strip
      $stdout.flush
      true
    elsif res.code.to_i == 202
      true
    else
      false
    end
  rescue StandardError, SystemCallError
    false
  end

  def start
    config = McpServer.load_mcp_config

    $stdin.each_line do |line|
      trimmed = line.strip
      next if trimmed.empty?

      forwarded = false
      if config && config['port'] && config['port'] > 0
        forwarded = McpServer.forward_to_gui(trimmed, config)
      end

      unless forwarded
        begin
          req = JSON.parse(trimmed)
          res = handle_message(req)
          puts JSON.generate(res) if res
          $stdout.flush
        rescue StandardError => e
          puts JSON.generate({
            jsonrpc: '2.0',
            id: nil,
            error: { code: -32700, message: "Parse error: #{e}" }
          })
          $stdout.flush
        end
      end
    end
  end

  def handle_message(msg)
    id = msg['id']
    method = msg['method']
    params = msg['params'] || {}

    return nil if id.nil? # Notifications

    case method
    when 'initialize'
      {
        jsonrpc: '2.0',
        id: id,
        result: {
          protocolVersion: '2024-11-05',
          capabilities: {
            tools: { listChanged: false },
            resources: { listChanged: false }
          },
          serverInfo: {
            name: 'draftflow',
            version: DraftFlowMcp::VERSION
          },
          instructions: 'DraftFlow is a minimalist notes and Notion-like relational database workspace. Use the provided tools to search, read, create, and modify user notes and databases.'
        }
      }
    when 'ping'
      { jsonrpc: '2.0', id: id, result: {} }
    when 'tools/list'
      { jsonrpc: '2.0', id: id, result: { tools: TOOLS } }
    when 'tools/call'
      name = params['name']
      args = params['arguments'] || {}
      result = execute_tool(name, args)
      { jsonrpc: '2.0', id: id, result: result }
    when 'resources/list'
      pages = @client.list_pages
      resources = pages.map do |p|
        {
          uri: "draftflow://pages/#{p['id']}",
          name: p['title'],
          description: "Note page in DraftFlow (created: #{p['createdAt']})",
          mimeType: 'text/markdown'
        }
      end
      { jsonrpc: '2.0', id: id, result: { resources: resources } }
    when 'resources/read'
      uri = params['uri'].to_s
      page_id = uri.sub(%r{^draftflow://pages/}, '')
      page = @client.get_page(page_id)
      if page
        {
          jsonrpc: '2.0',
          id: id,
          result: {
            contents: [
              {
                uri: uri,
                mimeType: 'text/markdown',
                text: "# #{page['title']}\n\n#{page['markdown']}"
              }
            ]
          }
        }
      else
        {
          jsonrpc: '2.0',
          id: id,
          error: { code: -32602, message: "Resource not found: #{uri}" }
        }
      end
    else
      {
        jsonrpc: '2.0',
        id: id,
        error: { code: -32601, message: "Method not found: #{method}" }
      }
    end
  end

  def execute_tool(name, args)
    case name
    when 'search_notes'
      query = args['query'].to_s
      limit = (args['limit'] || 10).to_i
      notes = @client.search_notes(query, limit: limit)
      text_result(JSON.generate(notes))
    when 'list_pages'
      parent_id = args['parentId']
      pages = @client.list_pages(parent_id: parent_id)
      text_result(JSON.generate(pages))
    when 'get_page'
      page_id = args['pageId'].to_s
      raise ArgumentError, 'pageId is required' if page_id.empty?
      page = @client.get_page(page_id)
      return error_result("Page with id \"#{page_id}\" not found") unless page
      formatted = "# #{page['title']}\nPage ID: #{page['id']}\nCreated: #{page['createdAt']}\n\n#{page['markdown']}\n"
      text_result(formatted)
    when 'create_page'
      title = args['title'] || 'Untitled'
      content = args['content']
      parent_id = args['parentId']
      icon = args['icon']
      res = @client.create_page(title: title, content: content, parent_id: parent_id, icon: icon)
      text_result("Created page \"#{res['title']}\" with ID: #{res['pageId']}")
    when 'update_page'
      page_id = args['pageId'].to_s
      raise ArgumentError, 'pageId is required' if page_id.empty?
      title = args['title']
      content = args['content']
      append = args['append'] == true
      @client.update_page(page_id, title: title, content: content, append: append)
      text_result("Updated page #{page_id} successfully")
    when 'delete_page'
      page_id = args['pageId'].to_s
      raise ArgumentError, 'pageId is required' if page_id.empty?
      @client.delete_page(page_id)
      text_result("Moved page #{page_id} to trash")
    when 'list_databases'
      dbs = @client.list_databases
      text_result(JSON.generate(dbs))
    when 'query_database_rows'
      db_id = args['databaseId'].to_s
      raise ArgumentError, 'databaseId is required' if db_id.empty?
      search = args['search']
      limit = (args['limit'] || 50).to_i
      rows = @client.query_database_rows(db_id, search: search, limit: limit)
      text_result(JSON.generate(rows))
    when 'create_database_row'
      db_id = args['databaseId'].to_s
      raise ArgumentError, 'databaseId is required' if db_id.empty?
      title = args['title'] || 'Untitled'
      props = args['properties'].is_a?(Hash) ? args['properties'] : nil
      res = @client.create_database_row(db_id, title: title, properties: props)
      text_result("Created row \"#{res['title']}\" with ID: #{res['rowId']}")
    when 'update_database_row'
      row_id = args['rowId'].to_s
      raise ArgumentError, 'rowId is required' if row_id.empty?
      title = args['title']
      props = args['properties'].is_a?(Hash) ? args['properties'] : nil
      @client.update_database_row(row_id, title: title, properties: props)
      text_result("Updated database row #{row_id}")
    when 'delete_database_row'
      row_id = args['rowId'].to_s
      raise ArgumentError, 'rowId is required' if row_id.empty?
      @client.delete_database_row(row_id)
      text_result("Deleted database row #{row_id}")
    else
      error_result("Unknown tool: #{name}")
    end
  rescue StandardError => e
    error_result("Tool execution failed: #{e.message}")
  end

  def text_result(text)
    { content: [{ type: 'text', text: text }] }
  end

  def error_result(msg)
    { isError: true, content: [{ type: 'text', text: msg }] }
  end
end

if __FILE__ == $0
  db_path = nil
  args = ARGV.dup
  while (arg = args.shift)
    case arg
    when '-h', '--help'
      puts "DraftFlow MCP Server\nUsage: ruby bin/draftflow_mcp.rb [--db-path <path>] [--test] [--detect]"
      exit 0
    when '--detect'
      client = DraftFlowMcp.new
      puts "DraftFlow database detected at: #{client.db_path}"
      exit 0
    when '--test'
      client = DraftFlowMcp.new
      pages = client.list_pages
      dbs = client.list_databases
      puts "DraftFlow MCP Self-Test: SUCCESS"
      puts "Database: #{client.db_path}"
      puts "Pages: #{pages.length}"
      puts "Databases: #{dbs.length}"
      exit 0
    when '-d', '--db-path'
      db_path = args.shift
    end
  end

  client = DraftFlowMcp.new(db_path)
  server = McpServer.new(client)
  server.start
end
