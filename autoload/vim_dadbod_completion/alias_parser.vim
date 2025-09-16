let s:reserved_words = ['inner', 'outer', 'left', 'right', 'join', 'where', 'on', 'from', 'as']
let s:quotes = vim_dadbod_completion#schemas#get_quotes_rgx()
let s:alias_rgx = printf(
      \ '\(%s\)\?\(\w\+\)\(%s\)\?\(%s\)\@<!\s\+\(as\s\+\)\?\(%s\)\?\(\w\+\)\(%s\)\?',
      \ s:quotes.open,
      \ s:quotes.close,
      \ join(s:reserved_words, '\|'),
      \ s:quotes.open,
      \ s:quotes.close
      \ )

function! vim_dadbod_completion#alias_parser#parse(bufnr, tables) abort
  let result = {}
  let content = getbufline(a:bufnr, 1, '$')
  if empty(a:tables) || empty(content)
    return result
  endif

  let aliases = []
  for line in content
    call substitute(line, s:alias_rgx, '\=add(aliases, [submatch(2), submatch(7)])', 'g')
  endfor

  for [tbl, alias] in aliases
    if !empty(alias) && index(a:tables, tbl) > -1 && index(s:reserved_words, tolower(alias)) ==? -1
      if !has_key(result, tbl)
        let result[tbl] = []
      endif
      call add(result[tbl], alias)
    endif
  endfor

  return result
endfunction
