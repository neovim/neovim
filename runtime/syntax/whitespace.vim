" Simplistic way to make spaces and Tabs visible

" This can be added to an already active syntax.

syn match Space " "
syn match Tab "\t"
if &background == "dark"
  hi def Space ctermbg=darkred guibg=#500000
  hi def Tab ctermbg=darkgreen guibg=#003000
else
  hi def Space ctermbg=lightred guibg=#ffd0d0
  hi def Tab ctermbg=lightgreen guibg=#d0ffd0
endif
