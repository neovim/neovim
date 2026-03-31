" DTML syntax file
" Language:			Zope's Dynamic Template Markup Language
" Maintainer:	    Jean Jordaan <jean@upfrontsystems.co.za> (njj)
" Last change:	    2001 Sep 02

" These are used with Claudio Fleiner's html.vim in the standard distribution.
"
" Still very hackish. The 'dtml attributes' and 'dtml methods' have been
" hacked out of the Zope Quick Reference in case someone finds something
" sensible to do with them. I certainly haven't.

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" First load the HTML syntax
runtime! syntax/html.vim

syn case match

" This doesn't have any effect.  Does it need to be moved to above/
" if !exists("main_syntax")
"   let main_syntax = 'dtml'
" endif

" dtml attributes
syn keyword dtmlAttribute ac_inherited_permissions access_debug_info contained
syn keyword dtmlAttribute acquiredRolesAreUsedBy all_meta_types assume_children AUTH_TYPE contained
syn keyword dtmlAttribute AUTHENTICATED_USER AUTHENTICATION_PATH BASE0 batch-end-index batch-size contained
syn keyword dtmlAttribute batch-start-index bobobase_modification_time boundary branches contained
syn keyword dtmlAttribute branches_expr capitalize cb_dataItems cb_dataValid cb_isCopyable contained
syn keyword dtmlAttribute cb_isMoveable changeClassId classDefinedAndInheritedPermissions contained
syn keyword dtmlAttribute classDefinedPermissions classInheritedPermissions collapse-all column contained
syn keyword dtmlAttribute connected connectionIsValid CONTENT_LENGTH CONTENT_TYPE cook cookies contained
syn keyword dtmlAttribute COPY count- createInObjectManager da_has_single_argument dav__allprop contained
syn keyword dtmlAttribute dav__init dav__propnames dav__propstat dav__validate default contained
syn keyword dtmlAttribute delClassAttr DELETE Destination DestinationURL digits discard contained
syn keyword dtmlAttribute disposition document_src e encode enter etc expand-all expr File contained
syn keyword dtmlAttribute filtered_manage_options filtered_meta_types first- fmt footer form contained
syn keyword dtmlAttribute GATEWAY_INTERFACE get_local_roles get_local_roles_for_userid contained
syn keyword dtmlAttribute get_request_var_or_attr get_size get_size get_valid_userids getAttribute contained
syn keyword dtmlAttribute getAttributeNode getAttributes getChildNodes getClassAttr getContentType contained
syn keyword dtmlAttribute getData getDocType getDocumentElement getElementsByTagName getFirstChild contained
syn keyword dtmlAttribute getImplementation getLastChild getLength getName getNextSibling contained
syn keyword dtmlAttribute getNodeName getNodeType getNodeValue getOwnerDocument getParentNode contained
syn keyword dtmlAttribute getPreviousSibling getProperty getPropertyType getSize getSize getSize contained
syn keyword dtmlAttribute get_size getTagName getUser getUserName getUserNames getUsers contained
syn keyword dtmlAttribute has_local_roles hasChildNodes hasProperty HEAD header hexdigits HTML contained
syn keyword dtmlAttribute html_quote HTMLFile id index_html index_objects indexes contained
syn keyword dtmlAttribute inheritedAttribute items last- leave leave_another leaves letters LOCK contained
syn keyword dtmlAttribute locked_in_version lower lowercase mailfrom mailhost mailhost_list mailto contained
syn keyword dtmlAttribute manage manage_ methods manage_access manage_acquiredPermissions contained
syn keyword dtmlAttribute manage_addConferaTopic manage_addDocument manage_addDTMLDocument contained
syn keyword dtmlAttribute manage_addDTMLMethod manage_addFile manage_addFolder manage_addImage contained
syn keyword dtmlAttribute manage_addLocalRoles manage_addMailHost manage_addPermission contained
syn keyword dtmlAttribute manage_addPrincipiaFactory manage_addProduct manage_addProperty contained
syn keyword dtmlAttribute manage_addUserFolder manage_addZClass manage_addZGadflyConnection contained
syn keyword dtmlAttribute manage_addZGadflyConnectionForm manage_advanced manage_afterAdd contained
syn keyword dtmlAttribute manage_afterClone manage_beforeDelete manage_changePermissions contained
syn keyword dtmlAttribute manage_changeProperties manage_clone manage_CopyContainerFirstItem contained
syn keyword dtmlAttribute manage_copyObjects manage_cutObjects manage_defined_roles contained
syn keyword dtmlAttribute manage_delLocalRoles manage_delObjects manage_delProperties contained
syn keyword dtmlAttribute manage_distribute manage_edit manage_editedDialog manage_editProperties contained
syn keyword dtmlAttribute manage_editRoles manage_exportObject manage_FTPget manage_FTPlist contained
syn keyword dtmlAttribute manage_FTPstat manage_get_product_readme__ manage_getPermissionMapping contained
syn keyword dtmlAttribute manage_haveProxy manage_help manage_importObject manage_listLocalRoles contained
syn keyword dtmlAttribute manage_options manage_pasteObjects manage_permission contained
syn keyword dtmlAttribute manage_propertiesForm manage_proxy manage_renameObject manage_role contained
syn keyword dtmlAttribute manage_setLocalRoles manage_setPermissionMapping contained
syn keyword dtmlAttribute manage_subclassableClassNames manage_test manage_testForm contained
syn keyword dtmlAttribute manage_undo_transactions manage_upload manage_users manage_workspace contained
syn keyword dtmlAttribute management_interface mapping math max- mean- median- meta_type min- contained
syn keyword dtmlAttribute MKCOL modified_in_version MOVE multiple name navigate_filter new_version contained
syn keyword dtmlAttribute newline_to_br next next-batches next-sequence next-sequence-end-index contained
syn keyword dtmlAttribute next-sequence-size next-sequence-start-index no manage_access None contained
syn keyword dtmlAttribute nonempty normalize nowrap null Object Manager objectIds objectItems contained
syn keyword dtmlAttribute objectMap objectValues octdigits only optional OPTIONS orphan overlap contained
syn keyword dtmlAttribute PARENTS PATH_INFO PATH_TRANSLATED permission_settings contained
syn keyword dtmlAttribute permissionMappingPossibleValues permissionsOfRole pi port contained
syn keyword dtmlAttribute possible_permissions previous previous-batches previous-sequence contained
syn keyword dtmlAttribute previous-sequence-end-index previous-sequence-size contained
syn keyword dtmlAttribute previous-sequence-start-index PrincipiaFind PrincipiaSearchSource contained
syn keyword dtmlAttribute propdict propertyIds propertyItems propertyLabel propertyMap propertyMap contained
syn keyword dtmlAttribute propertyValues PROPFIND PROPPATCH PUT query_day query_month QUERY_STRING contained
syn keyword dtmlAttribute query_year quoted_input quoted_report raise_standardErrorMessage random contained
syn keyword dtmlAttribute read read_raw REMOTE_ADDR REMOTE_HOST REMOTE_IDENT REMOTE_USER REQUEST contained
syn keyword dtmlAttribute REQUESTED_METHOD required RESPONSE reverse rolesOfPermission save schema contained
syn keyword dtmlAttribute SCRIPT_NAME sequence-end sequence-even sequence-index contained
syn keyword dtmlAttribute sequence-index-var- sequence-item sequence-key sequence-Letter contained
syn keyword dtmlAttribute sequence-letter sequence-number sequence-odd sequence-query contained
syn keyword dtmlAttribute sequence-roman sequence-Roman sequence-start sequence-step-end-index contained
syn keyword dtmlAttribute sequence-step-size sequence-step-start-index sequence-var- SERVER_NAME contained
syn keyword dtmlAttribute SERVER_PORT SERVER_PROTOCOL SERVER_SOFTWARE setClassAttr setName single contained
syn keyword dtmlAttribute size skip_unauthorized smtphost sort spacify sql_quote SQLConnectionIDs contained
syn keyword dtmlAttribute standard-deviation- standard-deviation-n- standard_html_footer contained
syn keyword dtmlAttribute standard_html_header start String string subject SubTemplate superValues contained
syn keyword dtmlAttribute tabs_path_info tag test_url_ text_content this thousands_commas title contained
syn keyword dtmlAttribute title_and_id title_or_id total- tpURL tpValues TRACE translate tree-c contained
syn keyword dtmlAttribute tree-colspan tree-e tree-item-expanded tree-item-url tree-level contained
syn keyword dtmlAttribute tree-root-url tree-s tree-state type undoable_transactions UNLOCK contained
syn keyword dtmlAttribute update_data upper uppercase url url_quote URLn user_names contained
syn keyword dtmlAttribute userdefined_roles valid_property_id valid_roles validate_roles contained
syn keyword dtmlAttribute validClipData validRoles values variance- variance-n- view_image_or_file contained
syn keyword dtmlAttribute where whitespace whrandom xml_namespace zclass_candidate_view_actions contained
syn keyword dtmlAttribute ZClassBaseClassNames ziconImage ZopeFind ZQueryIds contained

syn keyword dtmlMethod abs absolute_url ac_inherited_permissions aCommon contained
syn keyword dtmlMethod aCommonZ acos acquiredRolesAreUsedBy aDay addPropertySheet aMonth AMPM contained
syn keyword dtmlMethod ampm AMPMMinutes appendChild appendData appendHeader asin atan atan2 contained
syn keyword dtmlMethod atof atoi betavariate capatilize capwords catalog_object ceil center contained
syn keyword dtmlMethod choice chr cloneNode COPY cos cosh count createInObjectManager contained
syn keyword dtmlMethod createSQLInput cunifvariate Date DateTime Day day dayOfYear dd default contained
syn keyword dtmlMethod DELETE deleteData delPropertySheet divmod document_id document_title dow contained
syn keyword dtmlMethod earliestTime enter equalTo exp expireCookie expovariate fabs fCommon contained
syn keyword dtmlMethod fCommonZ filtered_manage_options filtered_meta_types find float floor contained
syn keyword dtmlMethod fmod frexp gamma gauss get get_local_roles_for_userid get_size getattr contained
syn keyword dtmlMethod getAttribute getAttributeNode getClassAttr getDomains contained
syn keyword dtmlMethod getElementsByTagName getHeader getitem getNamedItem getobject contained
syn keyword dtmlMethod getObjectsInfo getpath getProperty getRoles getStatus getUser contained
syn keyword dtmlMethod getUserName greaterThan greaterThanEqualTo h_12 h_24 has_key contained
syn keyword dtmlMethod has_permission has_role hasattr hasFeature hash hasProperty HEAD hex contained
syn keyword dtmlMethod hour hypot index index_html inheritedAttribute insertBefore insertData contained
syn keyword dtmlMethod int isCurrentDay isCurrentHour isCurrentMinute isCurrentMonth contained
syn keyword dtmlMethod isCurrentYear isFuture isLeadYear isPast item join latestTime ldexp contained
syn keyword dtmlMethod leave leave_another len lessThan lessThanEqualTo ljust log log10 contained
syn keyword dtmlMethod lognormvariate lower lstrip maketrans manage manage_access contained
syn keyword dtmlMethod manage_acquiredPermissions manage_addColumn manage_addDocument contained
syn keyword dtmlMethod manage_addDTMLDocument manage_addDTMLMethod manage_addFile contained
syn keyword dtmlMethod manage_addFolder manage_addImage manage_addIndex manage_addLocalRoles contained
syn keyword dtmlMethod manage_addMailHost manage_addPermission manage_addPrincipiaFactory contained
syn keyword dtmlMethod manage_addProduct manage_addProperty manage_addPropertySheet contained
syn keyword dtmlMethod manage_addUserFolder manage_addZCatalog manage_addZClass contained
syn keyword dtmlMethod manage_addZGadflyConnection manage_addZGadflyConnectionForm contained
syn keyword dtmlMethod manage_advanced manage_catalogClear manage_catalogFoundItems contained
syn keyword dtmlMethod manage_catalogObject manage_catalogReindex manage_changePermissions contained
syn keyword dtmlMethod manage_changeProperties manage_clone manage_CopyContainerFirstItem contained
syn keyword dtmlMethod manage_copyObjects manage_createEditor manage_createView contained
syn keyword dtmlMethod manage_cutObjects manage_defined_roles manage_delColumns contained
syn keyword dtmlMethod manage_delIndexes manage_delLocalRoles manage_delObjects contained
syn keyword dtmlMethod manage_delProperties manage_Discard__draft__ manage_distribute contained
syn keyword dtmlMethod manage_edit manage_edit manage_editedDialog manage_editProperties contained
syn keyword dtmlMethod manage_editRoles manage_exportObject manage_importObject contained
syn keyword dtmlMethod manage_makeChanges manage_pasteObjects manage_permission contained
syn keyword dtmlMethod manage_propertiesForm manage_proxy manage_renameObject manage_role contained
syn keyword dtmlMethod manage_Save__draft__ manage_setLocalRoles manage_setPermissionMapping contained
syn keyword dtmlMethod manage_test manage_testForm manage_uncatalogObject contained
syn keyword dtmlMethod manage_undo_transactions manage_upload manage_users manage_workspace contained
syn keyword dtmlMethod mange_createWizard max min minute MKCOL mm modf month Month MOVE contained
syn keyword dtmlMethod namespace new_version nextObject normalvariate notEqualTo objectIds contained
syn keyword dtmlMethod objectItems objectValues oct OPTIONS ord paretovariate parts pCommon contained
syn keyword dtmlMethod pCommonZ pDay permissionsOfRole pMonth pow PreciseAMPM PreciseTime contained
syn keyword dtmlMethod previousObject propertyInfo propertyLabel PROPFIND PROPPATCH PUT quit contained
syn keyword dtmlMethod raise_standardErrorMessage randint random read read_raw redirect contained
syn keyword dtmlMethod removeAttribute removeAttributeNode removeChild replace replaceChild contained
syn keyword dtmlMethod replaceData rfc822 rfind rindex rjust rolesOfPermission round rstrip contained
syn keyword dtmlMethod save searchResults second seed set setAttribute setAttributeNode setBase contained
syn keyword dtmlMethod setCookie setHeader setStatus sin sinh split splitText sqrt str strip contained
syn keyword dtmlMethod substringData superValues swapcase tabs_path_info tan tanh Time contained
syn keyword dtmlMethod TimeMinutes timeTime timezone title title_and_id title_or_id toXML contained
syn keyword dtmlMethod toZone uncatalog_object undoable_transactions uniform uniqueValuesFor contained
syn keyword dtmlMethod update_data upper valid_property_id validate_roles vonmisesvariate contained
syn keyword dtmlMethod weibullvariate year yy zfill ZopeFind contained

" DTML tags
syn keyword dtmlTagName var if elif else unless in with let call raise try except tag comment tree sqlvar sqltest sqlgroup sendmail mime transparent contained

syn keyword dtmlEndTagName if unless in with let raise try tree sendmail transparent contained

" Own additions
syn keyword dtmlTODO    TODO FIXME		contained

syn region dtmlComment start=+<dtml-comment>+ end=+</dtml-comment>+ contains=dtmlTODO

" All dtmlTagNames are contained by dtmlIsTag.
syn match dtmlIsTag	    "dtml-[A-Za-z]\+"    contains=dtmlTagName

" 'var' tag entity syntax: &dtml-variableName;
"       - with attributes: &dtml.attribute1[.attribute2]...-variableName;
syn match dtmlSpecialChar "&dtml[.0-9A-Za-z_]\{-}-[0-9A-Za-z_.]\+;"

" Redefine to allow inclusion of DTML within HTML strings.
syn cluster htmlTop contains=@Spell,htmlTag,htmlEndTag,dtmlSpecialChar,htmlSpecialChar,htmlPreProc,htmlComment,htmlLink,javaScript,@htmlPreproc
syn region htmlLink start="<a\>[^>]*href\>" end="</a>"me=e-4 contains=@Spell,htmlTag,htmlEndTag,dtmlSpecialChar,htmlSpecialChar,htmlPreProc,htmlComment,javaScript,@htmlPreproc
syn region htmlHead start="<head\>" end="</head>"me=e-7 end="<body\>"me=e-5 end="<h[1-6]\>"me=e-3 contains=htmlTag,htmlEndTag,dtmlSpecialChar,htmlSpecialChar,htmlPreProc,htmlComment,htmlLink,htmlTitle,javaScript,cssStyle,@htmlPreproc
syn region htmlTitle start="<title\>" end="</title>"me=e-8 contains=htmlTag,htmlEndTag,dtmlSpecialChar,htmlSpecialChar,htmlPreProc,htmlComment,javaScript,@htmlPreproc
syn region  htmlString   contained start=+"+ end=+"+ contains=dtmlSpecialChar,htmlSpecialChar,javaScriptExpression,dtmlIsTag,dtmlAttribute,dtmlMethod,@htmlPreproc
syn match   htmlTagN     contained +<\s*[-a-zA-Z0-9]\++hs=s+1 contains=htmlTagName,htmlSpecialTagName,dtmlIsTag,dtmlAttribute,dtmlMethod,@htmlTagNameCluster
syn match   htmlTagN     contained +</\s*[-a-zA-Z0-9]\++hs=s+2 contains=htmlTagName,htmlSpecialTagName,dtmlIsTag,dtmlAttribute,dtmlMethod,@htmlTagNameCluster

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link dtmlIsTag			PreProc
hi def link dtmlAttribute		Identifier
hi def link dtmlMethod			Function
hi def link dtmlComment		Comment
hi def link dtmlTODO			Todo
hi def link dtmlSpecialChar    Special


let b:current_syntax = "dtml"

" if main_syntax == 'dtml'
"   unlet main_syntax
" endif

" vim: ts=4
