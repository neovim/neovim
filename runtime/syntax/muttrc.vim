" Vim syntax file
" Language:	Mutt setup files
" Original:	Preben 'Peppe' Guldberg <peppe-vim@wielders.org>
" Maintainer:	Luna Celeste <luna@unixpoet.dev>
" Last Change:	14 Aug 2023

" This file covers mutt version 2.2.10

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Set the keyword characters
setlocal isk=@,48-57,_,-

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
syn match muttrcHeader		"\<\c\%(From\|To\|C[Cc]\|B[Cc][Cc]\|Reply-To\|Subject\|Return-Path\|Received\|Date\|Replied\|Attach\)\>:\="

syn match   muttrcKeySpecial	contained +\%(\\[Cc'"]\|\^\|\\[01]\d\{2}\)+
syn match   muttrcKey		contained "\S\+"			contains=muttrcKeySpecial,muttrcKeyName
syn region  muttrcKey		contained start=+"+ skip=+\\\\\|\\"+ end=+"+	contains=muttrcKeySpecial,muttrcKeyName
syn region  muttrcKey		contained start=+'+ skip=+\\\\\|\\'+ end=+'+	contains=muttrcKeySpecial,muttrcKeyName
syn match   muttrcKeyName	contained "\<f\%(\d\|10\)\>"
syn match   muttrcKeyName	contained "\\[trne]"
syn match   muttrcKeyName	contained "\c<\%(BackSpace\|BackTab\|Delete\|Down\|End\|Enter\|Esc\|Home\|Insert\|Left\|PageDown\|PageUp\|Return\|Right\|Space\|Tab\|Up\)>"
syn match   muttrcKeyName	contained "<F[0-9]\+>"

syn keyword muttrcVarBool	skipwhite contained 
			\ allow_8bit allow_ansi arrow_cursor ascii_chars askbcc askcc attach_split
			\ auto_tag autoedit auto_subscribe background_edit background_confirm_quit beep beep_new
			\ bounce_delivered braille_friendly browser_abbreviate_mailboxes browser_sticky_cursor
			\ change_folder_next check_mbox_size check_new collapse_unread compose_confirm_detach_first
			\ confirmappend confirmcreate copy_decode_weed count_alternatives crypt_autoencrypt crypt_autopgp
			\ crypt_autosign crypt_autosmime crypt_confirmhook crypt_protected_headers_read
			\ crypt_protected_headers_save crypt_protected_headers_write crypt_opportunistic_encrypt
			\ crypt_opportunistic_encrypt_strong_keys crypt_replyencrypt crypt_replysign
			\ crypt_replysignencrypted crypt_timestamp crypt_use_gpgme crypt_use_pka cursor_overlay
			\ delete_untag digest_collapse duplicate_threads edit_hdrs edit_headers encode_from
			\ envelope_from fast_reply fcc_before_send fcc_clear flag_safe followup_to force_name forw_decode
			\ forw_decrypt forw_quote forward_decode forward_quote hdrs header
			\ header_color_partial help hidden_host hide_limited hide_missing hide_thread_subject
			\ hide_top_limited hide_top_missing history_remove_dups honor_disposition idn_decode idn_encode
			\ ignore_linear_white_space ignore_list_reply_to imap_check_subscribed imap_condstore imap_deflate
			\ imap_list_subscribed imap_passive imap_peek imap_qresync imap_servernoise
			\ implicit_autoview include_encrypted include_onlyfirst keep_flagged local_date_header
			\ mail_check_recent mail_check_stats mailcap_sanitize maildir_check_cur
			\ maildir_header_cache_verify maildir_trash mark_old markers menu_move_off
			\ menu_scroll message_cache_clean meta_key metoo mh_purge mime_forward_decode
			\ mime_type_query_first muttlisp_inline_eval narrow_tree pager_stop pgp_auto_decode
			\ pgp_auto_traditional pgp_autoencrypt pgp_autoinline pgp_autosign
			\ pgp_check_exit pgp_check_gpg_decrypt_status_fd pgp_create_traditional
			\ pgp_ignore_subkeys pgp_long_ids pgp_replyencrypt pgp_replyinline
			\ pgp_replysign pgp_replysignencrypted pgp_retainable_sigs pgp_self_encrypt
			\ pgp_self_encrypt_as pgp_show_unusable pgp_strict_enc pgp_use_gpg_agent
			\ pipe_decode pipe_decode_weed pipe_split pop_auth_try_all pop_last postpone_encrypt
			\ postpone_encrypt_as print_decode print_decode_weed print_split prompt_after read_only
			\ reflow_space_quotes reflow_text reflow_wrap reply_self resolve
			\ resume_draft_files resume_edited_draft_files reverse_alias reverse_name
			\ reverse_realname rfc2047_parameters save_address save_empty save_name score
			\ sidebar_folder_indent sidebar_new_mail_only sidebar_next_new_wrap
			\ sidebar_relative_shortpath_indent sidebar_short_path sidebar_sort sidebar_use_mailbox_shortcuts
			\ sidebar_visible sig_on_top sig_dashes size_show_bytes size_show_fraction size_show_mb
			\ size_units_on_left smart_wrap smime_ask_cert_label smime_decrypt_use_default_key
			\ smime_is_default smime_self_encrypt smime_self_encrypt_as sort_re
			\ ssl_force_tls ssl_use_sslv2 ssl_use_sslv3 ssl_use_tlsv1 ssl_use_tlsv1_3 ssl_usesystemcerts
			\ ssl_verify_dates ssl_verify_host ssl_verify_partial_chains status_on_top
			\ strict_mime strict_threads suspend text_flowed thorough_search
			\ thread_received tilde ts_enabled tunnel_is_secure uncollapse_jump use_8bitmime use_domain
			\ use_envelope_from use_from use_idn use_ipv6 uncollapse_new user_agent
			\ wait_key weed wrap_search write_bcc
			\ nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

syn keyword muttrcVarBool	skipwhite contained 
			\ noallow_8bit noallow_ansi noarrow_cursor noascii_chars noaskbcc noaskcc
			\ noattach_split noauto_tag noautoedit noauto_subscribe nobackground_edit
			\ nobackground_confirm_quit nobeep nobeep_new nobounce_delivered
			\ nobraille_friendly nobrowser_abbreviate_mailboxes nobrowser_sticky_cursor nochange_folder_next
			\ nocheck_mbox_size nocheck_new nocompose_confirm_detach_first nocollapse_unread noconfirmappend
			\ noconfirmcreate nocopy_decode_weed nocount_alternatives nocrypt_autoencrypt nocrypt_autopgp
			\ nocrypt_autosign nocrypt_autosmime nocrypt_confirmhook nocrypt_protected_headers_read
			\ nocrypt_protected_headers_save nocrypt_protected_headers_write nocrypt_opportunistic_encrypt
			\ nocrypt_opportunistic_encrypt_strong_keys nocrypt_replyencrypt nocrypt_replysign
			\ nocrypt_replysignencrypted nocrypt_timestamp nocrypt_use_gpgme nocrypt_use_pka nocursor_overlay
			\ nodelete_untag nodigest_collapse noduplicate_threads noedit_hdrs noedit_headers
			\ noencode_from noenvelope_from nofast_reply nofcc_before_send nofcc_clear noflag_safe
			\ nofollowup_to noforce_name noforw_decode noforw_decrypt noforw_quote
			\ noforward_decode noforward_quote nohdrs noheader
			\ noheader_color_partial nohelp nohidden_host nohide_limited nohide_missing
			\ nohide_thread_subject nohide_top_limited nohide_top_missing
			\ nohistory_remove_dups nohonor_disposition noidn_decode noidn_encode
			\ noignore_linear_white_space noignore_list_reply_to noimap_check_subscribed
			\ noimap_condstore noimap_deflate noimap_list_subscribed noimap_passive noimap_peek
			\ noimap_qresync noimap_servernoise noimplicit_autoview noinclude_encrypted noinclude_onlyfirst
			\ nokeep_flagged nolocal_date_header nomail_check_recent nomail_check_stats nomailcap_sanitize
			\ nomaildir_check_cur nomaildir_header_cache_verify nomaildir_trash nomark_old
			\ nomarkers nomenu_move_off nomenu_scroll nomessage_cache_clean nometa_key
			\ nometoo nomh_purge nomime_forward_decode nomime_type_query_first nomuttlisp_inline_eval
			\ nonarrow_tree nopager_stop nopgp_auto_decode nopgp_auto_traditional nopgp_autoencrypt
			\ nopgp_autoinline nopgp_autosign nopgp_check_exit
			\ nopgp_check_gpg_decrypt_status_fd nopgp_create_traditional
			\ nopgp_ignore_subkeys nopgp_long_ids nopgp_replyencrypt nopgp_replyinline
			\ nopgp_replysign nopgp_replysignencrypted nopgp_retainable_sigs
			\ nopgp_self_encrypt nopgp_self_encrypt_as nopgp_show_unusable
			\ nopgp_strict_enc nopgp_use_gpg_agent nopipe_decode nopipe_decode_weed nopipe_split
			\ nopop_auth_try_all nopop_last nopostpone_encrypt nopostpone_encrypt_as
			\ noprint_decode noprint_decode_weed noprint_split noprompt_after noread_only
			\ noreflow_space_quotes noreflow_text noreflow_wrap noreply_self noresolve
			\ noresume_draft_files noresume_edited_draft_files noreverse_alias
			\ noreverse_name noreverse_realname norfc2047_parameters nosave_address
			\ nosave_empty nosave_name noscore nosidebar_folder_indent
			\ nosidebar_new_mail_only nosidebar_next_new_wrap nosidebar_relative_shortpath_indent
			\ nosidebar_short_path nosidebar_sort nosidebar_visible nosidebar_use_mailbox_shortcuts
			\ nosig_dashes nosig_on_top nosize_show_bytes nosize_show_fraction nosize_show_mb
			\ nosize_units_on_left nosmart_wrap nosmime_ask_cert_label nosmime_decrypt_use_default_key
			\ nosmime_is_default nosmime_self_encrypt nosmime_self_encrypt_as nosort_re nossl_force_tls
			\ nossl_use_sslv2 nossl_use_sslv3 nossl_use_tlsv1 nossl_use_tlsv1_3 nossl_usesystemcerts
			\ nossl_verify_dates nossl_verify_host nossl_verify_partial_chains
			\ nostatus_on_top nostrict_mime nostrict_threads nosuspend notext_flowed
			\ nothorough_search nothread_received notilde nots_enabled notunnel_is_secure nouncollapse_jump
			\ nouse_8bitmime nouse_domain nouse_envelope_from nouse_from nouse_idn
			\ nouse_ipv6 nouncollapse_new nouser_agent nowait_key noweed nowrap_search
			\ nowrite_bcc
			\ nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

syn keyword muttrcVarBool	skipwhite contained
			\ invallow_8bit invallow_ansi invarrow_cursor invascii_chars invaskbcc
			\ invaskcc invattach_split invauto_tag invautoedit invauto_subscribe nobackground_edit
			\ nobackground_confirm_quit invbeep invbeep_new invbounce_delivered invbraille_friendly
			\ invbrowser_abbreviate_mailboxes invbrowser_sticky_cursor invchange_folder_next
			\ invcheck_mbox_size invcheck_new invcollapse_unread invcompose_confirm_detach_first
			\ invconfirmappend invcopy_decode_weed invconfirmcreate invcount_alternatives invcrypt_autopgp
			\ invcrypt_autoencrypt invcrypt_autosign invcrypt_autosmime invcrypt_confirmhook
			\ invcrypt_protected_headers_read invcrypt_protected_headers_save invcrypt_protected_headers_write
			\ invcrypt_opportunistic_encrypt invcrypt_opportunistic_encrypt_strong_keys invcrypt_replysign
			\ invcrypt_replyencrypt invcrypt_replysignencrypted invcrypt_timestamp invcrypt_use_gpgme
			\ invcrypt_use_pka invcursor_overlay invdelete_untag invdigest_collapse invduplicate_threads
			\ invedit_hdrs invedit_headers invencode_from invenvelope_from invfast_reply
			\ invfcc_before_send invfcc_clear invflag_safe invfollowup_to invforce_name invforw_decode
			\ invforw_decrypt invforw_quote invforward_decode
			\ invforward_quote invhdrs invheader invheader_color_partial invhelp
			\ invhidden_host invhide_limited invhide_missing invhide_thread_subject
			\ invhide_top_limited invhide_top_missing invhistory_remove_dups
			\ invhonor_disposition invidn_decode invidn_encode
			\ invignore_linear_white_space invignore_list_reply_to
			\ invimap_check_subscribed invimap_condstore invimap_deflate invimap_list_subscribed
			\ invimap_passive invimap_peek invimap_qresync invimap_servernoise invimplicit_autoview
			\ invinclude_encrypted invinclude_onlyfirst invkeep_flagged invlocal_date_header
			\ invmail_check_recent invmail_check_stats invmailcap_sanitize invmaildir_check_cur
			\ invmaildir_header_cache_verify invmaildir_trash invmark_old invmarkers invmenu_move_off
			\ invmenu_scroll invmessage_cache_clean invmeta_key invmetoo invmh_purge
			\ invmime_forward_decode invmime_type_query_first invmuttlisp_inline_eval invnarrow_tree
			\ invpager_stop invpgp_auto_decode invpgp_auto_traditional invpgp_autoencrypt
			\ invpgp_autoinline invpgp_autosign invpgp_check_exit
			\ invpgp_check_gpg_decrypt_status_fd invpgp_create_traditional
			\ invpgp_ignore_subkeys invpgp_long_ids invpgp_replyencrypt invpgp_replyinline
			\ invpgp_replysign invpgp_replysignencrypted invpgp_retainable_sigs
			\ invpgp_self_encrypt invpgp_self_encrypt_as invpgp_show_unusable
			\ invpgp_strict_enc invpgp_use_gpg_agent invpipe_decode invpipe_decode_weed invpipe_split
			\ invpop_auth_try_all invpop_last invpostpone_encrypt invpostpone_encrypt_as
			\ invprint_decode invprint_decode_weed invprint_split invprompt_after invread_only
			\ invreflow_space_quotes invreflow_text invreflow_wrap invreply_self invresolve
			\ invresume_draft_file sinvresume_edited_draft_files invreverse_alias
			\ invreverse_name invreverse_realname invrfc2047_parameters invsave_address
			\ invsave_empty invsave_name invscore invsidebar_folder_indent
			\ invsidebar_new_mail_only invsidebar_next_new_wrap invsidebar_relative_shortpath_indent
			\ invsidebar_short_path invsidebar_sort sidebar_use_mailbox_shortcuts invsidebar_visible
			\ invsig_dashes invsig_on_top invsize_show_bytes invsize_show_fraction invsize_show_mb
			\ invsize_units_on_left invsmart_wrap invsmime_ask_cert_label invsmime_decrypt_use_default_key
			\ invsmime_is_default invsmime_self_encrypt invsmime_self_encrypt_as invsort_re invssl_force_tls
			\ invssl_use_sslv2 invssl_use_sslv3 invssl_use_tlsv1 invssl_use_tlsv1_3 invssl_usesystemcerts
			\ invssl_verify_dates invssl_verify_host invssl_verify_partial_chains
			\ invstatus_on_top invstrict_mime invstrict_threads invsuspend invtext_flowed
			\ invthorough_search invthread_received invtilde invts_enabled invtunnel_is_secure
			\ invuncollapse_jump invuse_8bitmime invuse_domain invuse_envelope_from
			\ invuse_from invuse_idn invuse_ipv6 invuncollapse_new invuser_agent
			\ invwait_key invweed invwrap_search invwrite_bcc
			\ nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

syn keyword muttrcVarQuad	skipwhite contained
			\ abort_nosubject abort_unmodified abort_noattach bounce copy crypt_verify_sig
			\ delete fcc_attach forward_attachments forward_decrypt forward_edit honor_followup_to include
			\ mime_forward mime_forward_rest mime_fwd move pgp_mime_auto pgp_verify_sig pop_delete
			\ pop_reconnect postpone print quit recall reply_to send_multipart_alternative ssl_starttls
			\ nextgroup=muttrcSetQuadAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

syn keyword muttrcVarQuad	skipwhite contained
			\ noabort_nosubject noabort_unmodified noabort_noattach nobounce nocopy
			\ nocrypt_verify_sig nodelete nofcc_attach noforward_attachments noforward_decrypt noforward_edit
			\ nohonor_followup_to noinclude nomime_forward nomime_forward_rest nomime_fwd nomove
			\ nopgp_mime_auto nopgp_verify_sig nopop_delete nopop_reconnect nopostpone
			\ noprint noquit norecall noreply_to nosend_multipart_alternative nossl_starttls
			\ nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

syn keyword muttrcVarQuad	skipwhite contained
			\ invabort_nosubject invabort_unmodified invabort_noattach invbounce invcopy
			\ invcrypt_verify_sig invdelete invfcc_attach invforward_attachments invforward_decrypt
			\ invforward_edit invhonor_followup_to invinclude invmime_forward invmime_forward_rest
			\ invmime_fwd invmove invpgp_mime_auto invpgp_verify_sig invpop_delete
			\ invpop_reconnect invpostpone invprint invquit invrecall invreply_to
			\ invsend_multipart_alternative invssl_starttls
			\ nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

syn keyword muttrcVarNum	skipwhite contained
			\ connect_timeout error_history history imap_fetch_chunk_size imap_keepalive imap_pipeline_depth
			\ imap_poll_timeout mail_check mail_check_stats_interval menu_context net_inc
			\ pager_context pager_index_lines pager_skip_quoted_context pgp_timeout pop_checkinterval read_inc
			\ save_history score_threshold_delete score_threshold_flag
			\ score_threshold_read search_context sendmail_wait sidebar_width sleep_time
			\ smime_timeout ssl_min_dh_prime_bits time_inc timeout wrap wrap_headers
			\ wrapmargin write_inc
			\ nextgroup=muttrcSetNumAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

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
syn match muttrcAttachFormatEscapes contained /%\%(\%(-\?[0-9]\+\)\?\%(\.[0-9]\+\)\?\)\?[:_]\?[CcDdeFfImMnQstTuX%]/
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
syn match muttrcStatusFormatEscapes contained /%\%(\%(-\?[0-9]\+\)\?\%(\.[0-9]\+\)\?\)\?[:_]\?[bdfFhlLmMnopPRrsStuvV%]/
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
syn keyword muttrcVarStr	contained skipwhite background_format nextgroup=muttrcVarEqualsBackgroundFormatFmt
syn match muttrcVarEqualsBackgroundFormatFmt contained skipwhite "=" nextgroup=muttrcBackgroundFormatStr
syn keyword muttrcVarStr	contained skipwhite compose_format nextgroup=muttrcVarEqualsComposeFmt
syn match muttrcVarEqualsComposeFmt contained skipwhite "=" nextgroup=muttrcComposeFormatStr
syn keyword muttrcVarStr	contained skipwhite folder_format nextgroup=muttrcVarEqualsFolderFmt
syn match muttrcVarEqualsFolderFmt contained skipwhite "=" nextgroup=muttrcFolderFormatStr
syn keyword muttrcVarStr	contained skipwhite message_id_format nextgroup=muttrcVarEqualsMessageIdFmt
syn match muttrcVarEqualsMessageIdFmt contained skipwhite "=" nextgroup=muttrcMessageIdFormatStr
syn keyword muttrcVarStr	contained skipwhite mix_entry_format nextgroup=muttrcVarEqualsMixFmt
syn match muttrcVarEqualsMixFmt contained skipwhite "=" nextgroup=muttrcMixFormatStr
syn keyword muttrcVarStr	contained skipwhite pgp_entry_format nextgroup=muttrcVarEqualsPGPFmt
syn match muttrcVarEqualsPGPFmt contained skipwhite "=" nextgroup=muttrcPGPFormatStr
syn keyword muttrcVarStr	contained skipwhite query_format nextgroup=muttrcVarEqualsQueryFmt
syn match muttrcVarEqualsQueryFmt contained skipwhite "=" nextgroup=muttrcQueryFormatStr
syn keyword muttrcVarStr	contained skipwhite pgp_decode_command pgp_verify_command pgp_decrypt_command pgp_clearsign_command pgp_sign_command pgp_encrypt_sign_command pgp_encrypt_only_command pgp_import_command pgp_export_command pgp_verify_key_command pgp_list_secring_command pgp_list_pubring_command nextgroup=muttrcVarEqualsPGPCmdFmt
syn match muttrcVarEqualsPGPCmdFmt contained skipwhite "=" nextgroup=muttrcPGPCmdFormatStr
syn keyword muttrcVarStr	contained skipwhite ts_icon_format ts_status_format status_format nextgroup=muttrcVarEqualsStatusFmt
syn match muttrcVarEqualsStatusFmt contained skipwhite "=" nextgroup=muttrcStatusFormatStr
syn keyword muttrcVarStr	contained skipwhite pgp_getkeys_command nextgroup=muttrcVarEqualsPGPGetKeysFmt
syn match muttrcVarEqualsPGPGetKeysFmt contained skipwhite "=" nextgroup=muttrcPGPGetKeysFormatStr
syn keyword muttrcVarStr	contained skipwhite smime_decrypt_command smime_verify_command smime_verify_opaque_command smime_sign_command smime_sign_opaque_command smime_encrypt_command smime_pk7out_command smime_get_cert_command smime_get_signer_cert_command smime_import_cert_command smime_get_cert_email_command nextgroup=muttrcVarEqualsSmimeFmt
syn match muttrcVarEqualsSmimeFmt contained skipwhite "=" nextgroup=muttrcSmimeFormatStr
syn keyword muttrcVarStr	contained skipwhite date_format nextgroup=muttrcVarEqualsStrftimeFmt
syn match muttrcVarEqualsStrftimeFmt contained skipwhite "=" nextgroup=muttrcStrftimeFormatStr

syn match muttrcVPrefix		contained /[?&]/ nextgroup=muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

syn match muttrcVarStr		contained skipwhite 'my_[a-zA-Z0-9_]\+' nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syn keyword muttrcVarStr	contained skipwhite
			\ abort_noattach_regexp alias_file assumed_charset attach_charset attach_save_dir attach_sep
			\ attribution_locale certificate_file charset config_charset content_type
			\ crypt_protected_headers_subject default_hook display_filter dotlock_program dsn_notify
		        \ dsn_return editor entropy_file envelope_from_address escape fcc_delimiter folder forw_format
		        \ forward_attribution_intro forward_attribution_trailer forward_format from gecos_mask
		        \ hdr_format header_cache header_cache_compress header_cache_pagesize history_file
		        \ hostname imap_authenticators imap_delim_chars imap_headers imap_idle imap_login
		        \ imap_oauth_refresh_command imap_pass imap_user indent_str indent_string ispell locale
		        \ mailcap_pat hmark_macro_prefix mask mbox mbox_type message_cachedir mh_seq_flagged
		        \ mh_seq_replied mh_seq_unseen mime_type_query_command mixmaster msg_format new_mail_command
		        \ pager pgp_default_key pgp_decryption_okay pgp_good_sign pgp_mime_signature_description
		        \ pgp_mime_signature_filename pgp_sign_as pgp_sort_keys pipe_sep pop_authenticators
		        \ pop_host pop_oauth_refresh_command pop_pass pop_user post_indent_str post_indent_string
		        \ postpone_encrypt_as postponed preconnect print_cmd print_command query_command
		        \ quote_regexp realname record reply_regexp send_charset send_multipart_alternative_filter
		        \ sendmail shell sidebar_delim
		        \ sidebar_delim_chars sidebar_divider_char sidebar_format sidebar_indent_string
		        \ sidebar_sort_method signature simple_search smileys smime_ca_location smime_certificates
		        \ smime_default_key smime_encrypt_with smime_keys smime_sign_as smime_sign_digest_alg
		        \ smtp_authenticators smtp_oauth_refresh_command smtp_pass smtp_url sort sort_alias
		        \ sort_aux sort_browser sort_thread_groups spam_separator spoolfile ssl_ca_certificates_file
		        \ ssl_ciphers ssl_client_cert ssl_verify_host_override status_chars tmpdir to_chars trash
		        \ ts_icon_format ts_status_format tunnel visual
			\ nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

" Present in 1.4.2.1 (pgp_create_traditional was a bool then)
syn keyword muttrcVarBool	contained skipwhite imap_force_ssl noimap_force_ssl invimap_force_ssl nextgroup=muttrcSetBoolAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
"syn keyword muttrcVarQuad	contained pgp_create_traditional nopgp_create_traditional invpgp_create_traditional
syn keyword muttrcVarStr	contained skipwhite alternates nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

syn keyword muttrcMenu		contained alias attach browser compose editor index pager postpone pgp mix query generic
syn match muttrcMenuList "\S\+" contained contains=muttrcMenu
syn match muttrcMenuCommas /,/ contained

syn keyword muttrcHooks		contained skipwhite account-hook charset-hook iconv-hook index-format-hook message-hook folder-hook mbox-hook save-hook fcc-hook fcc-save-hook send-hook send2-hook reply-hook crypt-hook

syn keyword muttrcCommand	skipwhite
			\ alternative_order auto_view cd exec hdr_order iconv-hook ignore index-format-hook mailboxes
			\ mailto_allow mime_lookup my_hdr pgp-hook push run score sidebar_whitelist source
			\ unalternative_order unalternative_order unauto_view ungroup unhdr_order
			\ unignore unmailboxes unmailto_allow unmime_lookup unmono unmy_hdr unscore
			\ unsidebar_whitelist
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
syn match muttrcFunction	contained "\<\%(attach\|bounce\|copy\|delete\|display\|flag\|forward\|mark\|parent\|pipe\|postpone\|print\|purge\|recall\|resend\|root\|save\|send\|tag\|undelete\)-message\>"
syn match muttrcFunction	contained "\<\%(delete\|next\|previous\|read\|tag\|break\|undelete\)-thread\>"
syn match muttrcFunction	contained "\<link-threads\>"
syn match muttrcFunction	contained "\<\%(backward\|capitalize\|downcase\|forward\|kill\|upcase\)-word\>"
syn match muttrcFunction	contained "\<\%(delete\|filter\|first\|last\|next\|pipe\|previous\|print\|save\|select\|tag\|undelete\)-entry\>"
syn match muttrcFunction	contained "\<attach-\%(file\|key\)\>"
syn match muttrcFunction	contained "\<background-compose-menu\>"
syn match muttrcFunction	contained "\<browse-mailbox\>"
syn match muttrcFunction	contained "\<change-\%(dir\|folder\|folder-readonly\)\>"
syn match muttrcFunction	contained "\<check-\%(new\|traditional-pgp\)\>"
syn match muttrcFunction	contained "\<current-\%(bottom\|middle\|top\)\>"
syn match muttrcFunction	contained "\<decode-\%(copy\|save\)\>"
syn match muttrcFunction	contained "\<delete-\%(char\|pattern\|subthread\)\>"
syn match muttrcFunction	contained "\<descend-directory\>"
syn match muttrcFunction	contained "\<display-\%(address\|toggle-weed\)\>"
syn match muttrcFunction	contained "\<echo\>"
syn match muttrcFunction	contained "\<edit\%(-\%(bcc\|cc\|description\|encoding\|fcc\|file\|from\|headers\|label\|mime\|reply-to\|subject\|to\|type\)\)\?\>"
syn match muttrcFunction	contained "\<enter-\%(command\|mask\)\>"
syn match muttrcFunction	contained "\<error-history\>"
syn match muttrcFunction	contained "\<group-chat-reply\>"
syn match muttrcFunction	contained "\<half-\%(up\|down\)\>"
syn match muttrcFunction	contained "\<history-\%(up\|down\|search\)\>"
syn match muttrcFunction	contained "\<kill-\%(eol\|eow\|line\)\>"
syn match muttrcFunction	contained "\<move-\%(down\|up\)\>"
syn match muttrcFunction	contained "\<next-\%(line\|new\%(-then-unread\)\?\|page\|subthread\|undeleted\|unread\|unread-mailbox\)\>"
syn match muttrcFunction	contained "\<previous-\%(line\|new\%(-then-unread\)\?\|page\|subthread\|undeleted\|unread\)\>"
syn match muttrcFunction	contained "\<search\%(-\%(next\|opposite\|reverse\|toggle\)\)\?\>"
syn match muttrcFunction	contained "\<show-\%(limit\|version\)\>"
syn match muttrcFunction	contained "\<sort-\%(mailbox\|reverse\)\>"
syn match muttrcFunction	contained "\<tag-\%(pattern\|\%(sub\)\?thread\|prefix\%(-cond\)\?\)\>"
syn match muttrcFunction	contained "\<end-cond\>"
syn match muttrcFunction	contained "\<sidebar-\%(first\|last\|next\|next-new\|open\|page-down\|page-up\|prev\|prev-new\|toggle-visible\)\>"
syn match muttrcFunction	contained "\<toggle-\%(mailboxes\|new\|quoted\|subscribed\|unlink\|write\)\>"
syn match muttrcFunction	contained "\<undelete-\%(pattern\|subthread\)\>"
syn match muttrcFunction	contained "\<collapse-\%(parts\|thread\|all\)\>"
syn match muttrcFunction	contained "\<rename-attachment\>"
syn match muttrcFunction	contained "\<subjectrx\>"
syn match muttrcFunction	contained "\<\%(un\)\?setenv\>"
syn match muttrcFunction	contained "\<view-\%(alt\|alt-text\|alt-mailcap\|alt-pager\|attach\|attachments\|file\|mailcap\|name\|pager\|text\)\>"
syn match muttrcFunction	contained "\<\%(backspace\|backward-char\|bol\|bottom\|bottom-page\|buffy-cycle\|check-stats\|clear-flag\|complete\%(-query\)\?\|compose-to-sender\|copy-file\|create-alias\|detach-file\|eol\|exit\|extract-keys\|\%(imap-\)\?fetch-mail\|forget-passphrase\|forward-char\|group-reply\|help\|ispell\|jump\|limit\|list-action\|list-reply\|mail\|mail-key\|mark-as-new\|middle-page\|new-mime\|noop\|pgp-menu\|query\|query-append\|quit\|quote-char\|read-subthread\|redraw-screen\|refresh\|rename-file\|reply\|select-new\|set-flag\|shell-escape\|skip-headers\|skip-quoted\|sort\|subscribe\|sync-mailbox\|top\|top-page\|transpose-chars\|unsubscribe\|untag-pattern\|verify-key\|what-key\|write-fcc\)\>"
syn keyword muttrcFunction	contained imap-logout-all
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

syn match muttrcIndexFormatHookName contained /\S\+/ skipwhite nextgroup=muttrcPattern,muttrcString
syn match muttrcIndexFormatHook /index-format-hook/ skipwhite nextgroup=muttrcIndexFormatHookName,muttrcString

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
syn region muttrcPattern contained keepend skipwhite start=+[~][<>](+ end=+)+ skip=+\\)+ contains=muttrcSimplePat
syn match muttrcPattern contained skipwhite /[~][A-Za-z]/ contains=muttrcSimplePat
syn match muttrcPattern contained skipwhite /[.]/
syn region muttrcPatternInner contained keepend start=+"[~=%!(^]+ms=s+1 skip=+\\"+ end=+"+me=e-1 contains=muttrcSimplePat,muttrcUnHighlightSpace,muttrcSimplePatMetas
syn region muttrcPatternInner contained keepend start=+'[~=%!(^]+ms=s+1 skip=+\\'+ end=+'+me=e-1 contains=muttrcSimplePat,muttrcUnHighlightSpace,muttrcSimplePatMetas

" Colour definitions takes object, foreground and background arguments (regexps excluded).
syn match muttrcColorMatchCount	contained "[0-9]\+"
syn match muttrcColorMatchCountNL contained skipwhite skipnl "\s*\\$" nextgroup=muttrcColorMatchCount,muttrcColorMatchCountNL
syn region muttrcColorRXPat	contained start=+\s*'+ skip=+\\'+ end=+'\s*+ keepend skipwhite contains=muttrcRXString2 nextgroup=muttrcColorMatchCount,muttrcColorMatchCountNL
syn region muttrcColorRXPat	contained start=+\s*"+ skip=+\\"+ end=+"\s*+ keepend skipwhite contains=muttrcRXString2 nextgroup=muttrcColorMatchCount,muttrcColorMatchCountNL
syn keyword muttrcColorField	skipwhite contained
			\ attachment body bold error hdrdefault header index indicator markers message
			\ normal prompt quoted search sidebar-divider sidebar-flagged sidebar-highlight
			\ sidebar-indicator sidebar-new sidebar-spoolfile signature status tilde tree
			\ underline
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
" Only when an item doesn't have highlighting yet

hi def link muttrcComment		Comment
hi def link muttrcEscape		SpecialChar
hi def link muttrcRXChars		SpecialChar
hi def link muttrcString		String
hi def link muttrcRXString		String
hi def link muttrcRXString2	String
hi def link muttrcSpecial		Special
hi def link muttrcHooks		Type
hi def link muttrcGroupFlag	Type
hi def link muttrcGroupDef		Macro
hi def link muttrcAddrDef		muttrcGroupFlag
hi def link muttrcRXDef		muttrcGroupFlag
hi def link muttrcRXPat		String
hi def link muttrcAliasGroupName	Macro
hi def link muttrcAliasKey	        Identifier
hi def link muttrcUnAliasKey	Identifier
hi def link muttrcAliasEncEmail	Identifier
hi def link muttrcAliasParens	Type
hi def link muttrcSetNumAssignment	Number
hi def link muttrcSetBoolAssignment	Boolean
hi def link muttrcSetQuadAssignment	Boolean
hi def link muttrcSetStrAssignment	String
hi def link muttrcEmail		Special
hi def link muttrcVariableInner	Special
hi def link muttrcEscapedVariable	String
hi def link muttrcHeader		Type
hi def link muttrcKeySpecial	SpecialChar
hi def link muttrcKey		Type
hi def link muttrcKeyName		SpecialChar
hi def link muttrcVarBool		Identifier
hi def link muttrcVarQuad		Identifier
hi def link muttrcVarNum		Identifier
hi def link muttrcVarStr		Identifier
hi def link muttrcMenu		Identifier
hi def link muttrcCommand		Keyword
hi def link muttrcMacroDescr	String
hi def link muttrcAction		Macro
hi def link muttrcBadAction	Error
hi def link muttrcBindFunction	Error
hi def link muttrcBindMenuList	Error
hi def link muttrcFunction		Macro
hi def link muttrcGroupKeyword	muttrcCommand
hi def link muttrcGroupLine	Error
hi def link muttrcSubscribeKeyword	muttrcCommand
hi def link muttrcSubscribeLine	Error
hi def link muttrcListsKeyword	muttrcCommand
hi def link muttrcListsLine	Error
hi def link muttrcAlternateKeyword	muttrcCommand
hi def link muttrcAlternatesLine	Error
hi def link muttrcAttachmentsLine	muttrcCommand
hi def link muttrcAttachmentsFlag	Type
hi def link muttrcAttachmentsMimeType	String
hi def link muttrcColorLine	Error
hi def link muttrcColorContext	Error
hi def link muttrcColorContextI	Identifier
hi def link muttrcColorContextH	Identifier
hi def link muttrcColorKeyword	muttrcCommand
hi def link muttrcColorKeywordI	muttrcColorKeyword
hi def link muttrcColorKeywordH	muttrcColorKeyword
hi def link muttrcColorField	Identifier
hi def link muttrcColor		Type
hi def link muttrcColorFG		Error
hi def link muttrcColorFGI		Error
hi def link muttrcColorFGH		Error
hi def link muttrcColorBG		Error
hi def link muttrcColorBGI		Error
hi def link muttrcColorBGH		Error
hi def link muttrcMonoAttrib	muttrcColor
hi def link muttrcMono		muttrcCommand
hi def link muttrcSimplePat	Identifier
hi def link muttrcSimplePatString	Macro
hi def link muttrcSimplePatMetas	Special
hi def link muttrcPattern		Error
hi def link muttrcUnColorLine	Error
hi def link muttrcUnColorKeyword	muttrcCommand
hi def link muttrcUnColorIndex	Identifier
hi def link muttrcShellString	muttrcEscape
hi def link muttrcRXHooks		muttrcCommand
hi def link muttrcRXHookNot	Type
hi def link muttrcPatHooks		muttrcCommand
hi def link muttrcIndexFormatHookName	muttrcCommand
hi def link muttrcIndexFormatHook	 muttrcCommand
hi def link muttrcPatHookNot	Type
hi def link muttrcFormatConditionals2 Type
hi def link muttrcIndexFormatStr	muttrcString
hi def link muttrcIndexFormatEscapes muttrcEscape
hi def link muttrcIndexFormatConditionals muttrcFormatConditionals2
hi def link muttrcAliasFormatStr	muttrcString
hi def link muttrcAliasFormatEscapes muttrcEscape
hi def link muttrcAttachFormatStr	muttrcString
hi def link muttrcAttachFormatEscapes muttrcEscape
hi def link muttrcAttachFormatConditionals muttrcFormatConditionals2
hi def link muttrcBackgroundFormatStr	muttrcString
hi def link muttrcComposeFormatStr	muttrcString
hi def link muttrcComposeFormatEscapes muttrcEscape
hi def link muttrcFolderFormatStr	muttrcString
hi def link muttrcFolderFormatEscapes muttrcEscape
hi def link muttrcFolderFormatConditionals muttrcFormatConditionals2
hi def link muttrcMessageIdFormatStr	muttrcString
hi def link muttrcMixFormatStr	muttrcString
hi def link muttrcMixFormatEscapes muttrcEscape
hi def link muttrcMixFormatConditionals muttrcFormatConditionals2
hi def link muttrcPGPFormatStr	muttrcString
hi def link muttrcPGPFormatEscapes muttrcEscape
hi def link muttrcPGPFormatConditionals muttrcFormatConditionals2
hi def link muttrcPGPCmdFormatStr	muttrcString
hi def link muttrcPGPCmdFormatEscapes muttrcEscape
hi def link muttrcPGPCmdFormatConditionals muttrcFormatConditionals2
hi def link muttrcStatusFormatStr	muttrcString
hi def link muttrcStatusFormatEscapes muttrcEscape
hi def link muttrcStatusFormatConditionals muttrcFormatConditionals2
hi def link muttrcPGPGetKeysFormatStr	muttrcString
hi def link muttrcPGPGetKeysFormatEscapes muttrcEscape
hi def link muttrcSmimeFormatStr	muttrcString
hi def link muttrcSmimeFormatEscapes muttrcEscape
hi def link muttrcSmimeFormatConditionals muttrcFormatConditionals2
hi def link muttrcTimeEscapes	muttrcEscape
hi def link muttrcPGPTimeEscapes	muttrcEscape
hi def link muttrcStrftimeEscapes	Type
hi def link muttrcStrftimeFormatStr muttrcString
hi def link muttrcBindMenuListNL	SpecialChar
hi def link muttrcMacroDescrNL	SpecialChar
hi def link muttrcMacroBodyNL	SpecialChar
hi def link muttrcMacroKeyNL	SpecialChar
hi def link muttrcMacroMenuListNL	SpecialChar
hi def link muttrcColorMatchCountNL SpecialChar
hi def link muttrcColorNL		SpecialChar
hi def link muttrcColorRXNL	SpecialChar
hi def link muttrcColorBGNL	SpecialChar
hi def link muttrcColorFGNL	SpecialChar
hi def link muttrcAliasNameNL	SpecialChar
hi def link muttrcAliasENNL	SpecialChar
hi def link muttrcAliasNL		SpecialChar
hi def link muttrcUnAliasNL	SpecialChar
hi def link muttrcAliasGroupDefNL	SpecialChar
hi def link muttrcAliasEncEmailNL	SpecialChar
hi def link muttrcPatternNL	SpecialChar
hi def link muttrcUnColorPatNL	SpecialChar
hi def link muttrcUnColorAPNL	SpecialChar
hi def link muttrcUnColorIndexNL	SpecialChar
hi def link muttrcStringNL		SpecialChar


let b:current_syntax = "muttrc"

let &cpo = s:cpo_save
unlet s:cpo_save
"EOF	vim: ts=8 noet tw=100 sw=8 sts=0 ft=vim
