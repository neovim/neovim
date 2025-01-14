#include "nvim/vterm/encoding.h"
#include "nvim/vterm/vterm_internal_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "vterm/encoding.c.generated.h"
#endif

#define UNICODE_INVALID 0xFFFD

#if defined(DEBUG) && DEBUG > 1
# define DEBUG_PRINT_UTF8
#endif

struct UTF8DecoderData {
  // number of bytes remaining in this codepoint
  int bytes_remaining;

  // number of bytes total in this codepoint once it's finished
  // (for detecting overlongs)
  int bytes_total;

  int this_cp;
};

static void init_utf8(VTermEncoding *enc, void *data_)
{
  struct UTF8DecoderData *data = data_;

  data->bytes_remaining = 0;
  data->bytes_total = 0;
}

static void decode_utf8(VTermEncoding *enc, void *data_, uint32_t cp[], int *cpi, int cplen,
                        const char bytes[], size_t *pos, size_t bytelen)
{
  struct UTF8DecoderData *data = data_;

#ifdef DEBUG_PRINT_UTF8
  printf("BEGIN UTF-8\n");
#endif

  for (; *pos < bytelen && *cpi < cplen; (*pos)++) {
    uint8_t c = (uint8_t)bytes[*pos];

#ifdef DEBUG_PRINT_UTF8
    printf(" pos=%zd c=%02x rem=%d\n", *pos, c, data->bytes_remaining);
#endif

    if (c < 0x20) {  // C0
      return;
    } else if (c >= 0x20 && c < 0x7f) {
      if (data->bytes_remaining) {
        cp[(*cpi)++] = UNICODE_INVALID;
      }

      cp[(*cpi)++] = c;
#ifdef DEBUG_PRINT_UTF8
      printf(" UTF-8 char: U+%04x\n", c);
#endif
      data->bytes_remaining = 0;
    } else if (c == 0x7f) {  // DEL
      return;
    } else if (c >= 0x80 && c < 0xc0) {
      if (!data->bytes_remaining) {
        cp[(*cpi)++] = UNICODE_INVALID;
        continue;
      }

      data->this_cp <<= 6;
      data->this_cp |= c & 0x3f;
      data->bytes_remaining--;

      if (!data->bytes_remaining) {
#ifdef DEBUG_PRINT_UTF8
        printf(" UTF-8 raw char U+%04x bytelen=%d ", data->this_cp, data->bytes_total);
#endif
        // Check for overlong sequences
        switch (data->bytes_total) {
        case 2:
          if (data->this_cp < 0x0080) {
            data->this_cp = UNICODE_INVALID;
          }
          break;
        case 3:
          if (data->this_cp < 0x0800) {
            data->this_cp = UNICODE_INVALID;
          }
          break;
        case 4:
          if (data->this_cp < 0x10000) {
            data->this_cp = UNICODE_INVALID;
          }
          break;
        case 5:
          if (data->this_cp < 0x200000) {
            data->this_cp = UNICODE_INVALID;
          }
          break;
        case 6:
          if (data->this_cp < 0x4000000) {
            data->this_cp = UNICODE_INVALID;
          }
          break;
        }
        // Now look for plain invalid ones
        if ((data->this_cp >= 0xD800 && data->this_cp <= 0xDFFF)
            || data->this_cp == 0xFFFE
            || data->this_cp == 0xFFFF) {
          data->this_cp = UNICODE_INVALID;
        }
#ifdef DEBUG_PRINT_UTF8
        printf(" char: U+%04x\n", data->this_cp);
#endif
        cp[(*cpi)++] = (uint32_t)data->this_cp;
      }
    } else if (c >= 0xc0 && c < 0xe0) {
      if (data->bytes_remaining) {
        cp[(*cpi)++] = UNICODE_INVALID;
      }

      data->this_cp = c & 0x1f;
      data->bytes_total = 2;
      data->bytes_remaining = 1;
    } else if (c >= 0xe0 && c < 0xf0) {
      if (data->bytes_remaining) {
        cp[(*cpi)++] = UNICODE_INVALID;
      }

      data->this_cp = c & 0x0f;
      data->bytes_total = 3;
      data->bytes_remaining = 2;
    } else if (c >= 0xf0 && c < 0xf8) {
      if (data->bytes_remaining) {
        cp[(*cpi)++] = UNICODE_INVALID;
      }

      data->this_cp = c & 0x07;
      data->bytes_total = 4;
      data->bytes_remaining = 3;
    } else if (c >= 0xf8 && c < 0xfc) {
      if (data->bytes_remaining) {
        cp[(*cpi)++] = UNICODE_INVALID;
      }

      data->this_cp = c & 0x03;
      data->bytes_total = 5;
      data->bytes_remaining = 4;
    } else if (c >= 0xfc && c < 0xfe) {
      if (data->bytes_remaining) {
        cp[(*cpi)++] = UNICODE_INVALID;
      }

      data->this_cp = c & 0x01;
      data->bytes_total = 6;
      data->bytes_remaining = 5;
    } else {
      cp[(*cpi)++] = UNICODE_INVALID;
    }
  }
}

static VTermEncoding encoding_utf8 = {
  .init = &init_utf8,
  .decode = &decode_utf8,
};

static void decode_usascii(VTermEncoding *enc, void *data, uint32_t cp[], int *cpi, int cplen,
                           const char bytes[], size_t *pos, size_t bytelen)
{
  int is_gr = bytes[*pos] & 0x80;

  for (; *pos < bytelen && *cpi < cplen; (*pos)++) {
    uint8_t c = (uint8_t)(bytes[*pos] ^ is_gr);

    if (c < 0x20 || c == 0x7f || c >= 0x80) {
      return;
    }

    cp[(*cpi)++] = c;
  }
}

static VTermEncoding encoding_usascii = {
  .decode = &decode_usascii,
};

struct StaticTableEncoding {
  const VTermEncoding enc;
  const uint32_t chars[128];
};

static void decode_table(VTermEncoding *enc, void *data, uint32_t cp[], int *cpi, int cplen,
                         const char bytes[], size_t *pos, size_t bytelen)
{
  struct StaticTableEncoding *table = (struct StaticTableEncoding *)enc;
  int is_gr = bytes[*pos] & 0x80;

  for (; *pos < bytelen && *cpi < cplen; (*pos)++) {
    uint8_t c = (uint8_t)(bytes[*pos] ^ is_gr);

    if (c < 0x20 || c == 0x7f || c >= 0x80) {
      return;
    }

    if (table->chars[c]) {
      cp[(*cpi)++] = table->chars[c];
    } else {
      cp[(*cpi)++] = c;
    }
  }
}

// https://en.wikipedia.org/wiki/DEC_Special_Graphics
static const struct StaticTableEncoding encoding_DECdrawing = {
  { .decode = &decode_table },
  {
    [0x60] = 0x25C6,  // BLACK DIAMOND
    [0x61] = 0x2592,  // MEDIUM SHADE (checkerboard)
    [0x62] = 0x2409,  // SYMBOL FOR HORIZONTAL TAB
    [0x63] = 0x240C,  // SYMBOL FOR FORM FEED
    [0x64] = 0x240D,  // SYMBOL FOR CARRIAGE RETURN
    [0x65] = 0x240A,  // SYMBOL FOR LINE FEED
    [0x66] = 0x00B0,  // DEGREE SIGN
    [0x67] = 0x00B1,  // PLUS-MINUS SIGN (plus or minus)
    [0x68] = 0x2424,  // SYMBOL FOR NEW LINE
    [0x69] = 0x240B,  // SYMBOL FOR VERTICAL TAB
    [0x6a] = 0x2518,  // BOX DRAWINGS LIGHT UP AND LEFT (bottom-right corner)
    [0x6b] = 0x2510,  // BOX DRAWINGS LIGHT DOWN AND LEFT (top-right corner)
    [0x6c] = 0x250C,  // BOX DRAWINGS LIGHT DOWN AND RIGHT (top-left corner)
    [0x6d] = 0x2514,  // BOX DRAWINGS LIGHT UP AND RIGHT (bottom-left corner)
    [0x6e] = 0x253C,  // BOX DRAWINGS LIGHT VERTICAL AND HORIZONTAL (crossing lines)
    [0x6f] = 0x23BA,  // HORIZONTAL SCAN LINE-1
    [0x70] = 0x23BB,  // HORIZONTAL SCAN LINE-3
    [0x71] = 0x2500,  // BOX DRAWINGS LIGHT HORIZONTAL
    [0x72] = 0x23BC,  // HORIZONTAL SCAN LINE-7
    [0x73] = 0x23BD,  // HORIZONTAL SCAN LINE-9
    [0x74] = 0x251C,  // BOX DRAWINGS LIGHT VERTICAL AND RIGHT
    [0x75] = 0x2524,  // BOX DRAWINGS LIGHT VERTICAL AND LEFT
    [0x76] = 0x2534,  // BOX DRAWINGS LIGHT UP AND HORIZONTAL
    [0x77] = 0x252C,  // BOX DRAWINGS LIGHT DOWN AND HORIZONTAL
    [0x78] = 0x2502,  // BOX DRAWINGS LIGHT VERTICAL
    [0x79] = 0x2A7D,  // LESS-THAN OR SLANTED EQUAL-TO
    [0x7a] = 0x2A7E,  // GREATER-THAN OR SLANTED EQUAL-TO
    [0x7b] = 0x03C0,  // GREEK SMALL LETTER PI
    [0x7c] = 0x2260,  // NOT EQUAL TO
    [0x7d] = 0x00A3,  // POUND SIGN
    [0x7e] = 0x00B7,  // MIDDLE DOT
  }
};

static struct {
  VTermEncodingType type;
  char designation;
  VTermEncoding *enc;
}
encodings[] = {
  { ENC_UTF8,      'u', &encoding_utf8 },
  { ENC_SINGLE_94, '0', (VTermEncoding *)&encoding_DECdrawing },
  { ENC_SINGLE_94, 'B', &encoding_usascii },
  { 0 },
};

VTermEncoding *vterm_lookup_encoding(VTermEncodingType type, char designation)
{
  for (int i = 0; encodings[i].designation; i++) {
    if (encodings[i].type == type && encodings[i].designation == designation) {
      return encodings[i].enc;
    }
  }
  return NULL;
}
