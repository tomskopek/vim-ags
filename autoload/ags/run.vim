" Default ag executable path
let s:exe  = 'ag'

" Last command
let s:last = ''

" Last args
let s:lastArgs = ''

let s:id = ''

function! s:remove(args, name)
    return substitute(a:args, '\s\{}' . a:name . '\(=\S\{}\)\?', '', 'g')
endfunction

function! s:exists(args, name)
    return a:args =~ '\s\{1,}' . a:name . '\(=\|\s\)'
endfunction

function! s:cmd(args)
    let cmd  = has_key(g:, 'ags_agexe') ? g:ags_agexe . ' ' : s:exe
    let args = a:args

    for [ key, arg ] in items(g:ags_agargs)
        let value  = arg[0]
        let short  = arg[1]
        let exists = s:exists(args, key) || (strlen(short) > 0 && s:exists(args, short))

        if exists
            continue
        endif

        if value =~ '^g:'
            let value = substitute(value, '^g:', '', '')
            let value = get(g:, value, 0)
        endif

        let op   = strlen(value) == 0 ? '' : '='
        let cmd .= ' ' . key . op . value
    endfor

    let cmd    = cmd . ' ' . args
    let s:last = cmd

    return cmd
endfunction

" Runs an ag search with the given {args}
"
function! ags#run#ag(args)
    let s:lastArgs = a:args
    return system(s:cmd(a:args))
endfunction

" Runs an ag search with the givent {args} async.
" The functions {onOut}, {onExit}, and, {onError} will be used to
" communicate with the async process
"
function! ags#run#agAsync(args, onOut, onExit, onError)
    let s:lastArgs = a:args
    let cmd = split(s:cmd(a:args), '\s\+')
    if s:id
        silent! call jobstop(s:id)
    endif

    let s:id = jobstart(cmd, {
                \ 'on_stderr': a:onError,
                \ 'on_stdout': a:onOut,
                \ 'on_exit': a:onExit
                \ })
endfunction

" Runs the last ag search
"
function! ags#run#runLastCmd()
    return ags#run#ag(s:lastArgs)
endfunction

" Returns true if an ag search has been performed
"
function! ags#run#hasLastCmd()
    return !empty(s:lastArgs)
endfunction

" Return the arguments of the last command
"
function! ags#run#getLastArgs()
    return s:lastArgs
endfunction

" Displays the last ag command executed
"
function! ags#run#getLastCmd()
    echom s:last
endfunction
