local M = {}

function M.getCompletionItems(prefix, score_func)
  local items = vim.api.nvim_call_function('vim_dadbod_completion#omni',{0, prefix})
  for _, item in pairs(items) do
    item.user_data = vim.fn.json_encode({ hover = item.info })
  end

  return items
end

M.complete_item = {
  item = M.getCompletionItems
}

return M
