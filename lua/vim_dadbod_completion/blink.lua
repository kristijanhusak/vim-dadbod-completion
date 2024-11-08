---@type blink.cmp.Source
local M = {}

function M.new()
  return setmetatable({}, { __index = M })
end

function M:get_trigger_characters()
  return { '"', '`', '[', ']', '.' }
end

function M:enabled()
  local filetypes = { "sql", "mysql", "plsql" }
  return vim.tbl_contains(filetypes, vim.bo.filetype)
end

function M:get_completions(ctx, callback)
  local cursor_col = ctx.cursor[2]
  local line = ctx.line
  local word_start = cursor_col

  local triggers = self:get_trigger_characters()
  while word_start > 1 do
    local char = line:sub(word_start - 1, word_start - 1)
    if vim.tbl_contains(triggers, char) or char:match('%s') then
      break
    end
    word_start = word_start - 1
  end

  -- Get text from word start to cursor
  local input = line:sub(word_start, cursor_col)

  local transformed_callback = function(items)
    callback({
      context = ctx,
      is_incomplete_forward = false,
      is_incomplete_backward = false,
      items = items,
    })
  end

  local results = vim.api.nvim_call_function('vim_dadbod_completion#omni', { 0, input })

  if not results then
    transformed_callback({})
    return function() end
  end
  local items = {} ---@type table<string,lsp.CompletionItem>

  for _, item in ipairs(results) do
    table.insert(items, {
      label = item.abbr or item.word,
      dup = 0,
      insertText = item.word,
      labelDetails = item.menu and { description = item.menu } or nil,
      documentation = item.info or '',
      kind = require 'blink.cmp.types'.CompletionItemKind or vim.lsp.protocol.CompletionItemKind.Text
    })
  end

  transformed_callback(vim.tbl_values(items))

  return function() end
end

return M
