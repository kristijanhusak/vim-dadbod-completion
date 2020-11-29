function! vim_dadbod_completion#compe#create() abort
  return {
        \ 'get_metadata': function('s:get_metadata'),
        \ 'datermine': function('s:datermine'),
        \ 'documentation': function('s:documentation'),
        \ 'complete': function('s:complete'),
        \ }
endfunction

function! s:get_metadata(...) abort
  return { 'filetypes': ['sql'], 'priority': 100, 'dup': 0 }
endfunction

function! s:datermine(context) abort
  let offset = vim_dadbod_completion#omni(1, '') + 1
  let char = a:context.before_char
  if offset >= 0
    return {
          \   'keyword_pattern_offset': max([1, offset]),
          \   'trigger_character_offset': (char ==? '.' || char ==? '"') ? a:context.col : 0
          \ }
  endif
  return {}
endfunction

function! s:documentation(args) abort
  let info = get(a:args.completed_item, 'info', '')
  if empty(info)
    return a:args.abort()
  endif
  return a:args.callback([info])
endfunction

function! s:complete(args) abort
  let items = vim_dadbod_completion#omni(0, a:args.input)
  for item in items
    let item.filter_text = item.abbr
  endfor
  call a:args.callback({ 'items': items })
endfunction

