" Vim syntax file
" Language: PoV-Ray(tm) 3.7 configuration/initialization files
" Maintainer: David Necas (Yeti) <yeti@physics.muni.cz>
" Last Change: 2011-04-24
" Required Vim Version: 6.0

" Setup
" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn case ignore

" Syntax
syn match poviniInclude "^\s*[^[+-;]\S*\s*$" contains=poviniSection
syn match poviniLabel "^.\{-1,}\ze=" transparent contains=poviniKeyword nextgroup=poviniBool,poviniNumber
syn keyword poviniBool On Off True False Yes No
syn match poviniNumber "\<\d*\.\=\d\+\>"
syn keyword poviniKeyword Clock Initial_Frame Final_Frame Frame_Final Frame_Step Initial_Clock Final_Clock Subset_Start_Frame Subset_End_Frame Cyclic_Animation Clockless_Animation Real_Time_Raytracing Field_Render Odd_Field Work_Threads
syn keyword poviniKeyword Width Height Start_Column Start_Row End_Column End_Row Test_Abort Test_Abort_Count Continue_Trace Create_Ini
syn keyword poviniKeyword Display Video_Mode Palette Display_Gamma Pause_When_Done Verbose Draw_Vistas Preview_Start_Size Preview_End_Size Render_Block_Size Render_Block_Step Render_Pattern Max_Image_Buffer_Memory
syn keyword poviniKeyword Output_to_File Output_File_Type Output_Alpha Bits_Per_Color Output_File_Name Buffer_Output Buffer_Size Dither Dither_Method File_Gamma
syn keyword poviniKeyword BSP_Base BSP_Child BSP_Isect BSP_Max BSP_Miss
syn keyword poviniKeyword Histogram_Type Histogram_Grid_Size Histogram_Name
syn keyword poviniKeyword Input_File_Name Include_Header Library_Path Version
syn keyword poviniKeyword Debug_Console Fatal_Console Render_Console Statistic_Console Warning_Console All_Console Debug_File Fatal_File Render_File Statistic_File Warning_File All_File Warning_Level
syn keyword poviniKeyword Quality Bounding Bounding_Method Bounding_Threshold Light_Buffer Vista_Buffer Remove_Bounds Split_Unions Antialias Sampling_Method Antialias_Threshold Jitter Jitter_Amount Antialias_Depth Antialias_Gamma
syn keyword poviniKeyword Pre_Scene_Return Pre_Frame_Return Post_Scene_Return Post_Frame_Return User_Abort_Return Fatal_Error_Return
syn keyword poviniKeyword Radiosity Radiosity_File_Name Radiosity_From_File Radiosity_To_File Radiosity_Vain_Pretrace High_Reproducibility
syn match poviniShellOut "^\s*\(Pre_Scene_Command\|Pre_Frame_Command\|Post_Scene_Command\|Post_Frame_Command\|User_Abort_Command\|Fatal_Error_Command\)\>" nextgroup=poviniShellOutEq skipwhite
syn match poviniShellOutEq "=" nextgroup=poviniShellOutRHS skipwhite contained
syn match poviniShellOutRHS "[^;]\+" skipwhite contained contains=poviniShellOutSpecial
syn match poviniShellOutSpecial "%[osnkhw%]" contained
syn keyword poviniDeclare Declare
syn match poviniComment ";.*$"
syn match poviniOption "^\s*[+-]\S*"
syn match poviniIncludeLabel "^\s*Include_INI\s*=" nextgroup=poviniIncludedFile skipwhite
syn match poviniIncludedFile "[^;]\+" contains=poviniSection contained
syn region poviniSection start="\[" end="\]"

" Define the default highlighting
hi def link poviniSection Special
hi def link poviniComment Comment
hi def link poviniDeclare poviniKeyword
hi def link poviniShellOut poviniKeyword
hi def link poviniIncludeLabel poviniKeyword
hi def link poviniKeyword Type
hi def link poviniShellOutSpecial Special
hi def link poviniIncludedFile poviniInclude
hi def link poviniInclude Include
hi def link poviniOption Keyword
hi def link poviniBool Constant
hi def link poviniNumber Number

let b:current_syntax = "povini"
