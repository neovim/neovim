#ifndef NEOVIM_CRYPT_H
#define NEOVIM_CRYPT_H

/// Returns the crypt method string as a number.
///
/// @param s Pointer to the crypt method string.
///
/// @return An integer value of the crypt method:
///         0 for "zip", the old method. Also for any non-valid value.
///         1 for "blowfish".
int crypt_method_from_string(char_u *s);

/// Returns the crypt method of the buffer "buf" as a number.
///
/// @param buf Pointer to the buffer.
///
/// @return An integer value of the crypt method:
///         0 for "zip", the old method. Also for any non-valid value.
///         1 for "blowfish".
int get_crypt_method(buf_T *buf);

/// Sets the crypt method for buffer "buf" to "method" using the
/// int value as returned by crypt_method_from_string().
///
/// @param buf Pointer to the buffer.
/// @param method Crypt method.
void set_crypt_method(buf_T *buf, int method);

/// Prepares for initializing the encryption. If already doing encryption,
/// then save the state.
///
/// This function must always be called symmetrically with crypt_pop_state().
void crypt_push_state(void);

/// Ends encryption. If already doing encryption before crypt_push_state(),
/// then restore the saved state.
///
/// This function must always be called symmetrically with crypt_push_state().
void crypt_pop_state(void);

/// Encrypts "from[len]" into "to[len]".
/// For in-place encryption, "from" and "len" must be the same.
///
/// @param from Pointer to the source string.
/// @param len Length of the strings.
/// @param to Pointer to the destination string.
void crypt_encode(char_u *from, size_t len, char_u *to);

/// Decrypts "ptr[len]" in-place.
///
/// @param ptr Pointer to the string.
/// @param len Length of the string.
void crypt_decode(char_u *ptr, long len);

/// Initializes the encryption keys and the random header according to
/// the given password.
///
/// If "password" is NULL or empty, the function doesn't do anything.
///
/// @param passwd The password string with which to modify keys.
void crypt_init_keys(char_u *passwd);

/// Frees an allocated crypt key and clears the text to make sure
/// nothing stays in memory.
///
/// @param key The crypt key to be freed.
void free_crypt_key(char_u *key);

/// Asks the user for the crypt key.
///
/// When "store" is TRUE, the new key is stored in the 'key' option
/// and the 'key' option value is returned, which MUST NOT be freed
/// manually, but using free_crypt_key().
/// When "store" is FALSE, the typed key is returned in allocated memory.
///
/// @param store Determines, whether the new crypt key is stored.
/// @param twice Ask for the key twice.
///
/// @return The crypt key. On failure, NULL is returned.
char_u *get_crypt_key(int store, int twice);

#endif // NEOVIM_CRYPT_H
