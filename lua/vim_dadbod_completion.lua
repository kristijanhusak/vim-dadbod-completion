local M = {}

function M.getCompletionItems(prefix, score_func)
  return vim.api.nvim_call_function('vim_dadbod_completion#omni',{0, prefix})
end

M.complete_item = {
  item = M.getCompletionItems
}

return M
