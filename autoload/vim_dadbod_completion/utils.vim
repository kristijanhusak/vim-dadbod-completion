let s:disable_notifications = get(g:, 'vim_dadbod_completion_disable_notifications', get(g:, 'db_ui_disable_info_notifications', 0))

function! vim_dadbod_completion#utils#msg(msg) abort
  if s:disable_notifications
    return
  endif
  redraw!
  echom printf('[dadbod completion] %s', a:msg)
endfunction
