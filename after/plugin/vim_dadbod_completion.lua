local has_nvim_cmp, cmp = pcall(require, 'cmp')
if has_nvim_cmp then
  cmp.register_source('vim-dadbod-completion', require('vim_dadbod_completion').nvim_cmp_source)
end

local has_completion,completion = pcall(require, 'completion')
if has_completion then
  completion.addCompletionSource('vim-dadbod-completion', require'vim_dadbod_completion'.complete_item)
end

