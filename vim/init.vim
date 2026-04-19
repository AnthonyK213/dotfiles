" Options

filetype on
filetype indent on
filetype plugin on
syntax on

set ruler number cursorline hidden
set cmdheight=1
set scrolloff=8
set laststatus=2
set signcolumn=yes
set colorcolumn=80
set shortmess+=c
set noshowmode showcmd
set list listchars=tab:>-,trail:·
set background=dark
set encoding=utf-8
set fileencodings=utf-8,chinese,ucs-bom,latin-1,shift-jis,gb18030,gbk,gb2312,cp936
set fileformats=unix,dos,mac
set formatoptions+=mB
set autoindent nosmartindent
set tabstop=2 shiftwidth=2 softtabstop=2
set wrap linebreak showbreak=^
set expandtab smarttab
set backspace=2
set splitbelow splitright
set noerrorbells novisualbell
set winaltkeys=no
set history=500
set notimeout
set hlsearch incsearch
set ignorecase smartcase
set nobackup writebackup
set noswapfile noundofile
set autoread autowrite
set confirm
set nomodeline nomodelineexpr
set mouse=nvic

" Keymaps

let g:mapleader = " "

cno <C-A> <C-B>
cno <C-B> <LEFT>
cno <C-F> <RIGHT>
cno <M-b> <C-LEFT>
cno <M-f> <C-RIGHT>
cno <M-BS> <C-W>
ino <M-b> <C-\><C-O>b
ino <M-f> <C-\><C-O>e<Right>
ino <M-d> <C-\><C-O>dw
ino <C-A> <C-\><C-O>g0
ino <C-E> <C-\><C-O>g$
ino <C-K> <C-\><C-O>D
ino <expr><silent> <C-B> col(".") == 1 ? '<C-\><C-O>-<C-\><C-O>$' : '<C-G>U<Left>'
ino <expr><silent> <C-F> col(".") >= col("$") ? '<C-\><C-O>+<C-\><C-O>0' : '<C-G>U<Right>'
ino <silent> <C-N> <C-\><C-O>gj
ino <silent> <C-P> <C-\><C-O>gk
ino <M-x> <C-\><C-O>:
nn <M-x> :
nn <silent> <M-p> <Cmd>m.-2<CR>
nn <silent> <M-n> <Cmd>m.+1<CR>
xn <silent> <M-p> :<C-U>exe "'<,'>move" max([line("'<") - 2, 0])<CR>gv
xn <silent> <M-n> :<C-U>exe "'<,'>move" min([line("'>") + 1, line("$")])<CR>gv

nn <leader>bd <Cmd>bd<CR>
nn <leader>bn <Cmd>bn<CR>
nn <leader>bp <Cmd>bp<CR>
nn <leader>bh <Cmd>noh<CR>

nn <leader>fb :buffer<space>

" netrw

let g:netrw_altv = 1
let g:netrw_banner = 0
let g:netrw_winsize = 20
let g:netrw_liststyle = 0
let g:netrw_browse_split = 0
let g:netrw_clipboard = 0
let g:netrw_fastbrowse = 0
let g:netrw_timefmt = "%Y-%m-%d %H:%M"
let g:netrw_sort_by = "name"

nn <silent> <leader>op <Cmd>Explore<CR>

augroup VimrcNetrw
  au!
  au FileType netrw setlocal nobuflisted bufhidden=wipe
  au FileType netrw nn <buffer> <leader>op <Cmd>Rexplore<CR>
augroup END
