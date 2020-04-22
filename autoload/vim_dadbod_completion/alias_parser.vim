let s:reserved_words = ['inner', 'outer', 'left', 'right', 'join', 'where', 'on']

function! vim_dadbod_completion#alias_parser#parse(bufnr, tables) abort
  let result = {}
  let content = getbufline(a:bufnr, 1, '$')
  if empty(a:tables) || empty(content)
    return result
  endif

  let tableStr = printf('"\?\(%s\)"\?', join(a:tables, '\|'))
  let rgx = printf('%s\s\+\(as\s\+\)\?"\?\(\w\+\)"\?', tableStr)

  let aliases = []
  for line in content
    call substitute(line, rgx, '\=add(aliases, [submatch(1),submatch(3)])', 'g')
  endfor

  for [tbl, alias] in aliases
    if !empty(alias) && index(s:reserved_words, tolower(alias)) ==? -1
      let result[tbl] = alias
    endif
  endfor

  return result
endfunction
