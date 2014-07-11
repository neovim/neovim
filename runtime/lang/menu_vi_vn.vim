" Menu Translations:	Vietnamese
" Maintainer:		Phan Vinh Thinh <teppi@vnlinux.org>
" Last Change:		12 Mar 2005
" URL:			http://iatp.vspu.ac.ru/phan/vietvim/lang/menu_vi_vn.vim
"
"
" Adopted for VietVim project by Phan Vinh Thinh.
" First translation: Phan Vinh Thinh <teppi@vnlinux.org>
"
"
" Quit when menu translations have already been done.
"
if exists("did_menu_trans")
   finish
endif
let did_menu_trans = 1
let s:keepcpo= &cpo
set cpo&vim

scriptencoding utf-8

" Top
menutrans &File				&Tập\ tin
menutrans &Edit				&Soạn\ thảo
menutrans &Tools			Cô&ng\ cụ
menutrans &Syntax			&Cú\ pháp
menutrans &Buffers			&Bộ\ đệm
menutrans &Window			Cử&a\ sổ
menutrans &Help				Trợ\ &giúp
"
"
"
" Help menu
menutrans &Overview<Tab><F1>		&Tổng\ quan<Tab><F1>
menutrans &User\ Manual			&Hướng\ dẫn\ sử\ dụng
menutrans &How-to\ links		&Làm\ như\ thế\ nào
menutrans &Find\.\.\.			Tìm\ &kiếm\.\.\.
"--------------------
menutrans &Credits			Lời\ &cảm\ ơn
menutrans Co&pying			&Bản\ quyền
menutrans &Sponsor/Register		&Giúp\ đỡ/Đăng\ ký
menutrans O&rphans			Trẻ\ &mồ\ côi
"--------------------
menutrans &Version			&Phiên\ bản
menutrans &About			&Về\ Vim
"
"
" File menu
menutrans &Open\.\.\.<Tab>:e		&Mở\.\.\.<Tab>:e
menutrans Sp&lit-Open\.\.\.<Tab>:sp	&Chia-Mở\.\.\.<Tab>:sp
menutrans &New<Tab>:enew		Mớ&i<Tab>:enew
menutrans &Close<Tab>:close		Đó&ng<Tab>:close
"--------------------
menutrans &Save<Tab>:w			&Ghi\ nhớ<Tab>:w
menutrans Save\ &As\.\.\.<Tab>:sav	Ghi\ n&hư\.\.\.<Tab>:sav
"--------------------
menutrans Split\ &Diff\ with\.\.\.	&So\ sánh\ với\.\.\.
menutrans Split\ Patched\ &By\.\.\.	So\ sánh\ đã\ vá\ lỗi\ &bởi\.\.\.
"--------------------
menutrans &Print			In\ &ra
menutrans Sa&ve-Exit<Tab>:wqa		Ghi\ nhớ\ rồi\ th&oát <Tab>:wqa
menutrans E&xit<Tab>:qa			&Thoát<Tab>:qa
"
"
" Edit menu
menutrans &Undo<Tab>u			&Hủy\ bước<Tab>u
menutrans &Redo<Tab>^R			&Làm\ lại<Tab>^R
menutrans Rep&eat<Tab>\.		Lặ&p\ lại<Tab>\.
"--------------------
menutrans Cu&t<Tab>"+x			&Cắt<Tab>"+x
menutrans &Copy<Tab>"+y			&Sao\ chép<Tab>"+y
menutrans &Paste<Tab>"+gP		&Dán<Tab>"+gP
menutrans Put\ &Before<Tab>[p		Dán\ trướ&c<Tab>[p
menutrans Put\ &After<Tab>]p		Dán\ sa&u<Tab>]p
menutrans &Delete<Tab>x			&Xóa<Tab>x
menutrans &Select\ All<Tab>ggVG		Chọ&n\ tất\ cả<Tab>ggVG
"--------------------
menutrans &Find\.\.\.<Tab>/		&Tìm\ kiếm\.\.\.<Tab>/
menutrans Find\ and\ Rep&lace\.\.\.     Tìm\ kiếm\ &và\ thay\ thế\.\.\.
menutrans Find\ and\ Rep&lace\.\.\.<Tab>:%s     Tìm\ kiếm\ &và\ thay\ thế\.\.\.<Tab>:%s
menutrans Find\ and\ Rep&lace\.\.\.<Tab>:s     Tìm\ kiếm\ &và\ thay\ thế\.\.\<Tab>:s
"--------------------
menutrans Settings\ &Window		Cửa\ &sổ\ thiết\ lập
menutrans &Global\ Settings		Thiết\ lập\ t&oàn\ cầu
menutrans F&ile\ Settings		&Thiết\ lập\ tập\ t&in
menutrans C&olor\ Scheme		Phối\ hợp\ màu\ &sắc
menutrans &Keymap			Sơ\ đồ\ &bàn\ phím
menutrans Select\ Fo&nt\.\.\.		Chọn\ &phông\ chữ\.\.\.
">>>----------------- Edit/Global settings
menutrans Toggle\ Pattern\ &Highlight<Tab>:set\ hls!     &Chiếu\ sáng\ từ\ tìm\ thấy <Tab>:set\ hls!
menutrans Toggle\ &Ignore-case<Tab>:set\ ic!		 &Không\ tính\ đến\ kiểu\ chữ<Tab>:set\ ic!
menutrans Toggle\ &Showmatch<Tab>:set\ sm!		 Cho\ &biết\ phần\ tử\ có\ cặp<Tab>:set\ sm!
menutrans &Context\ lines				 Số\ &dòng\ quanh\ con\ trỏ
menutrans &Virtual\ Edit				 &Soạn\ thảo\ ảo
menutrans Toggle\ Insert\ &Mode<Tab>:set\ im!		 Chế\ độ\ chè&n<Tab>:set\ im!
menutrans Toggle\ Vi\ C&ompatible<Tab>:set\ cp!		 Tương\ thích\ với\ &Vi<Tab>:set\ cp!
menutrans Search\ &Path\.\.\.				 Đường\ dẫn\ tìm\ &kiếm\.\.\.
menutrans Ta&g\ Files\.\.\.				 Tập\ tin\ t&hẻ\ ghi\.\.\.
"
menutrans Toggle\ &Toolbar				 Ẩn/hiện\ th&anh\ công\ cụ
menutrans Toggle\ &Bottom\ Scrollbar		Ẩn/hiện\ thanh\ kéo\ nằ&m\ dưới
menutrans Toggle\ &Left\ Scrollbar			 Ẩn/hiện\ thanh\ ké&o\ bên\ trái
menutrans Toggle\ &Right\ Scrollbar			 Ẩn/hiện\ thanh\ kéo\ bên\ &phải
">>>->>>------------- Edit/Global settings/Virtual edit
menutrans Never						 Tắt
menutrans Block\ Selection				 Khi\ chọn\ khối
menutrans Insert\ mode					 Trong\ chế\ độ\ Chèn
menutrans Block\ and\ Insert				 Khi\ chọn\ khối\ và\ Chèn
menutrans Always					 Luôn\ luôn\ bật
">>>----------------- Edit/File settings
menutrans Toggle\ Line\ &Numbering<Tab>:set\ nu!	 Đánh\ &số\ dòng<Tab>:set\ nu!
menutrans Toggle\ &List\ Mode<Tab>:set\ list!		 &Chế\ độ\ danh\ sách<Tab>:set\ list!
menutrans Toggle\ Line\ &Wrap<Tab>:set\ wrap!		 &Ngắt\ những\ dòng\ dài<Tab>:set\ wrap!
menutrans Toggle\ W&rap\ at\ word<Tab>:set\ lbr!	 Ngắt\ từ\ nguyên\ &vẹn<Tab>:set\ lbr!
menutrans Toggle\ &expand-tab<Tab>:set\ et!		 &Dấu\ trắng\ thay\ cho\ tab<Tab>:set\ et!
menutrans Toggle\ &auto-indent<Tab>:set\ ai!		 &Tự\ động\ thụt\ dòng<Tab>:set\ ai!
menutrans Toggle\ &C-indenting<Tab>:set\ cin!		 T&hụt\ dòng\ kiểu\ C<Tab>:set\ cin!
">>>---
menutrans &Shiftwidth					 Chiều\ &rộng\ thụt\ dòng
menutrans Soft\ &Tabstop				 Chiều\ rộng\ T&ab
menutrans Te&xt\ Width\.\.\.				 Chiều\ rộng\ văn\ &bản\.\.\.
menutrans &File\ Format\.\.\.				 Định\ dạng\ tậ&p\ tin\.\.\.
">>>----------------- Edit/File settings/Color Scheme
menutrans default			Mặc\ định
">>>----------------- Edit/File settings/Keymap
menutrans None						Không\ dùng
menutrans arabic					Ả\ rập
menutrans czech						Séc
menutrans esperanto					Etperantô
menutrans greek						Hy\ Lạp
menutrans hebrew					Do\ thái
menutrans hebrewp					Do\ thái\ p
menutrans lithuania-baltic			Lát-vi\ Bal-tíc
menutrans magyar					Hungari
menutrans persian-iranian			Iran\ Ba\ Tư
menutrans persian					Ba\ Tư
menutrans russian-jcuken			Nga\ jcuken
menutrans russian-jcukenwin			Nga\ jcukenwin
menutrans russian-yawerty			Nga\ yawerty
menutrans serbian-latin				Xéc-bi\ La-tinh
menutrans serbian					Xéc-bi
menutrans slovak					slovak
"
"
"
" Tools menu
menutrans &Jump\ to\ this\ tag<Tab>g^]			&Nhảy\ tới\ thẻ\ ghi<Tab>g^]
menutrans Jump\ &back<Tab>^T				&Quay\ lại<Tab>^T
menutrans Build\ &Tags\ File				&Tạo\ tập\ tin\ thẻ\ ghi
"-------------------
menutrans &Folding					Nếp\ &gấp
menutrans &Diff						&Khác\ biệt (diff)
"-------------------
menutrans &Make<Tab>:make				&Biên\ dịch<Tab>:make
menutrans &List\ Errors<Tab>:cl				&Danh\ sách\ lỗi<Tab>:cl
menutrans L&ist\ Messages<Tab>:cl!			Danh\ &sách\ thông\ báo<Tab>:cl!
menutrans &Next\ Error<Tab>:cn				&Lỗi\ tiếp\ theo<Tab>:cn
menutrans &Previous\ Error<Tab>:cp			Lỗi\ t&rước<Tab>:cp
menutrans &Older\ List<Tab>:cold			Danh\ sách\ &cũ\ hơn<Tab>:cold
menutrans N&ewer\ List<Tab>:cnew			Danh\ sách\ &mới\ hơn<Tab>:cnew
menutrans Error\ &Window				Cử&a\ sổ\ lỗi
menutrans &Set\ Compiler				C&họn\ trình\ biên\ dịch
"-------------------
menutrans &Convert\ to\ HEX<Tab>:%!xxd			Ch&uyển\ thành\ HEX<Tab>:%!xxd
menutrans Conve&rt\ back<Tab>:%!xxd\ -r			Chuyển\ từ\ HE&X<Tab>:%!xxd\ -r
">>>---------------- Folds
menutrans &Enable/Disable\ folds<Tab>zi			&Bật/tắt\ nếp\ gấp<Tab>zi
menutrans &View\ Cursor\ Line<Tab>zv			&Xem\ dòng\ có\ con\ trỏ<Tab>zv
menutrans Vie&w\ Cursor\ Line\ only<Tab>zMzx		&Chỉ\ xem\ dòng\ có\ con\ trỏ<Tab>zMzx
menutrans C&lose\ more\ folds<Tab>zm			Đóng\ &nhiều\ nếp\ gấp\ hơn<Tab>zm
menutrans &Close\ all\ folds<Tab>zM			Đóng\ mọi\ nếp\ &gấp<Tab>zM
menutrans &Open\ all\ folds<Tab>zR			&Mở\ mọi\ nếp\ gấp<Tab>zR
menutrans O&pen\ more\ folds<Tab>zr			Mở\ n&hiều\ nếp\ gấp\ hơn<Tab>zr
menutrans Fold\ Met&hod					&Phương\ pháp\ gấp
menutrans Create\ &Fold<Tab>zf				&Tạo\ nếp\ gấp<Tab>zf
menutrans &Delete\ Fold<Tab>zd				Xó&a\ nếp\ gấp<Tab>zd
menutrans Delete\ &All\ Folds<Tab>zD			Xóa\ mọ&i\ nếp\ gấp<Tab>zD
menutrans Fold\ col&umn\ width				Chiều\ &rộng\ cột\ nếp\ gấp
">>>->>>----------- Tools/Folds/Fold Method
menutrans M&anual					&Thủ\ công
menutrans I&ndent					Thụt\ &dòng
menutrans E&xpression					&Biểu\ thức
menutrans S&yntax					&Cú\ pháp
menutrans Ma&rker					&Dấu\ hiệu
">>>--------------- Tools/Diff
menutrans &Update					&Cập\ nhật
menutrans &Get\ Block					&Thay\ đổi\ bộ\ đệm\ này
menutrans &Put\ Block					T&hay\ đổi\ bộ\ đệm\ khác
">>>--------------- Tools/Diff/Error window
menutrans &Update<Tab>:cwin				&Cập\ nhật<Tab>:cwin
menutrans &Close<Tab>:cclose				Đó&ng<Tab>:cclose
menutrans &Open<Tab>:copen				&Mở<Tab>:copen
"
"
" Syntax menu
"
menutrans &Show\ filetypes\ in\ menu			&Hiển\ thị\ loại\ tập\ tin\ trong\ trình\ đơn
menutrans Set\ '&syntax'\ only				&Chỉ\ thay\ đổi\ giá\ trị\ 'syntax'
menutrans Set\ '&filetype'\ too				Th&ay\ đổi\ cả\ giá\ trị\ 'filetype'
menutrans &Off						&Tắt
menutrans &Manual					&Bằng\ tay
menutrans A&utomatic					Tự\ độ&ng
menutrans on/off\ for\ &This\ file			Bật\ tắt\ &cho\ tập\ tin\ này
menutrans Co&lor\ test					&Kiểm\ tra\ màu\ sắc
menutrans &Highlight\ test				Kiểm\ tra\ chiếu\ &sáng
menutrans &Convert\ to\ HTML				&Chuyển\ thành\ HTML
">>>---------------- Syntax/AB
menutrans Apache\ config					Cấu\ hình\ Apache
menutrans Ant\ build\ file					Tập\ tin\ biên\ dịch\ Ant
menutrans Apache-style\ config				Cấu\ hình\ phong\ cách\ Apache
menutrans Arc\ Macro\ Language				Ngôn\ ngữ\ Macro\ Arc
menutrans Arch\ inventory					Kiểm\ kê\ Arch
menutrans ASP\ with\ VBScript				ASP\ với\ VBScript
menutrans ASP\ with\ Perl					ASP\ với\ Perl
menutrans BC\ calculator					Máy\ tính\ BC
menutrans BDF\ font							Phông\ chữ\ BDF
menutrans blank								không\ dùng
">>>---------------- Syntax/C
menutrans Calendar							Lịch
menutrans Cheetah\ template					Mẫu\ Cheetah
menutrans Config							Cấu\ hình
"
"
" Buffers menu
"
menutrans &Refresh\ menu				&Cập\ nhật\ trình\ đơn
menutrans Delete					&Xóa
menutrans &Alternate					Xen\ &kẽ
menutrans &Next						Tiế&p\ theo
menutrans &Previous					&Trước
menutrans [No\ File]					[Không\ có\ tập\ tin]
"
"
" Window menu
"
menutrans &New<Tab>^Wn					&Mới<Tab>^Wn
menutrans S&plit<Tab>^Ws				&Chia\ đôi<Tab>^Ws
menutrans Sp&lit\ To\ #<Tab>^W^^			Chia\ &tới\ #<Tab>^W^^
menutrans Split\ &Vertically<Tab>^Wv			Chia\ &dọc<Tab>^Wv
menutrans Split\ File\ E&xplorer			Mở\ trình\ &duyệt\ tập\ tin
"
menutrans &Close<Tab>^Wc				Đó&ng<Tab>^Wc
menutrans Close\ &Other(s)<Tab>^Wo			Đóng\ các\ cửa\ sổ\ &khác<Tab>^Wo
"
menutrans Move\ &To					C&huyển\ tới
menutrans Rotate\ &Up<Tab>^WR				&Lên\ trên<Tab>^WR
menutrans Rotate\ &Down<Tab>^Wr				&Xuống\ dưới<Tab>^Wr
"
menutrans &Equal\ Size<Tab>^W=				Cân\ &bằng\ kích\ thước<Tab>^W=
menutrans &Max\ Height<Tab>^W_				Chiều\ c&ao\ lớn\ nhất<Tab>^W_
menutrans M&in\ Height<Tab>^W1_				Chiều\ ca&o\ nhỏ\ nhất<Tab>^W1_
menutrans Max\ &Width<Tab>^W\|				Chiều\ &rộng\ lớn\ nhất<Tab>^W\|
menutrans Min\ Widt&h<Tab>^W1\|				Chiề&u\ rộng\ nhỏ\ nhất<Tab>^W1\|
">>>----------------- Window/Move To
menutrans &Top<Tab>^WK					Đầ&u<Tab>^WK
menutrans &Bottom<Tab>^WJ				&Cuối<Tab>^WJ
menutrans &Left\ side<Tab>^WH				&Trái<Tab>^WH
menutrans &Right\ side<Tab>^WL				&Phải<Tab>^WL
"
"
" The popup menu
"
"
menutrans &Undo						&Hủy\ bước
menutrans Cu&t						&Cắt
menutrans &Copy						&Sao\ chép
menutrans &Paste					&Dán
menutrans &Delete					&Xóa
menutrans Select\ Blockwise				Chọn\ &theo\ khối
menutrans Select\ &Word					Chọ&n\ từ
menutrans Select\ &Line					Chọn\ dòn&g
menutrans Select\ &Block				Chọn\ &khối
menutrans Select\ &All					Chọn\ tất\ &cả
"
" The GUI toolbar
"
if has("toolbar")
  if exists("*Do_toolbar_tmenu")
    delfun Do_toolbar_tmenu
  endif
  fun Do_toolbar_tmenu()
    tmenu ToolBar.Open					Mở tập tin
    tmenu ToolBar.Save					Ghi nhớ tập tin
    tmenu ToolBar.SaveAll				Ghi nhớ tất cả
    tmenu ToolBar.Print					In ra
    tmenu ToolBar.Undo					Hủy bước
    tmenu ToolBar.Redo					Làm lại
    tmenu ToolBar.Cut					Cắt
    tmenu ToolBar.Copy					Sao chép
    tmenu ToolBar.Paste					Dán
    tmenu ToolBar.Find					Tìm kiếm
    tmenu ToolBar.FindNext				Tìm tiếp theo
    tmenu ToolBar.FindPrev				Tìm ngược lại
    tmenu ToolBar.Replace				Thay thế...
    tmenu ToolBar.LoadSesn				Nạp buổi làm việc
    tmenu ToolBar.SaveSesn				Ghi nhớ buổi làm việc
    tmenu ToolBar.RunScript				Chạy script của Vim
    tmenu ToolBar.Make					Biên dịch
    tmenu ToolBar.Shell					Shell
    tmenu ToolBar.RunCtags				Tạo tập tin thẻ ghi
    tmenu ToolBar.TagJump				Chuyển tới thẻ ghi
    tmenu ToolBar.Help					Trợ giúp
    tmenu ToolBar.FindHelp				Tìm trong trợ giúp
  endfun
endif
"
"
" Dialog texts
"
" Find in help dialog
"
let g:menutrans_help_dialog = "Hãy nhập câu lệnh hoặc từ khóa tìm kiếm:\n\nThêm i_ để tìm kiếm câu lệnh của chế độ Nhập Input (Ví dụ, i_CTRL-X)\nThêm c_ để tìm kiếm câu lệnh của chế độ soạn thảo dòng lệnh (Ví dụ, с_<Del>)\nThêm ' để tìm kiếm trợ giúp cho một tùy chọn (ví dụ, 'shiftwidth')"
"
" Searh path dialog
"
let g:menutrans_path_dialog = "Hãy chỉ ra đường dẫn để tìm kiếm tập tin.\nTên của thư mục phân cách nhau bởi dấu phẩy."
"
" Tag files dialog
"
let g:menutrans_tags_dialog = "Nhập tên tập tin thẻ ghi (phân cách bởi dấu phẩy).\n"
"
" Text width dialog
"
let g:menutrans_textwidth_dialog = "Hãy nhập chiều rộng văn bản mới.\nNhập 0 để hủy bỏ."
"
" File format dialog
"
let g:menutrans_fileformat_dialog = "Hãy chọn định dạng tập tin."
let g:menutrans_fileformat_choices = "&Unix\n&Dos\n&Mac\n&Hủy bỏ"
"
let menutrans_no_file = "[không có tập tin]"

let &cpo = s:keepcpo
unlet s:keepcpo
