lua has_completion,completion = pcall(require, 'completion')
lua if has_completion then completion.addCompletionSource('vim-dadbod-completion', require'vim_dadbod_completion'.complete_item) end
