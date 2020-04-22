if exists('g:vim_dadbod_completion_loaded')
  finish
endif

let g:vim_dadbod_completion_loaded = 1
let g:vim_dadbod_completion_mark = get(g:, 'vim_dadbod_completion_mark', '[DB]')

augroup vim_dadbod_completion
  autocmd!
  autocmd FileType sql call vim_dadbod_completion#fetch(str2nr(expand('<abuf>')))
augroup END
