let s:vim_job = {'output': '' }

function! s:vim_job.cb(job, data) dict abort
  if type(a:data) ==? type(0)
    return self.callback(split(self.output, "\n", 1))
  endif
  let self.output .= a:data
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
    call job_start([&shell, '-c', a:cmd], {
          \ 'out_cb': fn.cb,
          \ 'err_cb': fn.cb,
          \ 'exit_cb': fn.cb,
          \ 'mode': 'raw'
          \ })
  endif

  let list = systemlist(a:cmd)
  return a:callback(list)
endfunction
