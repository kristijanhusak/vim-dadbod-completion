lua has_completion,completion = pcall(require, 'completion')
lua if has_completion then completion.addCompletionSource('vim-dadbod-completion', require'vim_dadbod_completion'.complete_item) end

lua has_nvim_cmp, cmp = pcall(require, 'cmp')
lua if has_nvim_cmp then cmp.register_source('vim-dadbod-completion', require('vim_dadbod_completion').nvim_cmp_source) end

if exists('g:loaded_compe') && has('nvim')
  call compe#register_source('vim_dadbod_completion', vim_dadbod_completion#compe#create())
endif
