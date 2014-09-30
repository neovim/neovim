" Vim syntax file
" Language:	Mutt setup files
" Original:	Preben 'Peppe' Guldberg <peppe-vim@wielders.org>
" Maintainer:	Kyle Wheeler <kyle-muttrc.vim@memoryhole.net>
" Last Change:	2 Feb 2012

" This file covers mutt version 1.5.21 (and most of the mercurial tip)
" Included are also a few features from 1.4.2.1

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Set the keyword characters
if version < 600
  set isk=@,48-57,_,-
else
  setlocal isk=@,48-57,_,-
endif

" handling optional variables
if !exists("use_mutt_sidebar")
  let use_mutt_sidebar=0
endif

syn match muttrcComment		"^# .*$" contains=@Spell
syn match muttrcComment		"^#[^ ].*$"
syn match muttrcComment		"^#$"
syn match muttrcComment		"[^\\]#.*$"lc=1

" Escape sequences (back-tick and pipe goes here too)
syn match muttrcEscape		+\\[#tnr"'Cc ]+
syn match muttrcEscape		+[`|]+
syn match muttrcEscape		+\\$+

" The variables takes the following arguments
"syn match  muttrcString		contained "=\s*[^ #"'`]\+"lc=1 contains=muttrcEscape
syn region muttrcString		contained keepend start=+"+ms=e skip=+\\"+ end=+"+ contains=muttrcEscape,muttrcCommand,muttrcAction,muttrcShellString
syn region muttrcString		contained keepend start=+'+ms=e skip=+\\'+ end=+'+ contains=muttrcEscape,muttrcCommand,muttrcAction
syn match muttrcStringNL	contained skipwhite skipnl "\s*\\$" nextgroup=muttrcString,muttrcStringNL

syn region muttrcShellString	matchgroup=muttrcEscape keepend start=+`+ skip=+\\`+ end=+`+ contains=muttrcVarStr,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcCommand

syn match  muttrcRXChars	contained /[^\\][][.*?+]\+/hs=s+1
syn match  muttrcRXChars	contained /[][|()][.*?+]*/
syn match  muttrcRXChars	contained /['"]^/ms=s+1
syn match  muttrcRXChars	contained /$['"]/me=e-1
syn match  muttrcRXChars	contained /\\/
" Why does muttrcRXString2 work with one \ when muttrcRXString requires two?
syn region muttrcRXString	contained skipwhite start=+'+ skip=+\\'+ end=+'+ contains=muttrcRXChars
syn region muttrcRXString	contained skipwhite start=+"+ skip=+\\"+ end=+"+ contains=muttrcRXChars
syn region muttrcRXString	contained skipwhite start=+[^ 	"'^]+ skip=+\\\s+ end=+\s+re=e-1 contains=muttrcRXChars
" For some reason, skip refuses to match backslashes here...
syn region muttrcRXString	contained matchgroup=muttrcRXChars skipwhite start=+\^+ end=+[^\\]\s+re=e-1 contains=muttrcRXChars
syn region muttrcRXString	contained matchgroup=muttrcRXChars skipwhite start=+\^+ end=+$\s+ contains=muttrcRXChars
syn region muttrcRXString2	contained skipwhite start=+'+ skip=+\'+ end=+'+ contains=muttrcRXChars
syn region muttrcRXString2	contained skipwhite start=+"+ skip=+\"+ end=+"+ contains=muttrcRXChars

" these must be kept synchronized with muttrcRXString, but are intended for
" muttrcRXHooks
syn region muttrcRXHookString	contained keepend skipwhite start=+'+ skip=+\\'+ end=+'+ contains=muttrcRXString nextgroup=muttrcString,muttrcStringNL
syn region muttrcRXHookString	contained keepend skipwhite start=+"+ skip=+\\"+ end=+"+ contains=muttrcRXString nextgroup=muttrcString,muttrcStringNL
syn region muttrcRXHookString	contained keepend skipwhite start=+[^ 	"'^]+ skip=+\\\s+ end=+\s+re=e-1 contains=muttrcRXString nextgroup=muttrcString,muttrcStringNL
syn region muttrcRXHookString	contained keepend skipwhite start=+\^+ end=+[^\\]\s+re=e-1 contains=muttrcRXString nextgroup=muttrcString,muttrcStringNL
syn region muttrcRXHookString	contained keepend matchgroup=muttrcRXChars skipwhite start=+\^+ end=+$\s+ contains=muttrcRXString nextgroup=muttrcString,muttrcStringNL
syn match muttrcRXHookStringNL contained skipwhite skipnl "\s*\\$" nextgroup=muttrcRXHookString,muttrcRXHookStringNL

" these are exclusively for args lists (e.g. -rx pat pat pat ...)
syn region muttrcRXPat		contained keepend skipwhite start=+'+ skip=+\\'+ end=+'\s*+ contains=muttrcRXString nextgroup=muttrcRXPat
syn region muttrcRXPat		contained keepend skipwhite start=+"+ skip=+\\"+ end=+"\s*+ contains=muttrcRXString nextgroup=muttrcRXPat
syn match muttrcRXPat		contained /[^-'"#!]\S\+/ skipwhite contains=muttrcRXChars nextgroup=muttrcRXPat
syn match muttrcRXDef 		contained "-rx\s\+" skipwhite nextgroup=muttrcRXPat

syn match muttrcSpecial		+\(['"]\)!\1+

syn match muttrcSetStrAssignment contained skipwhite /=\s*\%(\\\?\$\)\?[0-9A-Za-z_-]\+/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr contains=muttrcVariable,muttrcEscapedVariable
syn region muttrcSetStrAssignment contained skipwhite keepend start=+=\s*"+hs=s+1 end=+"+ skip=+\\"+ nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr contains=muttrcString
syn region muttrcSetStrAssignment contained skipwhite keepend start=+=\s*'+hs=s+1 end=+'+ skip=+\\'+ nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr contains=muttrcString
syn match muttrcSetBoolAssignment contained skipwhite /=\s*\\\?\$\w\+/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr contains=muttrcVariable,muttrcEscapedVariable
syn match muttrcSetBoolAssignment contained skipwhite /=\s*\%(yes\|no\)/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn match muttrcSetBoolAssignment contained skipwhite /=\s*"\%(yes\|no\)"/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn match muttrcSetBoolAssignment contained skipwhite /=\s*'\%(yes\|no\)'/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn match muttrcSetQuadAssignment contained skipwhite /=\s*\\\?\$\w\+/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr contains=muttrcVariable,muttrcEscapedVariable
syn match muttrcSetQuadAssignment contained skipwhite /=\s*\%(ask-\)\?\%(yes\|no\)/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn match muttrcSetQuadAssignment contained skipwhite /=\s*"\%(ask-\)\?\%(yes\|no\)"/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn match muttrcSetQuadAssignment contained skipwhite /=\s*'\%(ask-\)\?\%(yes\|no\)'/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn match muttrcSetNumAssignment contained skipwhite /=\s*\\\?\$\w\+/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr contains=muttrcVariable,muttrcEscapedVariable
syn match muttrcSetNumAssignment contained skipwhite /=\s*\d\+/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn match muttrcSetNumAssignment contained skipwhite /=\s*"\d\+"/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn match muttrcSetNumAssignment contained skipwhite /=\s*'\d\+'/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

" Now catch some email addresses and headers (purified version from mail.vim)
syn match muttrcEmail		"[a-zA-Z0-9._-]\+@[a-zA-Z0-9./-]\+"
syn match muttrcHeader		"\<\%(From\|To\|C[Cc]\|B[Cc][Cc]\|Reply-To\|Subject\|Return-Path\|Received\|Date\|Replied\|Attach\)\>:\="

syn match   muttrcKeySpecial	contained +\%(\\[Cc'"]\|\^\|\\[01]\d\{2}\)+
syn match   muttrcKey		contained "\S\+"			contains=muttrcKeySpecial,muttrcKeyName
syn region  muttrcKey		contained start=+"+ skip=+\\\\\|\\"+ end=+"+	contains=muttrcKeySpecial,muttrcKeyName
syn region  muttrcKey		contained start=+'+ skip=+\\\\\|\\'+ end=+'+	contains=muttrcKeySpecial,muttrcKeyName
syn match   muttrcKeyName	contained "\<f\%(\d\|10\)\>"
syn match   muttrcKeyName	contained "\\[trne]"
syn match   muttrcKeyName	contained "\c<\%(BackSpace\|BackTab\|Delete\|Down\|End\|Enter\|Esc\|Home\|Insert\|Left\|PageDown\|PageUp\|Return\|Right\|Space\|Tab\|Up\)>"
syn match   muttrcKeyName	contained "<F[0-9]\+>"

syn keyword muttrcVarBool	skipwhite contained allow_8bit allow_ansi arrow_cursor ascii_chars askbcc askcc attach_split auto_tag autoedit beep beep_new nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained bounce_delivered braille_friendly check_new check_mbox_size nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained collapse_unread confirmappend confirmcreate crypt_autoencrypt nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained crypt_autopgp crypt_autosign crypt_autosmime crypt_replyencrypt nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained crypt_replysign crypt_replysignencrypted crypt_timestamp nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained crypt_use_gpgme crypt_use_pka delete_untag digest_collapse duplicate_threads nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained edit_hdrs edit_headers encode_from envelope_from fast_reply nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained fcc_clear followup_to force_name forw_decode nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained forw_decrypt forw_quote forward_decode forward_decrypt nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained forward_quote hdrs header help hidden_host hide_limited nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained hide_missing hide_thread_subject hide_top_limited nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained hide_top_missing honor_disposition ignore_linear_white_space ignore_list_reply_to imap_check_subscribed nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained imap_list_subscribed imap_passive imap_peek imap_servernoise nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained implicit_autoview include_onlyfirst keep_flagged nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained mailcap_sanitize maildir_header_cache_verify maildir_trash nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained mark_old markers menu_move_off menu_scroll message_cache_clean meta_key nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained metoo mh_purge mime_forward_decode narrow_tree pager_stop nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained pgp_auto_decode pgp_auto_traditional pgp_autoencrypt nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained pgp_autoinline pgp_autosign pgp_check_exit nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained pgp_create_traditional pgp_ignore_subkeys pgp_long_ids nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained pgp_replyencrypt pgp_replyinline pgp_replysign nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained pgp_replysignencrypted pgp_retainable_sigs pgp_show_unusable nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained pgp_strict_enc pgp_use_gpg_agent pipe_decode pipe_split nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained pop_auth_try_all pop_last print_decode print_split nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained prompt_after read_only reply_self resolve reverse_alias nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained reverse_name reverse_realname rfc2047_parameters save_address nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained save_empty save_name score sig_dashes sig_on_top nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained smart_wrap smime_ask_cert_label smime_decrypt_use_default_key nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained smime_is_default sort_re ssl_force_tls ssl_use_sslv2 nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained ssl_use_sslv3 ssl_use_tlsv1 ssl_usesystemcerts ssl_verify_dates ssl_verify_host status_on_top nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained strict_mime strict_threads suspend text_flowed thorough_search nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained thread_received tilde uncollapse_jump use_8bitmime nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained use_domain use_envelope_from use_from use_idn use_ipv6 nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained user_agent wait_key weed wrap_search write_bcc nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

syn keyword muttrcVarBool	skipwhite contained noallow_8bit noallow_ansi noarrow_cursor noascii_chars noaskbcc nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained noaskcc noattach_split noauto_tag noautoedit nobeep nobeep_new nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nobounce_delivered nobraille_friendly nocheck_new nocollapse_unread nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained noconfirmappend noconfirmcreate nocrypt_autoencrypt nocrypt_autopgp nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nocrypt_autosign nocrypt_autosmime nocrypt_replyencrypt nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nocrypt_replysign nocrypt_replysignencrypted nocrypt_timestamp nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nocrypt_use_gpgme nodelete_untag nodigest_collapse noduplicate_threads nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained noedit_hdrs noedit_headers noencode_from noenvelope_from nofast_reply nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nofcc_clear nofollowup_to noforce_name noforw_decode nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained noforw_decrypt noforw_quote noforward_decode noforward_decrypt nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained noforward_quote nohdrs noheader nohelp nohidden_host nohide_limited nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nohide_missing nohide_thread_subject nohide_top_limited nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nohide_top_missing nohonor_disposition noignore_list_reply_to noimap_check_subscribed nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained noimap_list_subscribed noimap_passive noimap_peek noimap_servernoise nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained noimplicit_autoview noinclude_onlyfirst nokeep_flagged nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nomailcap_sanitize nomaildir_header_cache_verify nomaildir_trash nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nomark_old nomarkers nomenu_move_off nomenu_scroll nometa_key nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nometoo nomh_purge nomime_forward_decode nonarrow_tree nopager_stop nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nopgp_auto_decode nopgp_auto_traditional nopgp_autoencrypt nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nopgp_autoinline nopgp_autosign nopgp_check_exit nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nopgp_create_traditional nopgp_ignore_subkeys nopgp_long_ids nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nopgp_replyencrypt nopgp_replyinline nopgp_replysign nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nopgp_replysignencrypted nopgp_retainable_sigs nopgp_show_unusable nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nopgp_strict_enc nopgp_use_gpg_agent nopipe_decode nopipe_split nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nopop_auth_try_all nopop_last noprint_decode noprint_split nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained noprompt_after noread_only noreply_self noresolve noreverse_alias nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained noreverse_name noreverse_realname norfc2047_parameters nosave_address nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nosave_empty nosave_name noscore nosig_dashes nosig_on_top nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nosmart_wrap nosmime_ask_cert_label nosmime_decrypt_use_default_key nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nosmime_is_default nosort_re nossl_force_tls nossl_use_sslv2 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nossl_use_sslv3 nossl_use_tlsv1 nossl_usesystemcerts nostatus_on_top nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nostrict_threads nosuspend notext_flowed nothorough_search nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nothread_received notilde nouncollapse_jump nouse_8bitmime nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nouse_domain nouse_envelope_from nouse_from nouse_idn nouse_ipv6 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained nouser_agent nowait_key noweed nowrap_search nowrite_bcc nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

syn keyword muttrcVarBool	skipwhite contained invallow_8bit invallow_ansi invarrow_cursor invascii_chars invaskbcc nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invaskcc invattach_split invauto_tag invautoedit invbeep invbeep_new nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invbounce_delivered invbraille_friendly invcheck_new invcollapse_unread nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invconfirmappend invconfirmcreate invcrypt_autoencrypt invcrypt_autopgp nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invcrypt_autosign invcrypt_autosmime invcrypt_replyencrypt nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invcrypt_replysign invcrypt_replysignencrypted invcrypt_timestamp nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invcrypt_use_gpgme invdelete_untag invdigest_collapse invduplicate_threads nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invedit_hdrs invedit_headers invencode_from invenvelope_from invfast_reply nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invfcc_clear invfollowup_to invforce_name invforw_decode nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invforw_decrypt invforw_quote invforward_decode invforward_decrypt nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invforward_quote invhdrs invheader invhelp invhidden_host invhide_limited nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invhide_missing invhide_thread_subject invhide_top_limited nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invhide_top_missing invhonor_disposition invignore_list_reply_to invimap_check_subscribed nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invimap_list_subscribed invimap_passive invimap_peek invimap_servernoise nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invimplicit_autoview invinclude_onlyfirst invkeep_flagged nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invmailcap_sanitize invmaildir_header_cache_verify invmaildir_trash nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invmark_old invmarkers invmenu_move_off invmenu_scroll invmeta_key nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invmetoo invmh_purge invmime_forward_decode invnarrow_tree invpager_stop nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invpgp_auto_decode invpgp_auto_traditional invpgp_autoencrypt nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invpgp_autoinline invpgp_autosign invpgp_check_exit nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invpgp_create_traditional invpgp_ignore_subkeys invpgp_long_ids nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invpgp_replyencrypt invpgp_replyinline invpgp_replysign nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invpgp_replysignencrypted invpgp_retainable_sigs invpgp_show_unusable nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invpgp_strict_enc invpgp_use_gpg_agent invpipe_decode invpipe_split nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invpop_auth_try_all invpop_last invprint_decode invprint_split nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invprompt_after invread_only invreply_self invresolve invreverse_alias nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invreverse_name invreverse_realname invrfc2047_parameters invsave_address nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invsave_empty invsave_name invscore invsig_dashes invsig_on_top nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invsmart_wrap invsmime_ask_cert_label invsmime_decrypt_use_default_key nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invsmime_is_default invsort_re invssl_force_tls invssl_use_sslv2 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invssl_use_sslv3 invssl_use_tlsv1 invssl_usesystemcerts invstatus_on_top nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invstrict_threads invsuspend invtext_flowed invthorough_search nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invthread_received invtilde invuncollapse_jump invuse_8bitmime nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invuse_domain invuse_envelope_from invuse_from invuse_idn invuse_ipv6 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarBool	skipwhite contained invuser_agent invwait_key invweed invwrap_search invwrite_bcc nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
if use_mutt_sidebar == 1
    syn keyword muttrcVarBool skipwhite contained sidebar_visible sidebar_sort nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
endif

syn keyword muttrcVarQuad	skipwhite contained abort_nosubject abort_unmodified bounce copy nextgroup=muttrcSetQuadAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarQuad	skipwhite contained crypt_verify_sig delete fcc_attach forward_edit honor_followup_to nextgroup=muttrcSetQuadAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarQuad	skipwhite contained include mime_forward mime_forward_rest mime_fwd move nextgroup=muttrcSetQuadAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarQuad	skipwhite contained pgp_mime_auto pgp_verify_sig pop_delete pop_reconnect nextgroup=muttrcSetQuadAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarQuad	skipwhite contained postpone print quit recall reply_to ssl_starttls nextgroup=muttrcSetQuadAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

syn keyword muttrcVarQuad	skipwhite contained noabort_nosubject noabort_unmodified nobounce nocopy nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarQuad	skipwhite contained nocrypt_verify_sig nodelete nofcc_attach noforward_edit nohonor_followup_to nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarQuad	skipwhite contained noinclude nomime_forward nomime_forward_rest nomime_fwd nomove nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarQuad	skipwhite contained nopgp_mime_auto nopgp_verify_sig nopop_delete nopop_reconnect nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarQuad	skipwhite contained nopostpone noprint noquit norecall noreply_to nossl_starttls nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

syn keyword muttrcVarQuad	skipwhite contained invabort_nosubject invabort_unmodified invbounce invcopy nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarQuad	skipwhite contained invcrypt_verify_sig invdelete invfcc_attach invforward_edit invhonor_followup_to nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarQuad	skipwhite contained invinclude invmime_forward invmime_forward_rest invmime_fwd invmove nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarQuad	skipwhite contained invpgp_mime_auto invpgp_verify_sig invpop_delete invpop_reconnect nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarQuad	skipwhite contained invpostpone invprint invquit invrecall invreply_to invssl_starttls nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

syn keyword muttrcVarNum	skipwhite contained connect_timeout history imap_keepalive imap_pipeline_depth mail_check nextgroup=muttrcSetNumAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarNum	skipwhite contained menu_context net_inc pager_context pager_index_lines pgp_timeout nextgroup=muttrcSetNumAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarNum	skipwhite contained pop_checkinterval read_inc save_history score_threshold_delete nextgroup=muttrcSetNumAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarNum	skipwhite contained score_threshold_flag score_threshold_read search_context sendmail_wait sleep_time nextgroup=muttrcSetNumAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarNum	skipwhite contained smime_timeout ssl_min_dh_prime_bits timeout time_inc wrap wrapmargin nextgroup=muttrcSetNumAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarNum	skipwhite contained write_inc nextgroup=muttrcSetNumAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
if use_mutt_sidebar == 1
    syn keyword muttrcVarNum skipwhite contained sidebar_width nextgroup=muttrcSetNumAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
endif

syn match muttrcFormatErrors contained /%./

syn match muttrcStrftimeEscapes contained /%[AaBbCcDdeFGgHhIjklMmnpRrSsTtUuVvWwXxYyZz+%]/
syn match muttrcStrftimeEscapes contained /%E[cCxXyY]/
syn match muttrcStrftimeEscapes contained /%O[BdeHImMSuUVwWy]/

syn region muttrcIndexFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcIndexFormatEscapes,muttrcIndexFormatConditionals,muttrcFormatErrors,muttrcTimeEscapes nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcIndexFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcIndexFormatEscapes,muttrcIndexFormatConditionals,muttrcFormatErrors,muttrcTimeEscapes nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcQueryFormatStr contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcQueryFormatEscapes,muttrcQueryFormatConditionals,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcAliasFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcAliasFormatEscapes,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcAliasFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcAliasFormatEscapes,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcAttachFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcAttachFormatEscapes,muttrcAttachFormatConditionals,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcAttachFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcAttachFormatEscapes,muttrcAttachFormatConditionals,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcComposeFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcComposeFormatEscapes,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcComposeFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcComposeFormatEscapes,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcFolderFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcFolderFormatEscapes,muttrcFolderFormatConditionals,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcFolderFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcFolderFormatEscapes,muttrcFolderFormatConditionals,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcMixFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcMixFormatEscapes,muttrcMixFormatConditionals,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcMixFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcMixFormatEscapes,muttrcMixFormatConditionals,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcPGPFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcPGPFormatEscapes,muttrcPGPFormatConditionals,muttrcFormatErrors,muttrcPGPTimeEscapes nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcPGPFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcPGPFormatEscapes,muttrcPGPFormatConditionals,muttrcFormatErrors,muttrcPGPTimeEscapes nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcPGPCmdFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcPGPCmdFormatEscapes,muttrcPGPCmdFormatConditionals,muttrcVariable,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcPGPCmdFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcPGPCmdFormatEscapes,muttrcPGPCmdFormatConditionals,muttrcVariable,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcStatusFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcStatusFormatEscapes,muttrcStatusFormatConditionals,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcStatusFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcStatusFormatEscapes,muttrcStatusFormatConditionals,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcPGPGetKeysFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcPGPGetKeysFormatEscapes,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcPGPGetKeysFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcPGPGetKeysFormatEscapes,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcSmimeFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcSmimeFormatEscapes,muttrcSmimeFormatConditionals,muttrcVariable,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcSmimeFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcSmimeFormatEscapes,muttrcSmimeFormatConditionals,muttrcVariable,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcStrftimeFormatStr contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcStrftimeEscapes,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn region muttrcStrftimeFormatStr contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcStrftimeEscapes,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

" The following info was pulled from hdr_format_str in hdrline.c
syn match muttrcIndexFormatEscapes contained /%\%(\%(-\?[0-9]\+\)\?\%(\.[0-9]\+\)\?\)\?[:_]\?[aAbBcCdDeEfFHilLmMnNOPsStTuvXyYZ%]/
syn match muttrcIndexFormatEscapes contained /%[>|*]./
syn match muttrcIndexFormatConditionals contained /%?[EFHlLMNOXyY]?/ nextgroup=muttrcFormatConditionals2
" The following info was pulled from alias_format_str in addrbook.c
syn match muttrcAliasFormatEscapes contained /%\%(\%(-\?[0-9]\+\)\?\%(\.[0-9]\+\)\?\)\?[:_]\?[afnrt%]/
" The following info was pulled from query_format_str in query.c
syn match muttrcQueryFormatEscapes contained /%\%(\%(-\?[0-9]\+\)\?\%(\.[0-9]\+\)\?\)\?[:_]\?[acent%]/
syn match muttrcQueryFormatConditionals contained /%?[e]?/ nextgroup=muttrcFormatConditionals2
" The following info was pulled from mutt_attach_fmt in recvattach.c
syn match muttrcAttachFormatEscapes contained /%\%(\%(-\?[0-9]\+\)\?\%(\.[0-9]\+\)\?\)\?[:_]\?[CcDdefImMnQstTuX%]/
syn match muttrcAttachFormatEscapes contained /%[>|*]./
syn match muttrcAttachFormatConditionals contained /%?[CcdDefInmMQstTuX]?/ nextgroup=muttrcFormatConditionals2
syn match muttrcFormatConditionals2 contained /[^?]*?/
" The following info was pulled from compose_format_str in compose.c
syn match muttrcComposeFormatEscapes contained /%\%(\%(-\?[0-9]\+\)\?\%(\.[0-9]\+\)\?\)\?[:_]\?[ahlv%]/
syn match muttrcComposeFormatEscapes contained /%[>|*]./
" The following info was pulled from folder_format_str in browser.c
syn match muttrcFolderFormatEscapes contained /%\%(\%(-\?[0-9]\+\)\?\%(\.[0-9]\+\)\?\)\?[:_]\?[CDdfFglNstu%]/
syn match muttrcFolderFormatEscapes contained /%[>|*]./
syn match muttrcFolderFormatConditionals contained /%?[N]?/
" The following info was pulled from mix_entry_fmt in remailer.c
syn match muttrcMixFormatEscapes contained /%\%(\%(-\?[0-9]\+\)\?\%(\.[0-9]\+\)\?\)\?[:_]\?[ncsa%]/
syn match muttrcMixFormatConditionals contained /%?[ncsa]?/
" The following info was pulled from crypt_entry_fmt in crypt-gpgme.c 
" and pgp_entry_fmt in pgpkey.c (note that crypt_entry_fmt supports 
" 'p', but pgp_entry_fmt does not).
syn match muttrcPGPFormatEscapes contained /%\%(\%(-\?[0-9]\+\)\?\%(\.[0-9]\+\)\?\)\?[:_]\?[nkualfctp%]/
syn match muttrcPGPFormatConditionals contained /%?[nkualfct]?/
" The following info was pulled from _mutt_fmt_pgp_command in 
" pgpinvoke.c
syn match muttrcPGPCmdFormatEscapes contained /%\%(\%(-\?[0-9]\+\)\?\%(\.[0-9]\+\)\?\)\?[:_]\?[pfsar%]/
syn match muttrcPGPCmdFormatConditionals contained /%?[pfsar]?/ nextgroup=muttrcFormatConditionals2
" The following info was pulled from status_format_str in status.c
syn match muttrcStatusFormatEscapes contained /%\%(\%(-\?[0-9]\+\)\?\%(\.[0-9]\+\)\?\)\?[:_]\?[bdfFhlLmMnopPrsStuvV%]/
syn match muttrcStatusFormatEscapes contained /%[>|*]./
syn match muttrcStatusFormatConditionals contained /%?[bdFlLmMnoptuV]?/ nextgroup=muttrcFormatConditionals2
" This matches the documentation, but directly contradicts the code 
" (according to the code, this should be identical to the 
" muttrcPGPCmdFormatEscapes
syn match muttrcPGPGetKeysFormatEscapes contained /%\%(\%(-\?[0-9]\+\)\?\%(\.[0-9]\+\)\?\)\?[:_]\?[r%]/
" The following info was pulled from _mutt_fmt_smime_command in 
" smime.c
syn match muttrcSmimeFormatEscapes contained /%\%(\%(-\?[0-9]\+\)\?\%(\.[0-9]\+\)\?\)\?[:_]\?[Cciskaf%]/
syn match muttrcSmimeFormatConditionals contained /%?[Cciskaf]?/ nextgroup=muttrcFormatConditionals2

syn region muttrcTimeEscapes contained start=+%{+ end=+}+ contains=muttrcStrftimeEscapes
syn region muttrcTimeEscapes contained start=+%\[+ end=+\]+ contains=muttrcStrftimeEscapes
syn region muttrcTimeEscapes contained start=+%(+ end=+)+ contains=muttrcStrftimeEscapes
syn region muttrcTimeEscapes contained start=+%<+ end=+>+ contains=muttrcStrftimeEscapes
syn region muttrcPGPTimeEscapes contained start=+%\[+ end=+\]+ contains=muttrcStrftimeEscapes

syn keyword muttrcVarStr	contained skipwhite attribution index_format message_format pager_format nextgroup=muttrcVarEqualsIdxFmt
syn match muttrcVarEqualsIdxFmt contained skipwhite "=" nextgroup=muttrcIndexFormatStr
syn keyword muttrcVarStr	contained skipwhite alias_format nextgroup=muttrcVarEqualsAliasFmt
syn match muttrcVarEqualsAliasFmt contained skipwhite "=" nextgroup=muttrcAliasFormatStr
syn keyword muttrcVarStr	contained skipwhite attach_format nextgroup=muttrcVarEqualsAttachFmt
syn match muttrcVarEqualsAttachFmt contained skipwhite "=" nextgroup=muttrcAttachFormatStr
syn keyword muttrcVarStr	contained skipwhite compose_format nextgroup=muttrcVarEqualsComposeFmt
syn match muttrcVarEqualsComposeFmt contained skipwhite "=" nextgroup=muttrcComposeFormatStr
syn keyword muttrcVarStr	contained skipwhite folder_format nextgroup=muttrcVarEqualsFolderFmt
syn match muttrcVarEqualsFolderFmt contained skipwhite "=" nextgroup=muttrcFolderFormatStr
syn keyword muttrcVarStr	contained skipwhite mix_entry_format nextgroup=muttrcVarEqualsMixFmt
syn match muttrcVarEqualsMixFmt contained skipwhite "=" nextgroup=muttrcMixFormatStr
syn keyword muttrcVarStr	contained skipwhite pgp_entry_format nextgroup=muttrcVarEqualsPGPFmt
syn match muttrcVarEqualsPGPFmt contained skipwhite "=" nextgroup=muttrcPGPFormatStr
syn keyword muttrcVarStr	contained skipwhite query_format nextgroup=muttrcVarEqualsQueryFmt
syn match muttrcVarEqualsQueryFmt contained skipwhite "=" nextgroup=muttrcQueryFormatStr
syn keyword muttrcVarStr	contained skipwhite pgp_decode_command pgp_verify_command pgp_decrypt_command pgp_clearsign_command pgp_sign_command pgp_encrypt_sign_command pgp_encrypt_only_command pgp_import_command pgp_export_command pgp_verify_key_command pgp_list_secring_command pgp_list_pubring_command nextgroup=muttrcVarEqualsPGPCmdFmt
syn match muttrcVarEqualsPGPCmdFmt contained skipwhite "=" nextgroup=muttrcPGPCmdFormatStr
syn keyword muttrcVarStr	contained skipwhite status_format nextgroup=muttrcVarEqualsStatusFmt
syn match muttrcVarEqualsStatusFmt contained skipwhite "=" nextgroup=muttrcStatusFormatStr
syn keyword muttrcVarStr	contained skipwhite pgp_getkeys_command nextgroup=muttrcVarEqualsPGPGetKeysFmt
syn match muttrcVarEqualsPGPGetKeysFmt contained skipwhite "=" nextgroup=muttrcPGPGetKeysFormatStr
syn keyword muttrcVarStr	contained skipwhite smime_decrypt_command smime_verify_command smime_verify_opaque_command smime_sign_command smime_sign_opaque_command smime_encrypt_command smime_pk7out_command smime_get_cert_command smime_get_signer_cert_command smime_import_cert_command smime_get_cert_email_command nextgroup=muttrcVarEqualsSmimeFmt
syn match muttrcVarEqualsSmimeFmt contained skipwhite "=" nextgroup=muttrcSmimeFormatStr
syn keyword muttrcVarStr	contained skipwhite date_format nextgroup=muttrcVarEqualsStrftimeFmt
syn match muttrcVarEqualsStrftimeFmt contained skipwhite "=" nextgroup=muttrcStrftimeFormatStr

syn match muttrcVPrefix		contained /[?&]/ nextgroup=muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

syn match muttrcVarStr		contained skipwhite 'my_[a-zA-Z0-9_]\+' nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite alias_file assumed_charset attach_charset attach_sep nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite certificate_file charset config_charset content_type nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite default_hook display_filter dotlock_program dsn_notify nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite dsn_return editor entropy_file envelope_from_address escape folder nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite forw_format forward_format from gecos_mask hdr_format nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite header_cache header_cache_compress header_cache_pagesize nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite history_file hostname imap_authenticators nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite imap_delim_chars imap_headers imap_idle imap_login imap_pass nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite imap_user indent_str indent_string ispell locale mailcap_path nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite mask mbox mbox_type message_cachedir mh_seq_flagged mh_seq_replied nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite mh_seq_unseen mixmaster msg_format pager nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite pgp_good_sign  nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite pgp_mime_signature_filename nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite pgp_mime_signature_description pgp_sign_as nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite pgp_sort_keys nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite pipe_sep pop_authenticators pop_host pop_pass pop_user post_indent_str nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite post_indent_string postponed preconnect print_cmd print_command nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite query_command quote_regexp realname record reply_regexp send_charset nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite sendmail shell signature simple_search smileys smime_ca_location nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite smime_certificates smime_default_key nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite smime_encrypt_with nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite smime_keys smime_sign_as nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite smtp_url smtp_authenticators smtp_pass sort sort_alias sort_aux nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite sort_browser spam_separator spoolfile ssl_ca_certificates_file ssl_client_cert nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite status_chars tmpdir to_chars tunnel visual nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
if use_mutt_sidebar == 1
    syn keyword muttrcVarStr skipwhite contained sidebar_delim nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
endif

" Present in 1.4.2.1 (pgp_create_traditional was a bool then)
syn keyword muttrcVarBool	contained skipwhite imap_force_ssl noimap_force_ssl invimap_force_ssl nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
"syn keyword muttrcVarQuad	contained pgp_create_traditional nopgp_create_traditional invpgp_create_traditional
syn keyword muttrcVarStr	contained skipwhite alternates nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

syn keyword muttrcMenu		contained alias attach browser compose editor index pager postpone pgp mix query generic
syn match muttrcMenuList "\S\+" contained contains=muttrcMenu
syn match muttrcMenuCommas /,/ contained

syn keyword muttrcHooks		contained skipwhite account-hook charset-hook iconv-hook message-hook folder-hook mbox-hook save-hook fcc-hook fcc-save-hook send-hook send2-hook reply-hook crypt-hook

syn keyword muttrcCommand	auto_view alternative_order exec unalternative_order
syn keyword muttrcCommand	hdr_order iconv-hook ignore mailboxes my_hdr unmailboxes
syn keyword muttrcCommand	pgp-hook push score source unauto_view unhdr_order
syn keyword muttrcCommand	unignore unmono unmy_hdr unscore
syn keyword muttrcCommand	mime_lookup unmime_lookup ungroup
syn keyword muttrcCommand	unalternative_order
syn keyword muttrcCommand	skipwhite charset-hook nextgroup=muttrcRXString
syn keyword muttrcCommand	skipwhite unhook nextgroup=muttrcHooks

syn keyword muttrcCommand 	skipwhite spam nextgroup=muttrcSpamPattern
syn region muttrcSpamPattern	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcPattern nextgroup=muttrcString,muttrcStringNL
syn region muttrcSpamPattern	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcPattern nextgroup=muttrcString,muttrcStringNL

syn keyword muttrcCommand 	skipwhite nospam nextgroup=muttrcNoSpamPattern
syn region muttrcNoSpamPattern	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcPattern
syn region muttrcNoSpamPattern	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcPattern

syn match muttrcAttachmentsMimeType contained "[*a-z0-9_-]\+/[*a-z0-9._-]\+\s*" skipwhite nextgroup=muttrcAttachmentsMimeType
syn match muttrcAttachmentsFlag contained "[+-]\%([AI]\|inline\|attachment\)\s\+" skipwhite nextgroup=muttrcAttachmentsMimeType
syn match muttrcAttachmentsLine "^\s*\%(un\)\?attachments\s\+" skipwhite nextgroup=muttrcAttachmentsFlag

syn match muttrcUnHighlightSpace contained "\%(\s\+\|\\$\)"

syn keyword muttrcAsterisk	contained *
syn keyword muttrcListsKeyword	lists skipwhite nextgroup=muttrcGroupDef,muttrcComment
syn keyword muttrcListsKeyword	unlists skipwhite nextgroup=muttrcAsterisk,muttrcComment

syn keyword muttrcSubscribeKeyword	subscribe nextgroup=muttrcGroupDef,muttrcComment
syn keyword muttrcSubscribeKeyword	unsubscribe nextgroup=muttrcAsterisk,muttrcComment

syn keyword muttrcAlternateKeyword contained alternates unalternates
syn region muttrcAlternatesLine keepend start=+^\s*\%(un\)\?alternates\s+ skip=+\\$+ end=+$+ contains=muttrcAlternateKeyword,muttrcGroupDef,muttrcRXPat,muttrcUnHighlightSpace,muttrcComment

" muttrcVariable includes a prefix because partial strings are considered
" valid.
syn match muttrcVariable	contained "\\\@<![a-zA-Z_-]*\$[a-zA-Z_-]\+" contains=muttrcVariableInner
syn match muttrcVariableInner	contained "\$[a-zA-Z_-]\+"
syn match muttrcEscapedVariable	contained "\\\$[a-zA-Z_-]\+"

syn match muttrcBadAction	contained "[^<>]\+" contains=muttrcEmail
syn match muttrcFunction	contained "\<\%(attach\|bounce\|copy\|delete\|display\|flag\|forward\|parent\|pipe\|postpone\|print\|recall\|resend\|save\|send\|tag\|undelete\)-message\>"
syn match muttrcFunction	contained "\<\%(delete\|next\|previous\|read\|tag\|break\|undelete\)-thread\>"
syn match muttrcFunction	contained "\<link-threads\>"
syn match muttrcFunction	contained "\<\%(backward\|capitalize\|downcase\|forward\|kill\|upcase\)-word\>"
syn match muttrcFunction	contained "\<\%(delete\|filter\|first\|last\|next\|pipe\|previous\|print\|save\|select\|tag\|undelete\)-entry\>"
syn match muttrcFunction	contained "\<attach-\%(file\|key\)\>"
syn match muttrcFunction	contained "\<change-\%(dir\|folder\|folder-readonly\)\>"
syn match muttrcFunction	contained "\<check-\%(new\|traditional-pgp\)\>"
syn match muttrcFunction	contained "\<current-\%(bottom\|middle\|top\)\>"
syn match muttrcFunction	contained "\<decode-\%(copy\|save\)\>"
syn match muttrcFunction	contained "\<delete-\%(char\|pattern\|subthread\)\>"
syn match muttrcFunction	contained "\<display-\%(address\|toggle-weed\)\>"
syn match muttrcFunction	contained "\<edit\%(-\%(bcc\|cc\|description\|encoding\|fcc\|file\|from\|headers\|mime\|reply-to\|subject\|to\|type\)\)\?\>"
syn match muttrcFunction	contained "\<enter-\%(command\|mask\)\>"
syn match muttrcFunction	contained "\<half-\%(up\|down\)\>"
syn match muttrcFunction	contained "\<history-\%(up\|down\)\>"
syn match muttrcFunction	contained "\<kill-\%(eol\|eow\|line\)\>"
syn match muttrcFunction	contained "\<next-\%(line\|new\%(-then-unread\)\?\|page\|subthread\|undeleted\|unread\|unread-mailbox\)\>"
syn match muttrcFunction	contained "\<previous-\%(line\|new\%(-then-unread\)\?\|page\|subthread\|undeleted\|unread\)\>"
syn match muttrcFunction	contained "\<search\%(-\%(next\|opposite\|reverse\|toggle\)\)\?\>"
syn match muttrcFunction	contained "\<show-\%(limit\|version\)\>"
syn match muttrcFunction	contained "\<sort-\%(mailbox\|reverse\)\>"
syn match muttrcFunction	contained "\<tag-\%(pattern\|\%(sub\)\?thread\|prefix\%(-cond\)\?\)\>"
syn match muttrcFunction	contained "\<end-cond\>"
syn match muttrcFunction	contained "\<toggle-\%(mailboxes\|new\|quoted\|subscribed\|unlink\|write\)\>"
syn match muttrcFunction	contained "\<undelete-\%(pattern\|subthread\)\>"
syn match muttrcFunction	contained "\<collapse-\%(parts\|thread\|all\)\>"
syn match muttrcFunction	contained "\<view-\%(attach\|attachments\|file\|mailcap\|name\|text\)\>"
syn match muttrcFunction	contained "\<\%(backspace\|backward-char\|bol\|bottom\|bottom-page\|buffy-cycle\|clear-flag\|complete\%(-query\)\?\|copy-file\|create-alias\|detach-file\|eol\|exit\|extract-keys\|\%(imap-\)\?fetch-mail\|forget-passphrase\|forward-char\|group-reply\|help\|ispell\|jump\|limit\|list-reply\|mail\|mail-key\|mark-as-new\|middle-page\|new-mime\|noop\|pgp-menu\|query\|query-append\|quit\|quote-char\|read-subthread\|redraw-screen\|refresh\|rename-file\|reply\|select-new\|set-flag\|shell-escape\|skip-quoted\|sort\|subscribe\|sync-mailbox\|top\|top-page\|transpose-chars\|unsubscribe\|untag-pattern\|verify-key\|what-key\|write-fcc\)\>"
if use_mutt_sidebar == 1
    syn match muttrcFunction    contained "\<sidebar-\%(prev\|next\|open\|scroll-up\|scroll-down\)"
endif
syn match muttrcAction		contained "<[^>]\{-}>" contains=muttrcBadAction,muttrcFunction,muttrcKeyName

syn keyword muttrcCommand	set     skipwhite nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcCommand	unset   skipwhite nextgroup=muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcCommand	reset   skipwhite nextgroup=muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcCommand	toggle  skipwhite nextgroup=muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

" First, functions that take regular expressions:
syn match  muttrcRXHookNot	contained /!\s*/ skipwhite nextgroup=muttrcRXHookString,muttrcRXHookStringNL
syn match  muttrcRXHooks	/\<\%(account\|folder\)-hook\>/ skipwhite nextgroup=muttrcRXHookNot,muttrcRXHookString,muttrcRXHookStringNL

" Now, functions that take patterns
syn match muttrcPatHookNot	contained /!\s*/ skipwhite nextgroup=muttrcPattern
syn match muttrcPatHooks	/\<\%(mbox\|crypt\)-hook\>/ skipwhite nextgroup=muttrcPatHookNot,muttrcPattern
syn match muttrcPatHooks	/\<\%(message\|reply\|send\|send2\|save\|\|fcc\%(-save\)\?\)-hook\>/ skipwhite nextgroup=muttrcPatHookNot,muttrcOptPattern

syn match muttrcBindFunction	contained /\S\+\>/ skipwhite contains=muttrcFunction
syn match muttrcBindFunctionNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcBindFunction,muttrcBindFunctionNL
syn match muttrcBindKey		contained /\S\+/ skipwhite contains=muttrcKey nextgroup=muttrcBindFunction,muttrcBindFunctionNL
syn match muttrcBindKeyNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcBindKey,muttrcBindKeyNL
syn match muttrcBindMenuList	contained /\S\+/ skipwhite contains=muttrcMenu,muttrcMenuCommas nextgroup=muttrcBindKey,muttrcBindKeyNL
syn match muttrcBindMenuListNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcBindMenuList,muttrcBindMenuListNL
syn keyword muttrcCommand	skipwhite bind nextgroup=muttrcBindMenuList,muttrcBindMenuListNL

syn region muttrcMacroDescr	contained keepend skipwhite start=+\s*\S+ms=e skip=+\\ + end=+ \|$+me=s
syn region muttrcMacroDescr	contained keepend skipwhite start=+'+ms=e skip=+\\'+ end=+'+me=s
syn region muttrcMacroDescr	contained keepend skipwhite start=+"+ms=e skip=+\\"+ end=+"+me=s
syn match muttrcMacroDescrNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcMacroDescr,muttrcMacroDescrNL
syn region muttrcMacroBody	contained skipwhite start="\S" skip='\\ \|\\$' end=' \|$' contains=muttrcEscape,muttrcSet,muttrcUnset,muttrcReset,muttrcToggle,muttrcCommand,muttrcAction nextgroup=muttrcMacroDescr,muttrcMacroDescrNL
syn region muttrcMacroBody matchgroup=Type contained skipwhite start=+'+ms=e skip=+\\'+ end=+'\|\%(\%(\\\\\)\@<!$\)+me=s contains=muttrcEscape,muttrcSet,muttrcUnset,muttrcReset,muttrcToggle,muttrcSpam,muttrcNoSpam,muttrcCommand,muttrcAction,muttrcVariable nextgroup=muttrcMacroDescr,muttrcMacroDescrNL
syn region muttrcMacroBody matchgroup=Type contained skipwhite start=+"+ms=e skip=+\\"+ end=+"\|\%(\%(\\\\\)\@<!$\)+me=s contains=muttrcEscape,muttrcSet,muttrcUnset,muttrcReset,muttrcToggle,muttrcSpam,muttrcNoSpam,muttrcCommand,muttrcAction,muttrcVariable nextgroup=muttrcMacroDescr,muttrcMacroDescrNL
syn match muttrcMacroBodyNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcMacroBody,muttrcMacroBodyNL
syn match muttrcMacroKey	contained /\S\+/ skipwhite contains=muttrcKey nextgroup=muttrcMacroBody,muttrcMacroBodyNL
syn match muttrcMacroKeyNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcMacroKey,muttrcMacroKeyNL
syn match muttrcMacroMenuList	contained /\S\+/ skipwhite contains=muttrcMenu,muttrcMenuCommas nextgroup=muttrcMacroKey,muttrcMacroKeyNL
syn match muttrcMacroMenuListNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcMacroMenuList,muttrcMacroMenuListNL
syn keyword muttrcCommand	skipwhite macro	nextgroup=muttrcMacroMenuList,muttrcMacroMenuListNL

syn match muttrcAddrContent	contained "[a-zA-Z0-9._-]\+@[a-zA-Z0-9./-]\+\s*" skipwhite contains=muttrcEmail nextgroup=muttrcAddrContent
syn region muttrcAddrContent	contained start=+'+ end=+'\s*+ skip=+\\'+ skipwhite contains=muttrcEmail nextgroup=muttrcAddrContent
syn region muttrcAddrContent	contained start=+"+ end=+"\s*+ skip=+\\"+ skipwhite contains=muttrcEmail nextgroup=muttrcAddrContent
syn match muttrcAddrDef 	contained "-addr\s\+" skipwhite nextgroup=muttrcAddrContent

syn match muttrcGroupFlag	contained "-group"
syn region muttrcGroupDef	contained start="-group\s\+" skip="\\$" end="\s" skipwhite keepend contains=muttrcGroupFlag,muttrcUnHighlightSpace

syn keyword muttrcGroupKeyword	contained group ungroup
syn region muttrcGroupLine	keepend start=+^\s*\%(un\)\?group\s+ skip=+\\$+ end=+$+ contains=muttrcGroupKeyword,muttrcGroupDef,muttrcAddrDef,muttrcRXDef,muttrcUnHighlightSpace,muttrcComment

syn match muttrcAliasGroupName	contained /\w\+/ skipwhite nextgroup=muttrcAliasGroupDef,muttrcAliasKey,muttrcAliasNL
syn match muttrcAliasGroupDefNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcAliasGroupName,muttrcAliasGroupDefNL
syn match muttrcAliasGroupDef	contained /\s*-group/ skipwhite nextgroup=muttrcAliasGroupName,muttrcAliasGroupDefNL contains=muttrcGroupFlag
syn match muttrcAliasComma	contained /,/ skipwhite nextgroup=muttrcAliasEmail,muttrcAliasEncEmail,muttrcAliasNameNoParens,muttrcAliasENNL
syn match muttrcAliasEmail	contained /\S\+@\S\+/ contains=muttrcEmail nextgroup=muttrcAliasName,muttrcAliasNameNL skipwhite
syn match muttrcAliasEncEmail	contained /<[^>]\+>/ contains=muttrcEmail nextgroup=muttrcAliasComma
syn match muttrcAliasEncEmailNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcAliasEncEmail,muttrcAliasEncEmailNL
syn match muttrcAliasNameNoParens contained /[^<(@]\+\s\+/ nextgroup=muttrcAliasEncEmail,muttrcAliasEncEmailNL
syn region muttrcAliasName	contained matchgroup=Type start=/(/ end=/)/ skipwhite
syn match muttrcAliasNameNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcAliasName,muttrcAliasNameNL
syn match muttrcAliasENNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcAliasEmail,muttrcAliasEncEmail,muttrcAliasNameNoParens,muttrcAliasENNL
syn match muttrcAliasKey	contained /\s*[^- \t]\S\+/ skipwhite nextgroup=muttrcAliasEmail,muttrcAliasEncEmail,muttrcAliasNameNoParens,muttrcAliasENNL
syn match muttrcAliasNL		contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcAliasGroupDef,muttrcAliasKey,muttrcAliasNL
syn keyword muttrcCommand	skipwhite alias nextgroup=muttrcAliasGroupDef,muttrcAliasKey,muttrcAliasNL

syn match muttrcUnAliasKey	contained "\s*\w\+\s*" skipwhite nextgroup=muttrcUnAliasKey,muttrcUnAliasNL
syn match muttrcUnAliasNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcUnAliasKey,muttrcUnAliasNL
syn keyword muttrcCommand	skipwhite unalias nextgroup=muttrcUnAliasKey,muttrcUnAliasNL

syn match muttrcSimplePat contained "!\?\^\?[~][ADEFgGklNOpPQRSTuUvV=$]"
syn match muttrcSimplePat contained "!\?\^\?[~][mnXz]\s*\%([<>-][0-9]\+[kM]\?\|[0-9]\+[kM]\?[-]\%([0-9]\+[kM]\?\)\?\)"
syn match muttrcSimplePat contained "!\?\^\?[~][dr]\s*\%(\%(-\?[0-9]\{1,2}\%(/[0-9]\{1,2}\%(/[0-9]\{2}\%([0-9]\{2}\)\?\)\?\)\?\%([+*-][0-9]\+[ymwd]\)*\)\|\%(\%([0-9]\{1,2}\%(/[0-9]\{1,2}\%(/[0-9]\{2}\%([0-9]\{2}\)\?\)\?\)\?\%([+*-][0-9]\+[ymwd]\)*\)-\%([0-9]\{1,2}\%(/[0-9]\{1,2}\%(/[0-9]\{2}\%([0-9]\{2}\)\?\)\?\)\?\%([+*-][0-9]\+[ymwd]\)\?\)\?\)\|\%([<>=][0-9]\+[ymwd]\)\|\%(`[^`]\+`\)\|\%(\$[a-zA-Z0-9_-]\+\)\)" contains=muttrcShellString,muttrcVariable
syn match muttrcSimplePat contained "!\?\^\?[~][bBcCefhHiLstxy]\s*" nextgroup=muttrcSimplePatRXContainer
syn match muttrcSimplePat contained "!\?\^\?[%][bBcCefhHiLstxy]\s*" nextgroup=muttrcSimplePatString
syn match muttrcSimplePat contained "!\?\^\?[=][bcCefhHiLstxy]\s*" nextgroup=muttrcSimplePatString
syn region muttrcSimplePat contained keepend start=+!\?\^\?[~](+ end=+)+ contains=muttrcSimplePat
"syn match muttrcSimplePat contained /'[^~=%][^']*/ contains=muttrcRXString
syn region muttrcSimplePatString contained keepend start=+"+ end=+"+ skip=+\\"+
syn region muttrcSimplePatString contained keepend start=+'+ end=+'+ skip=+\\'+
syn region muttrcSimplePatString contained keepend start=+[^ 	"']+ skip=+\\ + end=+\s+re=e-1
syn region muttrcSimplePatRXContainer contained keepend start=+"+ end=+"+ skip=+\\"+ contains=muttrcRXString
syn region muttrcSimplePatRXContainer contained keepend start=+'+ end=+'+ skip=+\\'+ contains=muttrcRXString
syn region muttrcSimplePatRXContainer contained keepend start=+[^ 	"']+ skip=+\\ + end=+\s+re=e-1 contains=muttrcRXString
syn match muttrcSimplePatMetas contained /[(|)]/

syn match muttrcOptSimplePat contained skipwhite /[~=%!(^].*/ contains=muttrcSimplePat,muttrcSimplePatMetas
syn match muttrcOptSimplePat contained skipwhite /[^~=%!(^].*/ contains=muttrcRXString
syn region muttrcOptPattern contained matchgroup=Type keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcOptSimplePat,muttrcUnHighlightSpace nextgroup=muttrcString,muttrcStringNL
syn region muttrcOptPattern contained matchgroup=Type keepend skipwhite start=+'+ skip=+\\'+ end=+'+ contains=muttrcOptSimplePat,muttrcUnHighlightSpace nextgroup=muttrcString,muttrcStringNL
syn region muttrcOptPattern contained keepend skipwhite start=+[~](+ end=+)+ skip=+\\)+ contains=muttrcSimplePat nextgroup=muttrcString,muttrcStringNL
syn match muttrcOptPattern contained skipwhite /[~][A-Za-z]/ contains=muttrcSimplePat nextgroup=muttrcString,muttrcStringNL
syn match muttrcOptPattern contained skipwhite /[.]/ nextgroup=muttrcString,muttrcStringNL
" Keep muttrcPattern and muttrcOptPattern synchronized
syn region muttrcPattern contained matchgroup=Type keepend skipwhite start=+"+ skip=+\\"+ end=+"+ contains=muttrcSimplePat,muttrcUnHighlightSpace,muttrcSimplePatMetas
syn region muttrcPattern contained matchgroup=Type keepend skipwhite start=+'+ skip=+\\'+ end=+'+ contains=muttrcSimplePat,muttrcUnHighlightSpace,muttrcSimplePatMetas
syn region muttrcPattern contained keepend skipwhite start=+[~](+ end=+)+ skip=+\\)+ contains=muttrcSimplePat
syn match muttrcPattern contained skipwhite /[~][A-Za-z]/ contains=muttrcSimplePat
syn match muttrcPattern contained skipwhite /[.]/
syn region muttrcPatternInner contained keepend start=+"[~=%!(^]+ms=s+1 skip=+\\"+ end=+"+me=e-1 contains=muttrcSimplePat,muttrcUnHighlightSpace,muttrcSimplePatMetas
syn region muttrcPatternInner contained keepend start=+'[~=%!(^]+ms=s+1 skip=+\\'+ end=+'+me=e-1 contains=muttrcSimplePat,muttrcUnHighlightSpace,muttrcSimplePatMetas

" Colour definitions takes object, foreground and background arguments (regexps excluded).
syn match muttrcColorMatchCount	contained "[0-9]\+"
syn match muttrcColorMatchCountNL contained skipwhite skipnl "\s*\\$" nextgroup=muttrcColorMatchCount,muttrcColorMatchCountNL
syn region muttrcColorRXPat	contained start=+\s*'+ skip=+\\'+ end=+'\s*+ keepend skipwhite contains=muttrcRXString2 nextgroup=muttrcColorMatchCount,muttrcColorMatchCountNL
syn region muttrcColorRXPat	contained start=+\s*"+ skip=+\\"+ end=+"\s*+ keepend skipwhite contains=muttrcRXString2 nextgroup=muttrcColorMatchCount,muttrcColorMatchCountNL
syn keyword muttrcColorField	contained attachment body bold error hdrdefault header index indicator markers message normal quoted search signature status tilde tree underline
syn match   muttrcColorField	contained "\<quoted\d\=\>"
if use_mutt_sidebar == 1
    syn keyword muttrcColorField contained sidebar_new
endif
syn keyword muttrcColor	contained black blue cyan default green magenta red white yellow
syn keyword muttrcColor	contained brightblack brightblue brightcyan brightdefault brightgreen brightmagenta brightred brightwhite brightyellow
syn match   muttrcColor	contained "\<\%(bright\)\=color\d\{1,3}\>"
" Now for the structure of the color line
syn match muttrcColorRXNL	contained skipnl "\s*\\$" nextgroup=muttrcColorRXPat,muttrcColorRXNL
syn match muttrcColorBG 	contained /\s*[$]\?\w\+/ contains=muttrcColor,muttrcVariable,muttrcUnHighlightSpace nextgroup=muttrcColorRXPat,muttrcColorRXNL
syn match muttrcColorBGNL	contained skipnl "\s*\\$" nextgroup=muttrcColorBG,muttrcColorBGNL
syn match muttrcColorFG 	contained /\s*[$]\?\w\+/ contains=muttrcColor,muttrcVariable,muttrcUnHighlightSpace nextgroup=muttrcColorBG,muttrcColorBGNL
syn match muttrcColorFGNL	contained skipnl "\s*\\$" nextgroup=muttrcColorFG,muttrcColorFGNL
syn match muttrcColorContext 	contained /\s*[$]\?\w\+/ contains=muttrcColorField,muttrcVariable,muttrcUnHighlightSpace nextgroup=muttrcColorFG,muttrcColorFGNL
syn match muttrcColorNL 	contained skipnl "\s*\\$" nextgroup=muttrcColorContext,muttrcColorNL
syn match muttrcColorKeyword	contained /^\s*color\s\+/ nextgroup=muttrcColorContext,muttrcColorNL
syn region muttrcColorLine keepend start=/^\s*color\s\+\%(index\|header\)\@!/ skip=+\\$+ end=+$+ contains=muttrcColorKeyword,muttrcComment,muttrcUnHighlightSpace
" Now for the structure of the color index line
syn match muttrcPatternNL	contained skipnl "\s*\\$" nextgroup=muttrcPattern,muttrcPatternNL
syn match muttrcColorBGI	contained /\s*[$]\?\w\+\s*/ contains=muttrcColor,muttrcVariable,muttrcUnHighlightSpace nextgroup=muttrcPattern,muttrcPatternNL
syn match muttrcColorBGNLI	contained skipnl "\s*\\$" nextgroup=muttrcColorBGI,muttrcColorBGNLI
syn match muttrcColorFGI	contained /\s*[$]\?\w\+/ contains=muttrcColor,muttrcVariable,muttrcUnHighlightSpace nextgroup=muttrcColorBGI,muttrcColorBGNLI
syn match muttrcColorFGNLI	contained skipnl "\s*\\$" nextgroup=muttrcColorFGI,muttrcColorFGNLI
syn match muttrcColorContextI	contained /\s*\<index\>/ contains=muttrcUnHighlightSpace nextgroup=muttrcColorFGI,muttrcColorFGNLI
syn match muttrcColorNLI	contained skipnl "\s*\\$" nextgroup=muttrcColorContextI,muttrcColorNLI
syn match muttrcColorKeywordI	contained skipwhite /\<color\>/ nextgroup=muttrcColorContextI,muttrcColorNLI
syn region muttrcColorLine keepend skipwhite start=/\<color\s\+index\>/ skip=+\\$+ end=+$+ contains=muttrcColorKeywordI,muttrcComment,muttrcUnHighlightSpace
" Now for the structure of the color header line
syn match muttrcRXPatternNL	contained skipnl "\s*\\$" nextgroup=muttrcRXString,muttrcRXPatternNL
syn match muttrcColorBGH	contained /\s*[$]\?\w\+\s*/ contains=muttrcColor,muttrcVariable,muttrcUnHighlightSpace nextgroup=muttrcRXString,muttrcRXPatternNL
syn match muttrcColorBGNLH	contained skipnl "\s*\\$" nextgroup=muttrcColorBGH,muttrcColorBGNLH
syn match muttrcColorFGH	contained /\s*[$]\?\w\+/ contains=muttrcColor,muttrcVariable,muttrcUnHighlightSpace nextgroup=muttrcColorBGH,muttrcColorBGNLH
syn match muttrcColorFGNLH	contained skipnl "\s*\\$" nextgroup=muttrcColorFGH,muttrcColorFGNLH
syn match muttrcColorContextH	contained /\s*\<header\>/ contains=muttrcUnHighlightSpace nextgroup=muttrcColorFGH,muttrcColorFGNLH
syn match muttrcColorNLH	contained skipnl "\s*\\$" nextgroup=muttrcColorContextH,muttrcColorNLH
syn match muttrcColorKeywordH	contained skipwhite /\<color\>/ nextgroup=muttrcColorContextH,muttrcColorNLH
syn region muttrcColorLine keepend skipwhite start=/\<color\s\+header\>/ skip=+\\$+ end=+$+ contains=muttrcColorKeywordH,muttrcComment,muttrcUnHighlightSpace
" And now color's brother:
syn region muttrcUnColorPatterns contained skipwhite start=+\s*'+ end=+'+ skip=+\\'+ contains=muttrcPattern nextgroup=muttrcUnColorPatterns,muttrcUnColorPatNL
syn region muttrcUnColorPatterns contained skipwhite start=+\s*"+ end=+"+ skip=+\\"+ contains=muttrcPattern nextgroup=muttrcUnColorPatterns,muttrcUnColorPatNL
syn match muttrcUnColorPatterns contained skipwhite /\s*[^'"\s]\S\*/ contains=muttrcPattern nextgroup=muttrcUnColorPatterns,muttrcUnColorPatNL
syn match muttrcUnColorPatNL	contained skipwhite skipnl /\s*\\$/ nextgroup=muttrcUnColorPatterns,muttrcUnColorPatNL
syn match muttrcUnColorAll	contained skipwhite /[*]/
syn match muttrcUnColorAPNL	contained skipwhite skipnl /\s*\\$/ nextgroup=muttrcUnColorPatterns,muttrcUnColorAll,muttrcUnColorAPNL
syn match muttrcUnColorIndex	contained skipwhite /\s*index\s\+/ nextgroup=muttrcUnColorPatterns,muttrcUnColorAll,muttrcUnColorAPNL
syn match muttrcUnColorIndexNL	contained skipwhite skipnl /\s*\\$/ nextgroup=muttrcUnColorIndex,muttrcUnColorIndexNL
syn match muttrcUnColorKeyword	contained skipwhite /^\s*uncolor\s\+/ nextgroup=muttrcUnColorIndex,muttrcUnColorIndexNL
syn region muttrcUnColorLine keepend start=+^\s*uncolor\s+ skip=+\\$+ end=+$+ contains=muttrcUnColorKeyword,muttrcComment,muttrcUnHighlightSpace

" Mono are almost like color (ojects inherited from color)
syn keyword muttrcMonoAttrib	contained bold none normal reverse standout underline
syn keyword muttrcMono		contained mono		skipwhite nextgroup=muttrcColorField
syn match   muttrcMonoLine	"^\s*mono\s\+\S\+"	skipwhite nextgroup=muttrcMonoAttrib contains=muttrcMono

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_muttrc_syntax_inits")
  if version < 508
    let did_muttrc_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink muttrcComment		Comment
  HiLink muttrcEscape		SpecialChar
  HiLink muttrcRXChars		SpecialChar
  HiLink muttrcString		String
  HiLink muttrcRXString		String
  HiLink muttrcRXString2	String
  HiLink muttrcSpecial		Special
  HiLink muttrcHooks		Type
  HiLink muttrcGroupFlag	Type
  HiLink muttrcGroupDef		Macro
  HiLink muttrcAddrDef		muttrcGroupFlag
  HiLink muttrcRXDef		muttrcGroupFlag
  HiLink muttrcRXPat		String
  HiLink muttrcAliasGroupName	Macro
  HiLink muttrcAliasKey	        Identifier
  HiLink muttrcUnAliasKey	Identifier
  HiLink muttrcAliasEncEmail	Identifier
  HiLink muttrcAliasParens	Type
  HiLink muttrcSetNumAssignment	Number
  HiLink muttrcSetBoolAssignment	Boolean
  HiLink muttrcSetQuadAssignment	Boolean
  HiLink muttrcSetStrAssignment	String
  HiLink muttrcEmail		Special
  HiLink muttrcVariableInner	Special
  HiLink muttrcEscapedVariable	String
  HiLink muttrcHeader		Type
  HiLink muttrcKeySpecial	SpecialChar
  HiLink muttrcKey		Type
  HiLink muttrcKeyName		SpecialChar
  HiLink muttrcVarBool		Identifier
  HiLink muttrcVarQuad		Identifier
  HiLink muttrcVarNum		Identifier
  HiLink muttrcVarStr		Identifier
  HiLink muttrcMenu		Identifier
  HiLink muttrcCommand		Keyword
  HiLink muttrcMacroDescr	String
  HiLink muttrcAction		Macro
  HiLink muttrcBadAction	Error
  HiLink muttrcBindFunction	Error
  HiLink muttrcBindMenuList	Error
  HiLink muttrcFunction		Macro
  HiLink muttrcGroupKeyword	muttrcCommand
  HiLink muttrcGroupLine	Error
  HiLink muttrcSubscribeKeyword	muttrcCommand
  HiLink muttrcSubscribeLine	Error
  HiLink muttrcListsKeyword	muttrcCommand
  HiLink muttrcListsLine	Error
  HiLink muttrcAlternateKeyword	muttrcCommand
  HiLink muttrcAlternatesLine	Error
  HiLink muttrcAttachmentsLine	muttrcCommand
  HiLink muttrcAttachmentsFlag	Type
  HiLink muttrcAttachmentsMimeType	String
  HiLink muttrcColorLine	Error
  HiLink muttrcColorContext	Error
  HiLink muttrcColorContextI	Identifier
  HiLink muttrcColorContextH	Identifier
  HiLink muttrcColorKeyword	muttrcCommand
  HiLink muttrcColorKeywordI	muttrcColorKeyword
  HiLink muttrcColorKeywordH	muttrcColorKeyword
  HiLink muttrcColorField	Identifier
  HiLink muttrcColor		Type
  HiLink muttrcColorFG		Error
  HiLink muttrcColorFGI		Error
  HiLink muttrcColorFGH		Error
  HiLink muttrcColorBG		Error
  HiLink muttrcColorBGI		Error
  HiLink muttrcColorBGH		Error
  HiLink muttrcMonoAttrib	muttrcColor
  HiLink muttrcMono		muttrcCommand
  HiLink muttrcSimplePat	Identifier
  HiLink muttrcSimplePatString	Macro
  HiLink muttrcSimplePatMetas	Special
  HiLink muttrcPattern		Error
  HiLink muttrcUnColorLine	Error
  HiLink muttrcUnColorKeyword	muttrcCommand
  HiLink muttrcUnColorIndex	Identifier
  HiLink muttrcShellString	muttrcEscape
  HiLink muttrcRXHooks		muttrcCommand
  HiLink muttrcRXHookNot	Type
  HiLink muttrcPatHooks		muttrcCommand
  HiLink muttrcPatHookNot	Type
  HiLink muttrcFormatConditionals2 Type
  HiLink muttrcIndexFormatStr	muttrcString
  HiLink muttrcIndexFormatEscapes muttrcEscape
  HiLink muttrcIndexFormatConditionals muttrcFormatConditionals2
  HiLink muttrcAliasFormatStr	muttrcString
  HiLink muttrcAliasFormatEscapes muttrcEscape
  HiLink muttrcAttachFormatStr	muttrcString
  HiLink muttrcAttachFormatEscapes muttrcEscape
  HiLink muttrcAttachFormatConditionals muttrcFormatConditionals2
  HiLink muttrcComposeFormatStr	muttrcString
  HiLink muttrcComposeFormatEscapes muttrcEscape
  HiLink muttrcFolderFormatStr	muttrcString
  HiLink muttrcFolderFormatEscapes muttrcEscape
  HiLink muttrcFolderFormatConditionals muttrcFormatConditionals2
  HiLink muttrcMixFormatStr	muttrcString
  HiLink muttrcMixFormatEscapes muttrcEscape
  HiLink muttrcMixFormatConditionals muttrcFormatConditionals2
  HiLink muttrcPGPFormatStr	muttrcString
  HiLink muttrcPGPFormatEscapes muttrcEscape
  HiLink muttrcPGPFormatConditionals muttrcFormatConditionals2
  HiLink muttrcPGPCmdFormatStr	muttrcString
  HiLink muttrcPGPCmdFormatEscapes muttrcEscape
  HiLink muttrcPGPCmdFormatConditionals muttrcFormatConditionals2
  HiLink muttrcStatusFormatStr	muttrcString
  HiLink muttrcStatusFormatEscapes muttrcEscape
  HiLink muttrcStatusFormatConditionals muttrcFormatConditionals2
  HiLink muttrcPGPGetKeysFormatStr	muttrcString
  HiLink muttrcPGPGetKeysFormatEscapes muttrcEscape
  HiLink muttrcSmimeFormatStr	muttrcString
  HiLink muttrcSmimeFormatEscapes muttrcEscape
  HiLink muttrcSmimeFormatConditionals muttrcFormatConditionals2
  HiLink muttrcTimeEscapes	muttrcEscape
  HiLink muttrcPGPTimeEscapes	muttrcEscape
  HiLink muttrcStrftimeEscapes	Type
  HiLink muttrcStrftimeFormatStr muttrcString
  HiLink muttrcFormatErrors Error

  HiLink muttrcBindFunctionNL	SpecialChar
  HiLink muttrcBindKeyNL	SpecialChar
  HiLink muttrcBindMenuListNL	SpecialChar
  HiLink muttrcMacroDescrNL	SpecialChar
  HiLink muttrcMacroBodyNL	SpecialChar
  HiLink muttrcMacroKeyNL	SpecialChar
  HiLink muttrcMacroMenuListNL	SpecialChar
  HiLink muttrcColorMatchCountNL SpecialChar
  HiLink muttrcColorNL		SpecialChar
  HiLink muttrcColorRXNL	SpecialChar
  HiLink muttrcColorBGNL	SpecialChar
  HiLink muttrcColorFGNL	SpecialChar
  HiLink muttrcAliasNameNL	SpecialChar
  HiLink muttrcAliasENNL	SpecialChar
  HiLink muttrcAliasNL		SpecialChar
  HiLink muttrcUnAliasNL	SpecialChar
  HiLink muttrcAliasGroupDefNL	SpecialChar
  HiLink muttrcAliasEncEmailNL	SpecialChar
  HiLink muttrcPatternNL	SpecialChar
  HiLink muttrcUnColorPatNL	SpecialChar
  HiLink muttrcUnColorAPNL	SpecialChar
  HiLink muttrcUnColorIndexNL	SpecialChar
  HiLink muttrcStringNL		SpecialChar

  delcommand HiLink
endif

let b:current_syntax = "muttrc"

let &cpo = s:cpo_save
unlet s:cpo_save
"EOF	vim: ts=8 noet tw=100 sw=8 sts=0 ft=vim
