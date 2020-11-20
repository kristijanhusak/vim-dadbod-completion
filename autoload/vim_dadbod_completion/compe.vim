function! vim_dadbod_completion#compe#create() abort
  return {
        \ 'get_metadata': function('s:get_metadata'),
        \ 'datermine': function('s:datermine'),
        \ 'complete': function('s:complete'),
        \ }
endfunction

function! s:get_metadata(...) abort
  return { 'filetypes': ['sql'], 'priority': 100 }
endfunction

function! s:datermine(context) abort
  let offset = vim_dadbod_completion#omni(1, '') + 1
  let char = a:context.before_char
  if offset > 1
    return {
          \   'keyword_pattern_offset': offset,
          \   'trigger_character_offset': (char ==? '.' || char ==? '"') ? a:context.col : 0
          \ }
  endif
  return {}
endfunction

function! s:complete(args) abort
  call a:args.callback({ 'items': vim_dadbod_completion#omni(0, a:args.input) })
endfunction

