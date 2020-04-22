if exists('g:vim_dadbod_completion_loaded')
  finish
endif

let g:vim_dadbod_completion_loaded = 1

augroup vim_dadbod_completion
  autocmd!
  autocmd FileType sql call vim_dadbod_completion#fetch(str2nr(expand('<abuf>')))
augroup END
