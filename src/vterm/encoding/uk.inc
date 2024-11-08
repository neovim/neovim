static const struct StaticTableEncoding encoding_uk = {
  { .decode = &decode_table },
  {
    [0x23] = 0x00a3,  // £
  }
};
