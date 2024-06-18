" Maintainer: Maxim Kim <habamax@gmail.com>
" Converted from vim9script
" Last Update: 2024-06-18

if !exists("b:csv_delimiter")
    " detect delimiter
    let s:delimiters = ",;\t|"

    let s:max = 0
    for d in s:delimiters
        let s:count = getline(1)->split(d)->len() + getline(2)->split(d)->len()
        if s:count > s:max
            let s:max = s:count
            let b:csv_delimiter = d
        endif
    endfor
endif

if exists("b:did_ftplugin")
    finish
endif
let b:did_ftplugin = 1
