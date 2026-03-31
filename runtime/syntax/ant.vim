" Vim syntax file
" Language:		ANT build file (xml)
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Johannes Zellner <johannes@zellner.org>
" Last Change:		2024 Jan 27
" Filenames:		build.xml

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

let s:ant_cpo_save = &cpo
set cpo&vim

runtime! syntax/xml.vim

syn case ignore

if !exists('*AntSyntaxScript')
    fun AntSyntaxScript(tagname, synfilename)
	unlet b:current_syntax
	let s:include = expand("<sfile>:p:h").'/'.a:synfilename
	if filereadable(s:include)
	    exe 'syn include @ant'.a:tagname.' '.s:include
	else
	    exe 'syn include @ant'.a:tagname." $VIMRUNTIME/syntax/".a:synfilename
	endif

	exe 'syn region ant'.a:tagname
		    \." start=#<script[^>]\\{-}language\\s*=\\s*['\"]".a:tagname."['\"]\\(>\\|[^>]*[^/>]>\\)#"
		    \.' end=#</script>#'
		    \.' fold'
		    \.' contains=@ant'.a:tagname.',xmlCdataStart,xmlCdataEnd,xmlTag,xmlEndTag'
		    \.' keepend'
	exe 'syn cluster xmlRegionHook add=ant'.a:tagname
    endfun
endif

" TODO: add more script languages here ?
call AntSyntaxScript('javascript', 'javascript.vim')
call AntSyntaxScript('jpython', 'python.vim')


syn cluster xmlTagHook add=antElement

syn keyword antElement WsdlToDotnet addfiles and ant antcall antstructure apply archives arg argument
syn keyword antElement assertions attrib attribute available basename bcc blgenclient bootclasspath
syn keyword antElement borland bottom buildnumber buildpath buildpathelement bunzip2 bzip2 cab
syn keyword antElement catalogpath cc cccheckin cccheckout cclock ccmcheckin ccmcheckintask ccmcheckout
syn keyword antElement ccmcreatetask ccmkattr ccmkbl ccmkdir ccmkelem ccmklabel ccmklbtype
syn keyword antElement ccmreconfigure ccrmtype ccuncheckout ccunlock ccupdate checksum chgrp chmod
syn keyword antElement chown classconstants classes classfileset classpath commandline comment
syn keyword antElement compilerarg compilerclasspath concat concatfilter condition copy copydir
syn keyword antElement copyfile coveragepath csc custom cvs cvschangelog cvspass cvstagdiff cvsversion
syn keyword antElement daemons date defaultexcludes define delete deletecharacters deltree depend
syn keyword antElement depends dependset depth description different dirname dirset disable dname
syn keyword antElement doclet doctitle dtd ear echo echoproperties ejbjar element enable entity entry
syn keyword antElement env equals escapeunicode exclude excludepackage excludesfile exec execon
syn keyword antElement existing expandproperties extdirs extension extensionSet extensionset factory
syn keyword antElement fail filelist filename filepath fileset filesmatch filetokenizer filter
syn keyword antElement filterchain filterreader filters filterset filtersfile fixcrlf footer format
syn keyword antElement from ftp generic genkey get gjdoc grant group gunzip gzip header headfilter http
syn keyword antElement ignoreblank ilasm ildasm import importtypelib include includesfile input iplanet
syn keyword antElement iplanet-ejbc isfalse isreference isset istrue jar jarlib-available
syn keyword antElement jarlib-manifest jarlib-resolve java javac javacc javadoc javadoc2 jboss jdepend
syn keyword antElement jjdoc jjtree jlink jonas jpcoverage jpcovmerge jpcovreport jsharpc jspc
syn keyword antElement junitreport jvmarg lib libfileset linetokenizer link loadfile loadproperties
syn keyword antElement location macrodef mail majority manifest map mapper marker mergefiles message
syn keyword antElement metainf method mimemail mkdir mmetrics modified move mparse none not options or
syn keyword antElement os outputproperty package packageset parallel param patch path pathconvert
syn keyword antElement pathelement patternset permissions prefixlines present presetdef project
syn keyword antElement property propertyfile propertyref propertyset pvcs pvcsproject record reference
syn keyword antElement regexp rename renameext replace replacefilter replaceregex replaceregexp
syn keyword antElement replacestring replacetoken replacetokens replacevalue replyto report resource
syn keyword antElement revoke rmic root rootfileset rpm scp section selector sequential serverdeploy
syn keyword antElement setproxy signjar size sleep socket soscheckin soscheckout sosget soslabel source
syn keyword antElement sourcepath sql src srcfile srcfilelist srcfiles srcfileset sshexec stcheckin
syn keyword antElement stcheckout stlabel stlist stringtokenizer stripjavacomments striplinebreaks
syn keyword antElement striplinecomments style subant substitution support symlink sync sysproperty
syn keyword antElement syspropertyset tabstospaces tag taglet tailfilter tar tarfileset target
syn keyword antElement targetfile targetfilelist targetfileset taskdef tempfile test testlet text title
syn keyword antElement to token tokenfilter touch transaction translate triggers trim tstamp type
syn keyword antElement typedef unjar untar unwar unzip uptodate url user vbc vssadd vsscheckin
syn keyword antElement vsscheckout vsscp vsscreate vssget vsshistory vsslabel waitfor war wasclasspath
syn keyword antElement webapp webinf weblogic weblogictoplink websphere whichresource wlclasspath
syn keyword antElement wljspc wsdltodotnet xmlcatalog xmlproperty xmlvalidate xslt zip zipfileset
syn keyword antElement zipgroupfileset

hi def link antElement Statement

let b:current_syntax = "ant"

let &cpo = s:ant_cpo_save
unlet s:ant_cpo_save

" vim: ts=8
