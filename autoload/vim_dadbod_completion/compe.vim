let s:quotes = vim_dadbod_completion#schemas#get_quotes_rgx()
let s:trigger_rgx = printf('\(%s\|\.\)$', s:quotes.open)

function! vim_dadbod_completion#compe#create() abort
  return {
        \ 'get_metadata': function('s:get_metadata'),
        \ 'determine': function('s:determine'),
        \ 'documentation': function('s:documentation'),
        \ 'complete': function('s:complete'),
        \ }
endfunction

function! s:get_metadata(...) abort
  return { 'filetypes': ['sql', 'mysql', 'plsql'], 'priority': 100, 'dup': 0 }
endfunction

function! s:determine(context) abort
  let offset = vim_dadbod_completion#omni(1, '') + 1
  let char = a:context.before_char
  if offset > 0
    return {
          \   'keyword_pattern_offset': offset,
          \   'trigger_character_offset': char =~? s:trigger_rgx ? a:context.col : 0
          \ }
  endif
  return {}
endfunction

function! s:documentation(args) abort
  let info = get(a:args.completed_item, 'info', '')
  return a:args.callback(info)
endfunction

function! s:complete(args) abort
  let items = vim_dadbod_completion#omni(0, a:args.input)
  for item in items
    let item.filter_text = item.abbr
  endfor
  call a:args.callback({ 'items': items, 'incomplete': v:true })
endfunction

