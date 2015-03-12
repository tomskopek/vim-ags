
" The position of the last highlighted search pattern
let s:hlpos = []

" Last copied value
let s:lastCopy = ''

" Regex pattern functions
let s:pat  = function('ags#pat#mkpat')
let s:subg = function('ags#pat#subg')
let s:sub  = function('ags#pat#sub')

" Run search
let s:run = function('ags#run#ag')

" Search results usage
let s:usage = [
            \ ' Search Results Key Bindings',
            \ ' ---------------------------',
            \ ' ',
            \ ' Results Window Commands',
            \ ' p - navigate file paths forward',
            \ ' P - navigate files paths backwards',
            \ ' r - navigate results forward',
            \ ' R - navigate results backwards',
            \ ' a - display the file path for current results',
            \ ' c - copy to clipboard the file path for current results',
            \ ' u - usage',
            \ ' ',
            \ ' Open Window Commands',
            \ ' oa - open file above the results window',
            \ ' ob - open file below the results window',
            \ ' ol - open file to the left of the results window',
            \ ' or - open file to the right of the results window',
            \ ' os - open file in the results window',
            \ ' ou - open file in a previously opened window (alias Enter)',
            \ ' ',
            \ ]

" Window position flags
let s:wflags = { 't' : 'above', 'a' : 'above', 'b' : 'below', 'r' : 'right', 'l' : 'left' }

" Executes a write command
"
function! s:execw(...)
    execute 'setlocal modifiable'
    for cmd in a:000
        if type(cmd) == type({})
            call cmd.run()
        else
            execute cmd
        endif
    endfor
    execute 'setlocal nomodifiable'
endfunction

" Displays the search results from {lines} in the
" search results window
"
function! s:show(lines, ...)
    let obj = { 'add': a:0 && a:1, 'lines': a:lines }

    function obj.run()
        if self.add
            call append('$', self.lines)
        else
            execute '%delete'
            call append(0, self.lines)
            execute 'normal gg'
        endif
    endfunction

    call ags#buf#OpenResultsBuffer()
    call s:execw(obj)
endfunction

" Prepares the search {data} for display
"
function! s:process(data)
    let data    = substitute(a:data, '\e', '', 'g')
    let lines   = split(data, '\n')
    let lmaxlen = 0
    let lineNo  = s:pat('^:lineStart:\(\d\{1,}\)')

    for line in lines
        let lmatch  = matchstr(line, lineNo)
        let lmaxlen = max([ strlen(lmatch), lmaxlen ])
    endfor

    let results = []
    for line in lines
        let llen = strlen(matchstr(line, lineNo))
        let wlen = lmaxlen - llen

        " right justify line numbers
        let line = s:sub(line, lineNo, ':lineStart:' . repeat(' ', wlen) . '\1')

        " add a space between line number and start of text
        let line = s:sub(line, '^\(.\{-}:lineEnd:\)\(.\{1,}$\)\@=', '\1 ')

        " add a space between line and column number and start of text
        let line = s:sub(line, '^\(.\{-}:lineColEnd:\)', '\1 ')

        call add(results, line)
    endfor

    return results
endfunction

" Returns the cursor position when opening a file
" from the {lineNo} in the search results window
"
function! s:resultPosition(lineNo)
    let line = getline(a:lineNo)
    let col  = 0

    if line =~ s:pat(':file:')
        let line = getline(a:lineNo + 1)
    endif

    if strlen(line) == 0 || line =~ '^--$'
        let line = getline(a:lineNo - 1)
    endif

    if line =~ s:pat('^:lineStart:\s\{}\d\{1,}:lineColEnd:')
        let col = matchstr(line, ':\zs\d\{1,}:\@=')
    endif

    let row = matchstr(line, s:pat('^:lineStart:\s\{}\zs\d\{1,}[\@='))

    return [0, row, col, 0]
endfunction

" Performs a search with the specified {args}. If {add} is true
" the results will be added to the search results window; otherwise,
" they will replace any previous results.
"
function! ags#Search(args, add)
    let args  = empty(a:args) ? expand('<cword>') : a:args
    let data  = s:run(args)
    let lines = s:process(data)
    call s:show(lines, a:add)
endfunction

" Returns the file path for the search results
" relative to {lineNo}
"
function! ags#FilePath(lineNo)
    let nr = a:lineNo

    while nr >= 0 && getline(nr) !~ s:pat(':file:')
        let nr = nr - 1
    endw

    return s:sub(getline(nr), '^:file:', '\1')
endfunction

" Sets the {text} into the copy registers
"
function! s:setYanked(text)
    let @+ = a:text
    let @* = a:text
    let @@ = a:text
endfunction

" Copies to clipboard the file path for the search results
" relative to {lineNo}
"
function! ags#CopyFilePath(lineNo, fullPath)
    let file = ags#FilePath(a:lineNo)
    let file = a:fullPath ? fnamemodify(file, ':p') : file
    call s:setYanked(file)
    return 'Copied ' . file
endfunction

" Removes any delimiters from the yanked text
"
function! ags#CleanYankedText()
    if empty(@0) || @0 == s:lastCopy | return | endif

    let s:lastCopy = @0

    let text = @0
    let text = s:subg(text,  ':file:', '\1')
    let text = s:subg(text, ':\lineStart:\([ 0-9]\{-1,}\):lineColEnd:', '\1')
    let text = s:subg(text, ':\lineStart:\([ 0-9]\{-1,}\):lineEnd:', '\1')
    let text = s:subg(text, ':resultStart::hlDelim:\(.\{-1,}\):hlDelim::end:', '\1')
    let text = s:subg(text, ':resultStart:\(.\{-1,}\):end:', '\1')

    call s:setYanked(text)
endfunction

" Opens a results file
"
" {lineNo}  the line number in the search results buffer
" {flags}   window location flags
" {flags|s} opens the file in the search results window
" {flags|a} opens the file above the search results window
" {flags|b} opens the file below the search results window
" {flags|r} opens the file to the right of the search results window
" {flags|l} opens the file to the left of the search results window
" {flags|u} opens the file to in a previously opened window
" {preview} set to true to keep focus in the search results window
"
function! ags#OpenFile(lineNo, flags, preview)
    let path  = fnameescape(ags#FilePath(a:lineNo))
    let pos   = s:resultPosition(a:lineNo)
    let flags = has_key(s:wflags, a:flags) ? s:wflags[a:flags] : 'above'
    let wpos  = a:flags == 's'
    let reuse = a:flags == 'u'

    if filereadable(path)
        call ags#buf#OpenBuffer(path, flags, wpos, reuse)
        call setpos('.', pos)

        if a:preview
            execute 'wincmd p'
        endif
    endif
endfunction

" Clears the highlighted result pattern if any
"
function! ags#ClearHlResult()
    if empty(s:hlpos) | return | endif

    let lineNo  = s:hlpos[1]
    let lastNo  = line('$')
    let s:hlpos = []

    if lineNo < 0 || lineNo > lastNo | return | endif

    let pos  = getpos('.')
    let expr = s:pat(':\resultStart::\hlDelim:\(.\{-}\):\hlDelim::\end:')
    let repl = s:pat(':resultStart:\1:end:')
    let cmd  = 'silent ' . lineNo . 's/\m' . expr . '/' . repl . '/ge'

    call s:execw(cmd)
    call setpos('.', pos)
endfunction

" Navigates the next result pattern on the same line
"
function! ags#NavigateResultsOnLine()
    let line = getline('.')
    let result = s:pat(':resultStart:.\{-}:end:')
    if line =~ result
        let [bufnum, lnum, col, off] = getpos('.')
        call setpos('.', [bufnum, lnum, 0, off])
        call ags#NavigateResults()
    endif
endfunction

" Navigates the search results patterns
"
" {flags} search flags (b, B, w, W)
"
function! ags#NavigateResults(...)
    call ags#ClearHlResult()

    let flags = a:0 > 0 ? a:1 : 'w'
    call search(s:pat(':resultStart:.\{-}:end:'), flags)

    let pos  = getpos('.')
    let line = getline('.')
    let row  = pos[1]
    let col  = pos[2]

    let expr = s:pat(':\resultStart:\(.\{-}\):\end:')
    let repl = s:pat(':resultStart::hlDelim:\1:hlDelim::end:')
    let cmd  = 'silent ' . row . 's/\m\%' . col . 'c' . expr . '/' . repl . '/e'

    call s:execw(cmd)
    call setpos('.', pos)

    let s:hlpos = pos
endfunction

" Navigates the search results file paths
"
" {flags} search flags (b, B, w, W)
function! ags#NavigateResultsFiles(...)
    call ags#ClearHlResult()
    let flags = a:0 > 0 ? a:1 : 'w'
    let file = s:pat(':file:')
    call search(file, flags)
    execute 'normal zt'
endfunction

function! ags#Quit()
    call ags#buf#CloseResultsBuffer()
endfunction

function! ags#Usage()
    for u in s:usage | echom u | endfor
endfunction