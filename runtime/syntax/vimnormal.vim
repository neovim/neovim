syn match normalOp /[dcrypoaxv!"#%&.-\/:<>=?@ABCDGHIJKLMNOPQRSUVWXYZgmqstz~iu]/ nextgroup=normalMod
syn match normalMod /m\@<![ia]/
syn match normalObject /["'()<>BW\[\]`bstweE{}ftFT;,$]/
syn match normalCount /[0-9]/
syn region normalSearch start=/[/?]\@<=./ end=/.<CR>\@=/ contains=normalKey keepend
syn region normalChange start=/\([cr][wWbBeE()\[\]{}pst]\)\@<=./ end=/.\@=/ contains=normalKey keepend
syn match normalCharSearch /\c[ftr]\@<=\w/
syn match normalMark /\(f\@<!m\)\@<=[a-zA-Z0-9]/
syn match normalKey /<'\@!.\{-}>'\@!/

hi! link normalOp Operator
hi! link normalMod PreProc
hi! link normalObject Structure
hi! link normalCount Number
hi! link normalMark Identifier
hi! link normalKey Special
