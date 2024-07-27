if exists('g:vim_dadbod_completion_loaded')
  finish
endif

let g:vim_dadbod_completion_loaded = 1
let g:completion_use_svv = get(g:, 'completion_use_svv', 0)

augroup vim_dadbod_completion
  autocmd!
  autocmd FileType sql,mysql,plsql call vim_dadbod_completion#fetch(str2nr(expand('<abuf>')))
augroup END

command DBCompletionClearCache call vim_dadbod_completion#clear_cache()
