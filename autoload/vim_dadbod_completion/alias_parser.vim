let s:reserved_words = ['inner', 'outer', 'left', 'right', 'join', 'where', 'on', 'from', 'as']

function! vim_dadbod_completion#alias_parser#parse(bufnr, tables) abort
  let result = {}
  let content = getbufline(a:bufnr, 1, '$')
  if empty(a:tables) || empty(content)
    return result
  endif

  let rgx = '"\?\(\w\+\)"\?\('.join(s:reserved_words, '\|').'\)\@<!\s\+\(as\s\+\)\?"\?\(\w\+\)"\?'

  let aliases = []
  for line in content
    call substitute(line, rgx, '\=add(aliases, [submatch(1), submatch(4)])', 'g')
  endfor

  for [tbl, alias] in aliases
    if !empty(alias) && index(a:tables, tbl) > -1 && index(s:reserved_words, tolower(alias)) ==? -1
      let result[tbl] = alias
    endif
  endfor

  return result
endfunction
