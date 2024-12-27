# vim-dadbod-completion

Database auto completion powered by [vim-dadbod](https://github.com/tpope/vim-dadbod).

Supports:
* [coc.nvim](https://github.com/neoclide/coc.nvim)
* [deoplete.nvim](https://github.com/Shougo/deoplete.nvim)
* [nvim-compe](https://github.com/hrsh7th/nvim-compe)
* [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)
* [ddc.vim](https://github.com/Shougo/ddc.vim)
* [blink.cmp](https://github.com/Saghen/blink.cmp)
* Built in `omnifunc`

![coc-db](https://user-images.githubusercontent.com/1782860/78941173-717f6680-7ab7-11ea-91b3-18bf178b3735.gif)


Video presentation by TJ:

[![Video presentation by TJ](https://i.ytimg.com/vi/ALGBuFLzDSA/hqdefault.jpg?sqp=-oaymwEcCNACELwBSFXyq4qpAw4IARUAAIhCGAFwAcABBg==&rs=AOn4CLDmOFtUnDmQx5U_PKBqV819YujOBw)](https://www.youtube.com/watch?v=ALGBuFLzDSA)


## Install

**Dependencies**:
* [vim-dadbod](https://github.com/tpope/vim-dadbod)

For [coc.nvim](https://github.com/neoclide/coc.nvim)
```
:CocInstall coc-db
```

For `deoplete`, `completion-nvim`, `nvim-compe`, `ddc` and `omnifunc`, install it with your favorite plugin manager.

```vim
Plug 'tpope/vim-dadbod'
Plug 'kristijanhusak/vim-dadbod-ui' "Optional
Plug 'kristijanhusak/vim-dadbod-completion'

" For built in omnifunc
autocmd FileType sql setlocal omnifunc=vim_dadbod_completion#omni

" hrsh7th/nvim-compe
let g:compe.source.vim_dadbod_completion = v:true

" hrsh7th/nvim-cmp
  autocmd FileType sql,mysql,plsql lua require('cmp').setup.buffer({ sources = {{ name = 'vim-dadbod-completion' }} })

" Shougo/ddc.vim
call ddc#custom#patch_filetype(['sql', 'mysql', 'plsql'], 'sources', 'dadbod-completion')
call ddc#custom#patch_filetype(['sql', 'mysql', 'plsql'], 'sourceOptions', {
\ 'dadbod-completion': {
\   'mark': 'DB',
\   'isVolatile': v:true,
\ },
\ })
```

Configuration using [lazy.nvim](https://github.com/folke/lazy.nvim) with [vim-dadbod-ui](https://github.com/kristijanhusak/vim-dadbod-ui)
```lua
return {
  {
    'kristijanhusak/vim-dadbod-ui',
    dependencies = {
      { 'tpope/vim-dadbod', lazy = true },
      { 'kristijanhusak/vim-dadbod-completion', ft = { 'sql', 'mysql', 'plsql' }, lazy = true },
    },
    cmd = {
      'DBUI',
      'DBUIToggle',
      'DBUIAddConnection',
      'DBUIFindBuffer',
    },
    init = function()
      -- Your DBUI configuration
      vim.g.db_ui_use_nerd_fonts = 1
    end,
  },
  { -- optional saghen/blink.cmp completion source
    'saghen/blink.cmp',
    opts = {
      sources = {
        -- add vim-dadbod-completion to your completion providers
        default = { "lsp", "path", "snippets", "buffer", "dadbod" },
        providers = {
          dadbod = { name = "Dadbod", module = "vim_dadbod_completion.blink" },
        },
      },
    },
  }
}
```

## Features
* Autocomplete table names, with automatic quoting where needed. Works for all schemes that [vim-dadbod](https://github.com/tpope/vim-dadbod) supports.
* Autocomplete table columns, context aware. Also knows to read aliases (`select * from mytable tbl where tbl.id = 1`). Currently works for `PostgreSQL`, `MySQL`, `Oracle`, `SQLite` (requires version `3.37.0 (2021-11-27)`) and `SQLserver/MSSQL`.
* Out of the box integration with [vim-dadbod-ui](https://github.com/kristijanhusak/vim-dadbod-ui)

## How it works
* If an sql buffer is created by [vim-dadbod-ui](https://github.com/kristijanhusak/vim-dadbod-ui), it reads all the configuration from there. It should work out of the box.
* If `vim-dadbod-ui` is not used, [vim-dadbod](https://github.com/tpope/vim-dadbod) `g:db` or `b:db` is used. If you want, you can also add `b:db_table` to limit autocompletions to that table only.

## Settings
Default mark for completion items is `[DB]`. To change it, add this to vimrc:
```
let g:vim_dadbod_completion_mark = 'MYMARK'
```

## Commands
This plugin caches the database tables and columns to leverage maximum performance. If you want to clear the cache at any point just run:

```
:DBCompletionClearCache
```

## Todo
* [ ] Integration for column autocompletion with more database types
