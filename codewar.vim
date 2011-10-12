" Vim syntax file

" There are two sets of highlighting in here:
" If the "codewar_highlighting_clean" variable exists, it is rather sparse.
" Otherwise you get more highlighting.

" Quit when a syntax file was already loaded
if version < 600
   syntax clear
elseif exists("b:current_syntax")
  finish
endif

" codewar is case sensitive.
syn case match

  syn keyword codewarKeyword   r1 r2 acc ptr

  syn match   codewarOpCodeJmp "jmp"
  syn match   codewarOpCodeArith "add"
  syn match   codewarOpCodeOther "mov"

  syn match   codewarOperator "[*+\-\/]"

  syn match   codewarNumber	      "[0-9][0-9]*"
  syn match   codewarNumber	      "0x[0-9a-z][0-9a-z]*"
  syn match   codewarNumber	      "0b[01][01]*"

  syn match   codewarLable	      ":[a-z][a-z0-9]*"
  syn match   codewarLable	      "@[a-z][a-z0-9]*"
  syn match   codewarVar	      "\$[a-z][a-z0-9]*"
  syn match   codewarComment	      +;.*+


syn sync maxlines=50
" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_codewar_syn_inits")
  if version < 508
    let did_codewar_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  " The default highlighting.
    HiLink codewarComment		        Comment

    HiLink codewarKeyword	Statement

    HiLink codewarOpCodeArith     Keyword	
    HiLink codewarOpCodeJmp       Statement
    HiLink codewarOpCodeOther     Identifier

    HiLink codewarLable         Type
    HiLink codewarVar           String
    HiLink codewarNumber		Number
    HiLink codewarOperator	Identifier

  delcommand HiLink
endif

let b:current_syntax = "codewar"

" vim: ts=8
