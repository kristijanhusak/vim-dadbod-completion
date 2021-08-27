if exists('g:loaded_compe') && has('nvim')
  call compe#register_source('vim_dadbod_completion', vim_dadbod_completion#compe#create())
endif
