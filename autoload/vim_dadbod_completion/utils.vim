function! vim_dadbod_completion#utils#msg(msg) abort
  redraw!
  echom printf('[dadbod completion] %s', a:msg)
endfunction
