local M = {}

function M.getCompletionItems(prefix, score_func)
  local items = vim.api.nvim_call_function('vim_dadbod_completion#omni',{0, prefix})
  local completion = {}
  for _,item in pairs(items) do
    table.insert(completion, {
        word = item.word,
        abbr = item.abbr,
        menu = item.menu,
        info = item.info,
        user_data = vim.fn.json_encode({ hover = item.info })
      })
  end

  return completion
end

M.complete_item = {
  item = M.getCompletionItems
}

return M
