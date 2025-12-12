set et
set smartcase
set smartindent
set nocompatible            " disable compatibility to old-time vi
set showmatch               " show matching 
set ignorecase              " case insensitive 
set mouse=v                 " middle-click paste with 
set hlsearch                " highlight search 
set incsearch               " incremental search
set tabstop=4               " number of columns occupied by a tab 
set softtabstop=4           " see multiple spaces as tabstops so <BS> does the right thing
set expandtab               " converts tabs to white space
set shiftwidth=4            " width for autoindents
" set autoindent              " indent a new line the same amount as the line just typed
set number                  " add line numbers
set wildmode=longest,list   " get bash-like tab completions
" set cc=100                  " set an 80 column border for good coding style
filetype plugin indent on   "allow auto-indenting depending on file type
syntax on                   " syntax highlighting
set mouse=a                 " enable mouse click
set clipboard=unnamedplus   " using system clipboard
filetype plugin on
" set cursorline              " highlight current cursorline
set ttyfast                 " Speed up scrolling in Vim
" set relativenumber
" set spell                 " enable spell check (may need to download language package)
" set noswapfile            " disable creating swap file
" set backupdir=~/.cache/vim " Directory to store backup files.

" Split related
set splitright
set splitbelow

if !has('nvim')
  set ttymouse=xterm2
  " Tell vim to remember certain things when we exit
  "  '10  :  marks will be remembered for up to 10 previously edited files
  "  "100 :  will save up to 100 lines for each register
  "  :20  :  up to 20 lines of command-line history will be remembered
  "  %    :  saves and restores the buffer list
  "  n... :  where to save the viminfo files
  set viminfo='10,\"100,:20,%,n~/.viminfo
endif

"" Open file at last position
if has("autocmd")
  au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
endif

if has('nvim')
    tnoremap <Esc> <C-\><C-n>
endif

if has('persistent_undo')         "check if your vim version supports
  set undodir=$HOME/.vim/undo     "directory where the undo files will be stored
  set undofile                    "turn on the feature
endif

" " Make <CR> to accept selected completion item or notify coc.nvim to format
" " <C-g>u breaks current undo, please make your own choice.
" inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm()
"                               \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

if &diff
  highlight DiffAdd    cterm=none ctermfg=Black ctermbg=LightCyan gui=none guifg=bg guibg=Red
  highlight DiffDelete cterm=none ctermfg=Black ctermbg=DarkCyan gui=none guifg=bg guibg=Red
  highlight DiffChange cterm=none ctermfg=Black ctermbg=Green gui=none guifg=bg guibg=Red
  highlight DiffText   cterm=none ctermfg=Black ctermbg=DarkRed gui=none guifg=bg guibg=Red
endif

"Remove trailing whitespaces on save
autocmd BufWritePre *.py :%s/\s\+$//e
autocmd BufWritePre *.cxx :%s/\s\+$//e
autocmd BufWritePre *.h :%s/\s\+$//e
autocmd BufWritePre *.pl :%s/\s\+$//e
autocmd BufWritePre *.pm :%s/\s\+$//e

set mouse-=a

noremap Zz <c-w>_ \| <c-w>\|
noremap Zo <c-w>=

map <C-N> :se nu!<CR>

" table mode toggle
noremap <Leader>tm :TableModeToggle

fun! ShowFuncName()
  let lnum = line(".")
  let col = col(".")
  echohl ModeMsg
  echo getline(search("^[^ \t#/]\\{2}.*[^:]\s*$", 'bW'))
  echohl None
  call search("\\%" . lnum . "l" . "\\%" . col . "c")
endfun
map :f :call ShowFuncName() <CR>

function! DebugPyPrint()
  let var_name = input('Variable name: ')
  execute "normal! oprint(f'VIVEK_DBG:: {".var_name."=}', file=sys.stderr)"
  "execute "normal! Oprint(f'DEBUG:: {inspect.currentframe().f_back.f_code.co_filename}:{inspect.currentframe().f_back.f_lineno}:: {".var_name."=}')"
endfun

nnoremap <Leader>dp :call DebugPyPrint()<CR>

" all unmappings
silent! unmap t
silent! unmap <C-E>
