let s:base_column_query = 'select table_name,column_name from information_schema.columns'
let s:query = s:base_column_query.' order by column_name asc'
let s:count_query = 'select count(*) as total from information_schema.columns'
let s:table_column_query = s:base_column_query.' where table_name={db_tbl_name}'

function! s:map_and_filter(delimiter, list) abort
  return filter(
        \ map(a:list, { _, table -> map(split(table, a:delimiter), 'trim(v:val)') }),
        \ 'len(v:val) ==? 2'
        \ )
endfunction

function! s:count_parser(index, result) abort
  return str2nr(get(a:result, a:index, 0))
endfunction

let s:postgres = {
      \ 'column_query': printf('-A -c "%s"', s:query),
      \ 'count_column_query': printf('-A -c "%s"', s:count_query),
      \ 'table_column_query': {table -> printf('-A -c "%s"', substitute(s:table_column_query, '{db_tbl_name}', "'".table."'", ''))},
      \ 'functions_query': printf('-A -c "%s"', "SELECT routine_name FROM information_schema.routines WHERE routine_type='FUNCTION'"),
      \ 'functions_parser': {list->list[0:-4]},
      \ 'quote': 1,
      \ 'column_parser': function('s:map_and_filter', ['|']),
      \ 'count_parser': function('s:count_parser', [1])
      \ }

let s:oracle_args = "echo \"SET linesize 4000;\nSET pagesize 4000;\n%s\" | "
let s:oracle_base_column_query = printf(s:oracle_args, "COLUMN column_name FORMAT a50;\nCOLUMN table_name FORMAT a50;\nSELECT C.table_name, C.column_name FROM all_tab_columns C JOIN all_users U ON C.owner = U.username WHERE U.common = 'NO' %s;")
let s:oracle = {
\   'column_parser': function('s:map_and_filter', ['\s\s\+']),
\   'column_query': printf(s:oracle_base_column_query, 'ORDER BY C.column_name ASC'),
\   'count_column_query': printf(s:oracle_args, "COLUMN total FORMAT 9999999;\nSELECT COUNT(*) AS total FROM all_tab_columns C JOIN all_users U ON C.owner = U.username WHERE U.common = 'NO';"),
\   'count_parser': function('s:count_parser', [1]),
\   'quote': 1,
\   'table_column_query': {table -> printf(s:oracle_base_column_query, "AND C.table_name='".table."'")},
\ }

let s:schemas = {
      \ 'postgres': s:postgres,
      \ 'postgresql': s:postgres,
      \ 'mysql': {
      \   'column_query': printf('-e "%s"', s:query),
      \   'count_column_query': printf('-e "%s"', s:count_query),
      \   'table_column_query': {table -> printf('-e "%s"', substitute(s:table_column_query, '{db_tbl_name}', "'".table."'", ''))},
      \   'quote': 0,
      \   'column_parser': function('s:map_and_filter', ['\t']),
      \   'count_parser': function('s:count_parser', [1])
      \ },
      \ 'oracle': s:oracle,
      \ 'sqlserver': {
      \   'column_query': printf('-h-1 -W -s "|" -Q "%s"', s:query),
      \   'count_column_query': printf('-h-1 -W -Q "%s"', s:count_query),
      \   'table_column_query': {table -> printf('-h-1 -W -Q "%s"', substitute(s:table_column_query, '{db_tbl_name}', "'".table."'", ''))},
      \   'quote': 0,
      \   'column_parser': function('s:map_and_filter', ['|']),
      \   'count_parser': function('s:count_parser', [0])
      \ },
    \ }

function! vim_dadbod_completion#schemas#get(scheme)
  return get(s:schemas, a:scheme, {})
endfunction

