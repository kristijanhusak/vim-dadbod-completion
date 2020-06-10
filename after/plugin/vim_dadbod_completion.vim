lua has_source,source = pcall(require, 'source')
lua if has_source then source.addCompleteItems('vim-dadbod-completion', require'vim_dadbod_completion'.complete_item) end
