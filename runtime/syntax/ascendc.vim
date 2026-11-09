" Vim syntax file
" Language:     Ascend C
" Maintainer:   Yinzuo Jiang <jiangyinzuo@foxmail.com>
" Last Change:  2026 Nov 6

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

runtime! syntax/cpp.vim

" CANN 9.0 language-extension keywords.
" https://www.hiascend.com/doc_center/source/en/CANNCommunityEdition/900/programug/Ascendcopdevg/atlas_ascendc_10_10053.html
" https://www.hiascend.com/doc_center/source/en/CANNCommunityEdition/900/programug/Ascendcopdevg/atlas_ascendc_10_10054.html
" Kernel declaration and execution qualifiers:
" https://www.hiascend.com/doc_center/source/en/CANNCommunityEdition/900/programug/Ascendcopdevg/atlas_ascendc_10_0014.html
" SIMD/SIMT function qualifiers and address spaces:
" https://www.hiascend.com/doc_center/source/en/CANNCommunityEdition/900/programug/Ascendcopdevg/atlas_ascendc_10_10052.html
syn keyword ascendcStorageClass __aicore__ __global__ __host__ __gm__ __ubuf__ __cbuf__ __ca__ __cb__ __cc__
syn keyword ascendcStorageClass __fbuf__ __ssbuf__ __aicpu__ __cube__ __vector__ __mix__
syn keyword ascendcStorageClass __simd_vf__ __simt_vf__ __simd_callee__ __simt_callee__
syn keyword ascendcStorageClass __inline__ __launch_bounds__ __schedmode__
hi def link ascendcStorageClass StorageClass

let b:current_syntax = "ascendc"

" vim: ts=8
