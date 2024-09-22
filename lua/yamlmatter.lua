local M = {}

-- Default configuration
M.config = {
  key_value_padding = 4, -- Default padding between key and value
  conceallevel = 1, -- on what level start conceal the yaml text
  icon_mappings = {
    -- Default icon mappings
    title = '',
    author = '',
    date = '',
    id = '',
    tags = '',
    category = '',
    type = '',
    default = '󰦨',
  },
  highlight_groups = {
    -- icon = 'YamlFrontmatterIcon',
    -- key = 'YamlFrontmatterKey',
    -- value = 'YamlFrontmatterValue',
    icon = 'Identifier',
    key = 'Function',
    value = 'Type',
    parameter = 'String', -- New highlight group for parameters
  },
}

-- Namespace for extmarks
local ns_id = vim.api.nvim_create_namespace('YamlFrontmatterAlign')

-- Table to keep track of extmarks for resetting
local extmark_ids = {}

-- Table to keep track of un-concealed lines in insert mode
local unconcealed_lines = {}

local function parse_yaml(yaml_text)
  local data = {}
  local lines = {}
  for line in yaml_text:gmatch('[^\r\n]*') do
    table.insert(lines, line)
  end

  local current_key
  local current_list

  for _, line in ipairs(lines) do
    -- Remove leading whitespace
    local indent, trimmed_line = line:match('^(%s*)(.-)%s*$')
    -- Check for key-value pair
    local key, value = trimmed_line:match('^([%w_]+)%s*:%s*(.-)%s*$')
    if key then
      if value ~= '' then
        -- Simple key-value pair
        data[key] = value
        current_key = nil
        current_list = nil
      else
        -- Key with empty value (might be a list)
        data[key] = {} -- Initialize as list
        current_key = key
        current_list = data[key]
      end
    else
      -- Check for list item
      local list_item = trimmed_line:match('^%-%s*(.-)%s*$')
      if list_item and current_list then
        table.insert(current_list, list_item)
      else
        -- Ignore lines that don't match
      end
    end
  end

  return data
end

-- Function to align YAML front matter
function M.display_frontmatter()
  -- Check conceallevel and it does not work when conceallevel is 0
  if vim.api.nvim_get_option_value('conceallevel', { scope = 'local' }) < M.config.conceallevel then
    -- print('conceallevel is less than ' .. M.config.conceallevel)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Ensure the front matter starts with '---'
  if lines[1] ~= '---' then
    -- No front matter found at the beginning of the file.
    -- TODO: handle yaml file
    -- print('No front matter found at the beginning of the file.')
    return
  end

  -- Clear existing extmarks
  vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
  extmark_ids = {}

  -- Conceal the starting '---' line
  local id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, 0, 0, {
    end_line = 0,
    end_col = #lines[1],
    hl_group = 'Conceal',
    conceal = '',
  })
  extmark_ids[1] = id

  -- Extract front matter lines between the first and second '---'
  local frontmatter = {}
  local end_line
  for i = 2, #lines do
    if lines[i] == '---' then
      end_line = i
      -- Conceal the ending '---' line
      id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, 0, {
        end_line = i - 1,
        end_col = #lines[i],
        hl_group = 'Conceal',
        conceal = '',
      })
      extmark_ids[i] = id
      break
    else
      table.insert(frontmatter, lines[i])
    end
  end

  if not end_line then
    -- Closing '---' for front matter not found.
    print('Closing --- for front matter not found.')
    return
  end

  if #frontmatter == 0 then
    -- Front matter is empty.
    return
  end

  -- Convert front matter to string
  local yaml_text = table.concat(frontmatter, '\n')

  -- Parse the YAML front matter
  local data = parse_yaml(yaml_text)
  if not data or vim.tbl_isempty(data) then
    print('Error parsing front matter.')
    return
  end

  -- Prepare keys with icons
  local keys_with_icons = {}
  for key, _ in pairs(data) do
    local icon = M.config.icon_mappings[key] or M.config.icon_mappings.default
    local key_with_icon = icon .. ' ' .. key
    keys_with_icons[key] = key_with_icon
  end

  -- Calculate max key length including icons
  local max_key_length = 0
  for _, key_with_icon in pairs(keys_with_icons) do
    local display_width = vim.fn.strdisplaywidth(key_with_icon)
    if display_width > max_key_length then
      max_key_length = display_width
    end
  end

  -- Apply configurable padding
  max_key_length = max_key_length + M.config.key_value_padding

  -- Add virtual text for alignment
  local i = 1
  while i <= end_line - 1 do
    local line = lines[i]
    local key, separator, value = line:match('^(%s*[^:]+)(%s*:%s*)(.*)$')
    if key and separator then
      local key_trimmed = key:match('^%s*(.-)%s*$')
      local icon = M.config.icon_mappings[key_trimmed] or M.config.icon_mappings.default
      local key_with_icon = icon .. ' ' .. key_trimmed
      local key_display_width = vim.fn.strdisplaywidth(key_with_icon)

      local padding = max_key_length - key_display_width
      local padding_spaces = string.rep(' ', padding)
      local display_value = data[key_trimmed]

      if display_value == nil then
        display_value = ''
      elseif type(display_value) == 'table' then
        local list_items = {}
        for _, item in ipairs(display_value) do
          table.insert(list_items, item)
        end
        display_value = "{ '" .. table.concat(list_items, "', '") .. "' }"
        -- Conceal list item lines
        local j = i + 1
        while j <= end_line - 1 do
          local next_line = lines[j]
          if next_line:match('^%s*%-%s*.+$') then
            vim.api.nvim_buf_set_extmark(bufnr, ns_id, j - 1, 0, {
              end_line = j - 1,
              end_col = #next_line,
              hl_group = 'Conceal',
              conceal = '',
            })
            j = j + 1
          else
            break
          end
        end
      else
        display_value = tostring(display_value)
      end

      -- Conceal the entire line
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, 0, {
        end_line = i - 1,
        end_col = #line,
        hl_group = 'Conceal',
        conceal = '',
      })

      -- Build virt_text with different highlight groups
      local virt_text = {
        { icon .. ' ', M.config.highlight_groups.icon },
        { key_trimmed, M.config.highlight_groups.key },
        { padding_spaces, '' }, -- No highlight group for padding
        { display_value, M.config.highlight_groups.value },
      }

      -- Add virtual text
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, -1, {
        virt_text = virt_text,
        virt_text_pos = 'overlay',
      })
    end
    i = i + 1
  end
end

-- Function to reset the view
function M.reset_frontmatter_view(disable)
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  extmark_ids = {}
  -- Re-render the frontmatter if conceallevel is >= config.conceallevel
  if disable then
    return
  end
  if
    vim.api.nvim_get_option_value('conceallevel', { scope = 'local' }) >= M.config.conceallevel
  then
    M.display_frontmatter()
  end
end

-- Function to un-conceal the current line
local function unconceal_current_line()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1 -- Convert to 0-based index
  local col = cursor[2]

  -- Check if the current line has an extmark in the namespace
  local extmarks = vim.api.nvim_buf_get_extmarks(
    bufnr,
    ns_id,
    { row, 0 },
    { row, -1 },
    { details = true }
  )

  if #extmarks > 0 then
    for _, extmark in ipairs(extmarks) do
      local extmark_id = extmark[1]
      local _, start_col, end_col = unpack(
        extmark[4].end_col and { extmark[2], extmark[3], extmark[4].end_col }
          or { extmark[2], extmark[3], extmark[3] }
      )

      -- Remove the extmark to un-conceal the line
      vim.api.nvim_buf_del_extmark(bufnr, ns_id, extmark_id)
      -- Optionally, remove any virtual text if present
    end
  end
end

-- Function to handle cursor movement in insert mode
function M.on_cursor_moved_i()
  unconceal_current_line()
end

-- Function to handle leaving insert mode
function M.on_insert_leave()
  M.display_frontmatter()
end

-- Setup function for user configuration
function M.setup(user_config)
  M.config = vim.tbl_deep_extend('force', M.config, user_config or {})

  -- Define highlight groups if they don't exist
  local function define_hl(group, default)
    if vim.fn.empty(vim.api.nvim_get_hl(0, { name = group })) == 1 then
      vim.api.nvim_set_hl(0, group, default)
    end
  end

  define_hl(M.config.highlight_groups.icon, { link = 'Identifier' })
  define_hl(M.config.highlight_groups.key, { link = 'Function' })
  define_hl(M.config.highlight_groups.value, { link = 'Type' })
  define_hl(M.config.highlight_groups.parameter, { link = 'String' }) -- Define parameter highlight

  -- Create user commands
  vim.api.nvim_create_user_command('YamlMatter', M.display_frontmatter, {})
  vim.api.nvim_create_user_command('YamlMatterReset', M.reset_frontmatter_view, {})
  vim.api.nvim_create_user_command('YamlMatterDisable', function()
    M.reset_frontmatter_view(true)
  end, {})

  -- Set up autocmds
  vim.api.nvim_create_augroup('YamlFrontmatterGroup', { clear = true })

  -- Auto-render YAML frontmatter on buffer events
  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'TextChanged', 'InsertLeave' }, {
    group = 'YamlFrontmatterGroup',
    pattern = { '*.md', '*.rmd' },
    callback = function()
      require('yamlmatter').display_frontmatter()
    end,
  })

  -- Toggle rendering based on conceallevel changes
  -- seems not working?
  vim.api.nvim_create_autocmd('OptionSet', {
    group = 'YamlFrontmatterGroup',
    pattern = 'conceallevel',
    callback = function(opts)
      -- double check if conceallevel is changed
      if opts.match ~= 'conceallevel' then
        return
      end
      -- get current conceallevel

      local cl = vim.api.nvim_get_option_value('conceallevel', { scope = 'local' })
      if cl >= M.config.conceallevel then
        require('yamlmatter').display_frontmatter()
      else
        require('yamlmatter').reset_frontmatter_view()
      end
    end,
  })

  -- Un-conceal current line in insert mode when cursor moves
  vim.api.nvim_create_autocmd('CursorMovedI', {
    group = 'YamlFrontmatterGroup',
    pattern = { '*.md', '*.rmd' },
    -- callback = on_cursor_moved_i,
    callback = function()
      require('yamlmatter').on_cursor_moved_i()
    end,
  })

  -- Re-conceal frontmatter when leaving insert mode
  vim.api.nvim_create_autocmd('InsertLeave', {
    group = 'YamlFrontmatterGroup',
    pattern = { '*.md', '*.rmd' },
    callback = function()
      require('yamlmatter').on_insert_leave()
    end,
  })
end

return M
