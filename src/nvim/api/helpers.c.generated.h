static void set_option_value_err(char *key,
                                 int numval,
                                 char *stringval,
                                 int opt_flags,
                                 Error *err);
static void set_option_value_for(char *key,
                                 int numval,
                                 char *stringval,
                                 int opt_flags,
                                 int opt_type,
                                 void *from,
                                 Error *err);
static bool object_to_vim(Object obj, typval_T *tv, Error *err);
static Object vim_to_object_rec(typval_T *obj, khash_t(Lookup) *lookup);
KHASH_INIT(Lookup, uintptr_t, char, 0, ptr_hash_func, kh_int_hash_equal)

/// Recursion helper for the `vim_to_object`. This uses a pointer table
/// to avoid infinite recursion due to cyclic references
///
/// @param obj The source object
static void set_option_value_err(char *key,
                                 int numval,
                                 char *stringval,
                                 int opt_flags,
                                 Error *err);
static void set_option_value_for(char *key,
                                 int numval,
                                 char *stringval,
                                 int opt_flags,
                                 int opt_type,
                                 void *from,
                                 Error *err);
static bool object_to_vim(Object obj, typval_T *tv, Error *err);
static Object vim_to_object_rec(typval_T *obj, khash_t(Lookup) *lookup);
KHASH_INIT(Lookup, uintptr_t, char, 0, ptr_hash_func, kh_int_hash_equal)





