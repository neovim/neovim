#ifndef NVIM_MBYTE_H
#define NVIM_MBYTE_H

/*
 * Return byte length of character that starts with byte "b".
 * Returns 1 for a single-byte character.
 * MB_BYTE2LEN_CHECK() can be used to count a special key as one byte.
 * Don't call MB_BYTE2LEN(b) with b < 0 or b > 255!
 */
# define MB_BYTE2LEN(b)         mb_bytelen_tab[b]
# define MB_BYTE2LEN_CHECK(b)   (((b) < 0 || (b) > 255) ? 1 : mb_bytelen_tab[b])

/* properties used in enc_canon_table[] (first three mutually exclusive) */
# define ENC_8BIT       0x01
# define ENC_DBCS       0x02
# define ENC_UNICODE    0x04

# define ENC_ENDIAN_B   0x10        /* Unicode: Big endian */
# define ENC_ENDIAN_L   0x20        /* Unicode: Little endian */

# define ENC_2BYTE      0x40        /* Unicode: UCS-2 */
# define ENC_4BYTE      0x80        /* Unicode: UCS-4 */
# define ENC_2WORD      0x100       /* Unicode: UTF-16 */

# define ENC_LATIN1     0x200       /* Latin1 */
# define ENC_LATIN9     0x400       /* Latin9 */
# define ENC_MACROMAN   0x800       /* Mac Roman (not Macro Man! :-) */

/* mbyte.c */
int enc_canon_props(char_u *name);
char_u *mb_init(void);
int bomb_size(void);
void remove_bom(char_u *s);
int mb_get_class(char_u *p);
int mb_get_class_buf(char_u *p, buf_T *buf);
int dbcs_class(unsigned lead, unsigned trail);
int latin_char2len(int c);
int latin_char2bytes(int c, char_u *buf);
int latin_ptr2len(char_u *p);
int latin_ptr2len_len(char_u *p, int size);
int utf_char2cells(int c);
int latin_ptr2cells(char_u *p);
int utf_ptr2cells(char_u *p);
int dbcs_ptr2cells(char_u *p);
int latin_ptr2cells_len(char_u *p, int size);
int latin_char2cells(int c);
int mb_string2cells(char_u *p, int len);
int latin_off2cells(unsigned off, unsigned max_off);
int dbcs_off2cells(unsigned off, unsigned max_off);
int utf_off2cells(unsigned off, unsigned max_off);
int latin_ptr2char(char_u *p);
int utf_ptr2char(char_u *p);
int mb_ptr2char_adv(char_u **pp);
int mb_cptr2char_adv(char_u **pp);
int arabic_combine(int one, int two);
int arabic_maycombine(int two);
int utf_composinglike(char_u *p1, char_u *p2);
int utfc_ptr2char(char_u *p, int *pcc);
int utfc_ptr2char_len(char_u *p, int *pcc, int maxlen);
int utfc_char2bytes(int off, char_u *buf);
int utf_ptr2len(char_u *p);
int utf_byte2len(int b);
int utf_ptr2len_len(char_u *p, int size);
int utfc_ptr2len(char_u *p);
int utfc_ptr2len_len(char_u *p, int size);
int utf_char2len(int c);
int utf_char2bytes(int c, char_u *buf);
int utf_iscomposing(int c);
int utf_printable(int c);
int utf_class(int c);
int utf_fold(int a);
int utf_toupper(int a);
int utf_islower(int a);
int utf_tolower(int a);
int utf_isupper(int a);
int mb_strnicmp(char_u *s1, char_u *s2, size_t nn);
void show_utf8(void);
int latin_head_off(char_u *base, char_u *p);
int dbcs_head_off(char_u *base, char_u *p);
int dbcs_screen_head_off(char_u *base, char_u *p);
int utf_head_off(char_u *base, char_u *p);
void mb_copy_char(char_u **fp, char_u **tp);
int mb_off_next(char_u *base, char_u *p);
int mb_tail_off(char_u *base, char_u *p);
void utf_find_illegal(void);
void mb_adjust_cursor(void);
void mb_adjustpos(buf_T *buf, pos_T *lp);
char_u *mb_prevptr(char_u *line, char_u *p);
int mb_charlen(char_u *str);
int mb_charlen_len(char_u *str, int len);
char_u *mb_unescape(char_u **pp);
int mb_lefthalve(int row, int col);
int mb_fix_col(int col, int row);
char_u *enc_skip(char_u *p);
char_u *enc_canonize(char_u *enc);
char_u *enc_locale(void);
void *my_iconv_open(char_u *to, char_u *from);
int iconv_enabled(int verbose);
void iconv_end(void);
void im_set_active(int active);
int im_get_status(void);
int convert_setup(vimconv_T *vcp, char_u *from, char_u *to);
int convert_setup_ext(vimconv_T *vcp, char_u *from,
                      int from_unicode_is_utf8, char_u *to,
                      int to_unicode_is_utf8);
int convert_input(char_u *ptr, int len, int maxlen);
int convert_input_safe(char_u *ptr, int len, int maxlen, char_u **restp,
                       int *restlenp);
char_u *string_convert(vimconv_T *vcp, char_u *ptr, int *lenp);
char_u *string_convert_ext(vimconv_T *vcp, char_u *ptr, int *lenp,
                           int *unconvlenp);

#endif /* NVIM_MBYTE_H */
