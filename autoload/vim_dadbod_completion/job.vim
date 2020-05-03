let s:vim_job = {'output': '', 'exit': 0, 'close': 0 }

function! s:vim_job.cb(job, data) dict abort
  if type(a:data) ==? type(0)
    let self.exit = 1
    return self.call_cb_if_finished()
  endif
  let self.output .= a:data
endfunction

function! s:vim_job.close_cb(channel) dict abort
  let self.close = 1
  return self.call_cb_if_finished()
endfunction

function! s:vim_job.call_cb_if_finished() abort
  if self.close && self.exit
    return self.callback(split(self.output, "\n", 1))
  endif
endfunction

function! s:nvim_job_cb(jobid, data, event) dict abort
  if a:event ==? 'exit'
    return self.callback(self.output)
  endif
  call extend(self.output, a:data)
endfunction

function! vim_dadbod_completion#job#run(cmd, callback) abort
  if has('nvim')
    return jobstart(a:cmd, {
          \ 'on_stdout': function('s:nvim_job_cb'),
          \ 'on_stderr': function('s:nvim_job_cb'),
          \ 'on_exit': function('s:nvim_job_cb'),
          \ 'output': [],
          \ 'callback': a:callback,
          \ 'stdout_buffered': 1,
          \ 'stderr_buffered': 1,
          \ })
  endif

  if exists('*job_start')
    let fn = copy(s:vim_job)
    let fn.callback = a:callback
    let opts = {
          \ 'out_cb': fn.cb,
          \ 'err_cb': fn.cb,
          \ 'exit_cb': fn.cb,
          \ 'close_cb': fn.close_cb,
          \ 'mode': 'raw'
          \ }

    if has('patch-8.1.350')
      let opts['noblock'] = 1
    endif

    if has('win32')
        return job_start(printf('%s %s %s', &shell, &shellcmdflag, a:cmd), opts)
    else
        return job_start([&shell, &shellcmdflag, a:cmd], opts)
    endif
  endif

  let list = systemlist(a:cmd)
  return a:callback(list)
endfunction
