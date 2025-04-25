/// Deletes a buffer
///
/// @param buffer Buffer handle, or 0 for current buffer
/// @param opts Optional parameters
///         - force: Force deletion of the buffer, discarding unsaved changes
///                  (defaults to false)
///         - wipeout: Wipe out the buffer (like :bwipeout) instead of just deleting it
///                   (like :bdelete). Defaults to true for backward compatibility.
///                   When false, buffer marks are preserved.
///                   WARNING: Setting wipeout=true can cause data loss for marks stored in shada.
/// @param[out] err Error details, if any
void nvim_buf_delete(Buffer buffer, Dict(buffer_delete) *opts, Error *err)
{
  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (!buf) {
    return;
  }

  bool force = false;
  bool wipeout = true;

  if (opts) {
    force = opts->force;
    if (HAS_KEY(opts, wipeout)) {
      wipeout = opts->wipeout;
    }
  }

  int result;
  if (wipeout) {
    result = do_buffer(DOBUF_WIPE, DOBUF_FIRST, FORWARD, buf->b_fnum, force);
  } else {
    result = do_buffer(DOBUF_DEL, DOBUF_FIRST, FORWARD, buf->b_fnum, force);
  }

  if (result == FAIL) {
    api_set_error(err, kErrorTypeException, "Failed to delete buffer");
  }
}
