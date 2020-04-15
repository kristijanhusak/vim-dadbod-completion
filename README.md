# coc-db

Database auto completion extension for [coc.nvim](https://github.com/neoclide/coc.nvim) powered by [vim-dadbod](https://github.com/tpope/vim-dadbod).

![coc-db](https://user-images.githubusercontent.com/1782860/78941173-717f6680-7ab7-11ea-91b3-18bf178b3735.gif)

## Install

**Dependencies**:
* [vim-dadbod](https://github.com/tpope/vim-dadbod)

```
:CocInstall coc-db
```

## Features
* Autocomplete table names, with automatic quoting where needed. Works for all schemes that [vim-dadbod](https://github.com/tpope/vim-dadbod) supports.
* Autocomplete table columns, context aware. Also knows to read aliases (`select * from mytable tbl where tbl.id = 1`). Currently works for `PostgreSQL`, `MySQL` and `SQLserver/MSSQL`.
* Out of the box integration with [vim-dadbod-ui](https://github.com/kristijanhusak/vim-dadbod-ui)

## How it works
* If an sql buffer is created by [vim-dadbod-ui](https://github.com/kristijanhusak/vim-dadbod-ui), it reads all the configuration from there. It should work out of the box.
* If `vim-dadbod-ui` is not used, [vim-dadbod](https://github.com/tpope/vim-dadbod) `g:db` or `b:db` is used. If you want, you can also add `b:db_table` to limit autocompletions to that table only.

## Todo
* [ ] Integration for column autocompletion with more database types
