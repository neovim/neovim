#include <assert.h>
#include <ctype.h>
#include "cwalk.h"
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

/**
 * We try to default to a different path style depending on the operating
 * system. So this should detect whether we should use windows or unix paths.
 */
#if defined(WIN32) || defined(_WIN32) ||                                       \
  defined(__WIN32) && !defined(__CYGWIN__)
static enum cwk_path_style path_style = CWK_STYLE_WINDOWS;
#else
static enum cwk_path_style path_style = CWK_STYLE_UNIX;
#endif

/**
 * This is a list of separators used in different styles. Windows can read
 * multiple separators, but it generally outputs just a backslash. The output
 * will always use the first character for the output.
 */
static const char *separators[] = {
  "\\/", // CWK_STYLE_WINDOWS
  "/"    // CWK_STYLE_UNIX
};

/**
 * A joined path represents multiple path strings which are concatenated, but
 * not (necessarily) stored in contiguous memory. The joined path allows to
 * iterate over the segments as if it was one piece of path.
 */
struct cwk_segment_joined
{
  struct cwk_segment segment;
  const char **paths;
  size_t path_index;
};

static size_t cwk_path_output_sized(char *buffer, size_t buffer_size,
  size_t position, const char *str, size_t length)
{
  size_t amount_written;

  // First we determine the amount which we can write to the buffer. There are
  // three cases. In the first case we have enough to store the whole string in
  // it. In the second one we can only store a part of it, and in the third we
  // have no space left.
  if (buffer_size > position + length) {
    amount_written = length;
  } else if (buffer_size > position) {
    amount_written = buffer_size - position;
  } else {
    amount_written = 0;
  }

  // If we actually want to write out something we will do that here. We will
  // always append a '\0', this way we are guaranteed to have a valid string at
  // all times.
  if (amount_written > 0) {
    memmove(&buffer[position], str, amount_written);
  }

  // Return the theoretical length which would have been written when everything
  // would have fit in the buffer.
  return length;
}

static size_t cwk_path_output_current(char *buffer, size_t buffer_size,
  size_t position)
{
  // We output a "current" directory, which is a single character. This
  // character is currently not style dependant.
  return cwk_path_output_sized(buffer, buffer_size, position, ".", 1);
}

static size_t cwk_path_output_back(char *buffer, size_t buffer_size,
  size_t position)
{
  // We output a "back" directory, which ahs two characters. This
  // character is currently not style dependant.
  return cwk_path_output_sized(buffer, buffer_size, position, "..", 2);
}

static size_t cwk_path_output_separator(char *buffer, size_t buffer_size,
  size_t position)
{
  // We output a separator, which is a single character.
  return cwk_path_output_sized(buffer, buffer_size, position,
    separators[path_style], 1);
}

static size_t cwk_path_output_dot(char *buffer, size_t buffer_size,
  size_t position)
{
  // We output a dot, which is a single character. This is used for extensions.
  return cwk_path_output_sized(buffer, buffer_size, position, ".", 1);
}

static size_t cwk_path_output(char *buffer, size_t buffer_size, size_t position,
  const char *str)
{
  size_t length;

  // This just does a sized output internally, but first measuring the
  // null-terminated string.
  length = strlen(str);
  return cwk_path_output_sized(buffer, buffer_size, position, str, length);
}

static void cwk_path_terminate_output(char *buffer, size_t buffer_size,
  size_t pos)
{
  if (buffer_size > 0) {
    if (pos >= buffer_size) {
      buffer[buffer_size - 1] = '\0';
    } else {
      buffer[pos] = '\0';
    }
  }
}

static bool cwk_path_is_string_equal(const char *first, const char *second,
  size_t first_size, size_t second_size)
{
  bool are_both_separators;

  // The two strings are not equal if the sizes are not equal.
  if (first_size != second_size) {
    return false;
  }

  // If the path style is UNIX, we will compare case sensitively. This can be
  // done easily using strncmp.
  if (path_style == CWK_STYLE_UNIX) {
    return strncmp(first, second, first_size) == 0;
  }

  // However, if this is windows we will have to compare case insensitively.
  // Since there is no standard method to do that we will have to do it on our
  // own.
  while (*first && *second && first_size > 0) {
    // We can consider the string to be not equal if the two lowercase
    // characters are not equal. The two chars may also be separators, which
    // means they would be equal.
    are_both_separators = strchr(separators[path_style], *first) != NULL &&
                          strchr(separators[path_style], *second) != NULL;

    if (tolower(*first) != tolower(*second) && !are_both_separators) {
      return false;
    }

    first++;
    second++;

    --first_size;
  }

  // The string must be equal since they both have the same length and all the
  // characters are the same.
  return true;
}

static const char *cwk_path_find_next_stop(const char *c)
{
  // We just move forward until we find a '\0' or a separator, which will be our
  // next "stop".
  while (*c != '\0' && !cwk_path_is_separator(c)) {
    ++c;
  }

  // Return the pointer of the next stop.
  return c;
}

static const char *cwk_path_find_previous_stop(const char *begin, const char *c)
{
  // We just move back until we find a separator or reach the beginning of the
  // path, which will be our previous "stop".
  while (c > begin && !cwk_path_is_separator(c)) {
    --c;
  }

  // Return the pointer to the previous stop. We have to return the first
  // character after the separator, not on the separator itself.
  if (cwk_path_is_separator(c)) {
    return c + 1;
  } else {
    return c;
  }
}

static bool cwk_path_get_first_segment_without_root(const char *path,
  const char *segments, struct cwk_segment *segment)
{
  // Let's remember the path. We will move the path pointer afterwards, that's
  // why this has to be done first.
  segment->path = path;
  segment->segments = segments;
  segment->begin = segments;
  segment->end = segments;
  segment->size = 0;

  // Now let's check whether this is an empty string. An empty string has no
  // segment it could use.
  if (*segments == '\0') {
    return false;
  }

  // If the string starts with separators, we will jump over those. If there is
  // only a slash and a '\0' after it, we can't determine the first segment
  // since there is none.
  while (cwk_path_is_separator(segments)) {
    ++segments;
    if (*segments == '\0') {
      return false;
    }
  }

  // So this is the beginning of our segment.
  segment->begin = segments;

  // Now let's determine the end of the segment, which we do by moving the path
  // pointer further until we find a separator.
  segments = cwk_path_find_next_stop(segments);

  // And finally, calculate the size of the segment by subtracting the position
  // from the end.
  segment->size = (size_t)(segments - segment->begin);
  segment->end = segments;

  // Tell the caller that we found a segment.
  return true;
}

static bool cwk_path_get_last_segment_without_root(const char *path,
  struct cwk_segment *segment)
{
  // Now this is fairly similar to the normal algorithm, however, it will assume
  // that there is no root in the path. So we grab the first segment at this
  // position, assuming there is no root.
  if (!cwk_path_get_first_segment_without_root(path, path, segment)) {
    return false;
  }

  // Now we find our last segment. The segment struct of the caller
  // will contain the last segment, since the function we call here will not
  // change the segment struct when it reaches the end.
  while (cwk_path_get_next_segment(segment)) {
    // We just loop until there is no other segment left.
  }

  return true;
}

static bool cwk_path_get_first_segment_joined(const char **paths,
  struct cwk_segment_joined *sj)
{
  bool result;

  // Prepare the first segment. We position the joined segment on the first path
  // and assign the path array to the struct.
  sj->path_index = 0;
  sj->paths = paths;

  // We loop through all paths until we find one which has a segment. The result
  // is stored in a variable, so we can let the caller know whether we found one
  // or not.
  result = false;
  while (paths[sj->path_index] != NULL &&
         (result = cwk_path_get_first_segment(paths[sj->path_index],
            &sj->segment)) == false) {
    ++sj->path_index;
  }

  return result;
}

static bool cwk_path_get_next_segment_joined(struct cwk_segment_joined *sj)
{
  bool result;

  if (sj->paths[sj->path_index] == NULL) {
    // We reached already the end of all paths, so there is no other segment
    // left.
    return false;
  } else if (cwk_path_get_next_segment(&sj->segment)) {
    // There was another segment on the current path, so we are good to
    // continue.
    return true;
  }

  // We try to move to the next path which has a segment available. We must at
  // least move one further since the current path reached the end.
  result = false;

  do {
    ++sj->path_index;

    // And we obviously have to stop this loop if there are no more paths left.
    if (sj->paths[sj->path_index] == NULL) {
      break;
    }

    // Grab the first segment of the next path and determine whether this path
    // has anything useful in it. There is one more thing we have to consider
    // here - for the first time we do this we want to skip the root, but
    // afterwards we will consider that to be part of the segments.
    result = cwk_path_get_first_segment_without_root(sj->paths[sj->path_index],
      sj->paths[sj->path_index], &sj->segment);

  } while (!result);

  // Finally, report the result back to the caller.
  return result;
}

static bool cwk_path_get_previous_segment_joined(struct cwk_segment_joined *sj)
{
  bool result;

  if (*sj->paths == NULL) {
    // It's possible that there is no initialized segment available in the
    // struct since there are no paths. In that case we can return false, since
    // there is no previous segment.
    return false;
  } else if (cwk_path_get_previous_segment(&sj->segment)) {
    // Now we try to get the previous segment from the current path. If we can
    // do that successfully, we can let the caller know that we found one.
    return true;
  }

  result = false;

  do {
    // We are done once we reached index 0. In that case there are no more
    // segments left.
    if (sj->path_index == 0) {
      break;
    }

    // There is another path which we have to inspect. So we decrease the path
    // index.
    --sj->path_index;

    // If this is the first path we will have to consider that this path might
    // include a root, otherwise we just treat is as a segment.
    if (sj->path_index == 0) {
      result = cwk_path_get_last_segment(sj->paths[sj->path_index],
        &sj->segment);
    } else {
      result = cwk_path_get_last_segment_without_root(sj->paths[sj->path_index],
        &sj->segment);
    }

  } while (!result);

  return result;
}

static bool cwk_path_segment_back_will_be_removed(struct cwk_segment_joined *sj)
{
  enum cwk_segment_type type;
  int counter;

  // We are handling back segments here. We must verify how many back segments
  // and how many normal segments come before this one to decide whether we keep
  // or remove it.

  // The counter determines how many normal segments are our current segment,
  // which will popped off before us. If the counter goes above zero it means
  // that our segment will be popped as well.
  counter = 0;

  // We loop over all previous segments until we either reach the beginning,
  // which means our segment will not be dropped or the counter goes above zero.
  while (cwk_path_get_previous_segment_joined(sj)) {

    // Now grab the type. The type determines whether we will increase or
    // decrease the counter. We don't handle a CWK_CURRENT frame here since it
    // has no influence.
    type = cwk_path_get_segment_type(&sj->segment);
    if (type == CWK_NORMAL) {
      // This is a normal segment. The normal segment will increase the counter
      // since it neutralizes one back segment. If we go above zero we can
      // return immediately.
      ++counter;
      if (counter > 0) {
        return true;
      }
    } else if (type == CWK_BACK) {
      // A CWK_BACK segment will reduce the counter by one. We can not remove a
      // back segment as long we are not above zero since we don't have the
      // opposite normal segment which we would remove.
      --counter;
    }
  }

  // We never got a count larger than zero, so we will keep this segment alive.
  return false;
}

static bool cwk_path_segment_normal_will_be_removed(
  struct cwk_segment_joined *sj)
{
  enum cwk_segment_type type;
  int counter;

  // The counter determines how many segments are above our current segment,
  // which will popped off before us. If the counter goes below zero it means
  // that our segment will be popped as well.
  counter = 0;

  // We loop over all following segments until we either reach the end, which
  // means our segment will not be dropped or the counter goes below zero.
  while (cwk_path_get_next_segment_joined(sj)) {

    // First, grab the type. The type determines whether we will increase or
    // decrease the counter. We don't handle a CWK_CURRENT frame here since it
    // has no influence.
    type = cwk_path_get_segment_type(&sj->segment);
    if (type == CWK_NORMAL) {
      // This is a normal segment. The normal segment will increase the counter
      // since it will be removed by a "../" before us.
      ++counter;
    } else if (type == CWK_BACK) {
      // A CWK_BACK segment will reduce the counter by one. If we are below zero
      // we can return immediately.
      --counter;
      if (counter < 0) {
        return true;
      }
    }
  }

  // We never got a negative count, so we will keep this segment alive.
  return false;
}

static bool
cwk_path_segment_will_be_removed(const struct cwk_segment_joined *sj,
  bool absolute)
{
  enum cwk_segment_type type;
  struct cwk_segment_joined sjc;

  // We copy the joined path so we don't need to modify it.
  sjc = *sj;

  // First we check whether this is a CWK_CURRENT or CWK_BACK segment, since
  // those will always be dropped.
  type = cwk_path_get_segment_type(&sj->segment);
  if (type == CWK_CURRENT || (type == CWK_BACK && absolute)) {
    return true;
  } else if (type == CWK_BACK) {
    return cwk_path_segment_back_will_be_removed(&sjc);
  } else {
    return cwk_path_segment_normal_will_be_removed(&sjc);
  }
}

static bool
cwk_path_segment_joined_skip_invisible(struct cwk_segment_joined *sj,
  bool absolute)
{
  while (cwk_path_segment_will_be_removed(sj, absolute)) {
    if (!cwk_path_get_next_segment_joined(sj)) {
      return false;
    }
  }

  return true;
}

static void cwk_path_get_root_windows(const char *path, size_t *length)
{
  const char *c;
  bool is_device_path;

  // We can not determine the root if this is an empty string. So we set the
  // root to NULL and the length to zero and cancel the whole thing.
  c = path;
  *length = 0;
  if (!*c) {
    return;
  }

  // Now we have to verify whether this is a windows network path (UNC), which
  // we will consider our root.
  if (cwk_path_is_separator(c)) {
    ++c;

    // Check whether the path starts with a single backslash, which means this
    // is not a network path - just a normal path starting with a backslash.
    if (!cwk_path_is_separator(c)) {
      // Okay, this is not a network path but we still use the backslash as a
      // root.
      ++(*length);
      return;
    }

    // A device path is a path which starts with "\\." or "\\?". A device path
    // can be a UNC path as well, in which case it will take up one more
    // segment. So, this is a network or device path. Skip the previous
    // separator. Now we need to determine whether this is a device path. We
    // might advance one character here if the server name starts with a '?' or
    // a '.', but that's fine since we will search for a separator afterwards
    // anyway.
    ++c;
    is_device_path = (*c == '?' || *c == '.') && cwk_path_is_separator(++c);
    if (is_device_path) {
      // That's a device path, and the root must be either "\\.\" or "\\?\"
      // which is 4 characters long. (at least that's how Windows
      // GetFullPathName behaves.)
      *length = 4;
      return;
    }

    // We will grab anything up to the next stop. The next stop might be a '\0'
    // or another separator. That will be the server name.
    c = cwk_path_find_next_stop(c);

    // If this is a separator and not the end of a string we wil have to include
    // it. However, if this is a '\0' we must not skip it.
    while (cwk_path_is_separator(c)) {
      ++c;
    }

    // We are now skipping the shared folder name, which will end after the
    // next stop.
    c = cwk_path_find_next_stop(c);

    // Then there might be a separator at the end. We will include that as well,
    // it will mark the path as absolute.
    if (cwk_path_is_separator(c)) {
      ++c;
    }

    // Finally, calculate the size of the root.
    *length = (size_t)(c - path);
    return;
  }

  // Move to the next and check whether this is a colon.
  if (*++c == ':') {
    *length = 2;

    // Now check whether this is a backslash (or slash). If it is not, we could
    // assume that the next character is a '\0' if it is a valid path. However,
    // we will not assume that - since ':' is not valid in a path it must be a
    // mistake by the caller than. We will try to understand it anyway.
    if (cwk_path_is_separator(++c)) {
      *length = 3;
    }
  }
}

static void cwk_path_get_root_unix(const char *path, size_t *length)
{
  // The slash of the unix path represents the root. There is no root if there
  // is no slash.
  if (cwk_path_is_separator(path)) {
    *length = 1;
  } else {
    *length = 0;
  }
}

static bool cwk_path_is_root_absolute(const char *path, size_t length)
{
  // This is definitely not absolute if there is no root.
  if (length == 0) {
    return false;
  }

  // If there is a separator at the end of the root, we can safely consider this
  // to be an absolute path.
  return cwk_path_is_separator(&path[length - 1]);
}

static void cwk_path_fix_root(char *buffer, size_t buffer_size, size_t length)
{
  size_t i;

  // This only affects windows.
  if (path_style != CWK_STYLE_WINDOWS) {
    return;
  }

  // Make sure we are not writing further than we are actually allowed to.
  if (length > buffer_size) {
    length = buffer_size;
  }

  // Replace all forward slashes with backwards slashes. Since this is windows
  // we can't have any forward slashes in the root.
  for (i = 0; i < length; ++i) {
    if (cwk_path_is_separator(&buffer[i])) {
      buffer[i] = *separators[CWK_STYLE_WINDOWS];
    }
  }
}

static size_t cwk_path_join_and_normalize_multiple(const char **paths,
  char *buffer, size_t buffer_size)
{
  size_t pos;
  bool absolute, has_segment_output;
  struct cwk_segment_joined sj;

  // We initialize the position after the root, which should get us started.
  cwk_path_get_root(paths[0], &pos);

  // Determine whether the path is absolute or not. We need that to determine
  // later on whether we can remove superfluous "../" or not.
  absolute = cwk_path_is_root_absolute(paths[0], pos);

  // First copy the root to the output. After copying, we will normalize the
  // root.
  cwk_path_output_sized(buffer, buffer_size, 0, paths[0], pos);
  cwk_path_fix_root(buffer, buffer_size, pos);

  // So we just grab the first segment. If there is no segment we will always
  // output a "/", since we currently only support absolute paths here.
  if (!cwk_path_get_first_segment_joined(paths, &sj)) {
    goto done;
  }

  // Let's assume that we don't have any segment output for now. We will toggle
  // this flag once there is some output.
  has_segment_output = false;

  do {
    // Check whether we have to drop this segment because of resolving a
    // relative path or because it is a CWK_CURRENT segment.
    if (cwk_path_segment_will_be_removed(&sj, absolute)) {
      continue;
    }

    // We add a separator if we previously wrote a segment. The last segment
    // must not have a trailing separator. This must happen before the segment
    // output, since we would override the null terminating character with
    // reused buffers if this was done afterwards.
    if (has_segment_output) {
      pos += cwk_path_output_separator(buffer, buffer_size, pos);
    }

    // Remember that we have segment output, so we can handle the trailing slash
    // later on. This is necessary since we might have segments but they are all
    // removed.
    has_segment_output = true;

    // Write out the segment but keep in mind that we need to follow the
    // buffer size limitations. That's why we use the path output functions
    // here.
    pos += cwk_path_output_sized(buffer, buffer_size, pos, sj.segment.begin,
      sj.segment.size);
  } while (cwk_path_get_next_segment_joined(&sj));

  // Remove the trailing slash, but only if we have segment output. We don't
  // want to remove anything from the root.
  if (!has_segment_output && pos == 0) {
    // This may happen if the path is absolute and all segments have been
    // removed. We can not have an empty output - and empty output means we stay
    // in the current directory. So we will output a ".".
    assert(absolute == false);
    pos += cwk_path_output_current(buffer, buffer_size, pos);
  }

  // We must append a '\0' in any case, unless the buffer size is zero. If the
  // buffer size is zero, which means we can not.
done:
  cwk_path_terminate_output(buffer, buffer_size, pos);

  // And finally let our caller know about the total size of the normalized
  // path.
  return pos;
}

size_t cwk_path_get_absolute(const char *base, const char *path, char *buffer,
  size_t buffer_size)
{
  size_t i;
  const char *paths[4];

  // The basename should be an absolute path if the caller is using the API
  // correctly. However, he might not and in that case we will append a fake
  // root at the beginning.
  if (cwk_path_is_absolute(base)) {
    i = 0;
  } else if (path_style == CWK_STYLE_WINDOWS) {
    paths[0] = "\\";
    i = 1;
  } else {
    paths[0] = "/";
    i = 1;
  }

  if (cwk_path_is_absolute(path)) {
    // If the submitted path is not relative the base path becomes irrelevant.
    // We will only normalize the submitted path instead.
    paths[i++] = path;
    paths[i] = NULL;
  } else {
    // Otherwise we append the relative path to the base path and normalize it.
    // The result will be a new absolute path.
    paths[i++] = base;
    paths[i++] = path;
    paths[i] = NULL;
  }

  // Finally join everything together and normalize it.
  return cwk_path_join_and_normalize_multiple(paths, buffer, buffer_size);
}

static void cwk_path_skip_segments_until_diverge(struct cwk_segment_joined *bsj,
  struct cwk_segment_joined *osj, bool absolute, bool *base_available,
  bool *other_available)
{
  // Now looping over all segments until they start to diverge. A path may
  // diverge if two segments are not equal or if one path reaches the end.
  do {

    // Check whether there is anything available after we skip everything which
    // is invisible. We do that for both paths, since we want to let the caller
    // know which path has some trailing segments after they diverge.
    *base_available = cwk_path_segment_joined_skip_invisible(bsj, absolute);
    *other_available = cwk_path_segment_joined_skip_invisible(osj, absolute);

    // We are done if one or both of those paths reached the end. They either
    // diverge or both reached the end - but in both cases we can not continue
    // here.
    if (!*base_available || !*other_available) {
      break;
    }

    // Compare the content of both segments. We are done if they are not equal,
    // since they diverge.
    if (!cwk_path_is_string_equal(bsj->segment.begin, osj->segment.begin,
          bsj->segment.size, osj->segment.size)) {
      break;
    }

    // We keep going until one of those segments reached the end. The next
    // segment might be invisible, but we will check for that in the beginning
    // of the loop once again.
    *base_available = cwk_path_get_next_segment_joined(bsj);
    *other_available = cwk_path_get_next_segment_joined(osj);
  } while (*base_available && *other_available);
}

size_t cwk_path_get_relative(const char *base_directory, const char *path,
  char *buffer, size_t buffer_size)
{
  size_t pos, base_root_length, path_root_length;
  bool absolute, base_available, other_available, has_output;
  const char *base_paths[2], *other_paths[2];
  struct cwk_segment_joined bsj, osj;

  pos = 0;

  // First we compare the roots of those two paths. If the roots are not equal
  // we can't continue, since there is no way to get a relative path from
  // different roots.
  cwk_path_get_root(base_directory, &base_root_length);
  cwk_path_get_root(path, &path_root_length);
  if (base_root_length != path_root_length ||
      !cwk_path_is_string_equal(base_directory, path, base_root_length,
        path_root_length)) {
    cwk_path_terminate_output(buffer, buffer_size, pos);
    return pos;
  }

  // Verify whether this is an absolute path. We need to know that since we can
  // remove all back-segments if it is.
  absolute = cwk_path_is_root_absolute(base_directory, base_root_length);

  // Initialize our joined segments. This will allow us to use the internal
  // functions to skip until diverge and invisible. We only have one path in
  // them though.
  base_paths[0] = base_directory;
  base_paths[1] = NULL;
  other_paths[0] = path;
  other_paths[1] = NULL;
  cwk_path_get_first_segment_joined(base_paths, &bsj);
  cwk_path_get_first_segment_joined(other_paths, &osj);

  // Okay, now we skip until the segments diverge. We don't have anything to do
  // with the segments which are equal.
  cwk_path_skip_segments_until_diverge(&bsj, &osj, absolute, &base_available,
    &other_available);

  // Assume there is no output until we have got some. We will need this
  // information later on to remove trailing slashes or alternatively output a
  // current-segment.
  has_output = false;

  // So if we still have some segments left in the base path we will now output
  // a back segment for all of them.
  if (base_available) {
    do {
      // Skip any invisible segment. We don't care about those and we don't need
      // to navigate back because of them.
      if (!cwk_path_segment_joined_skip_invisible(&bsj, absolute)) {
        break;
      }

      // Toggle the flag if we have output. We need to remember that, since we
      // want to remove the trailing slash.
      has_output = true;

      // Output the back segment and a separator. No need to worry about the
      // superfluous segment since it will be removed later on.
      pos += cwk_path_output_back(buffer, buffer_size, pos);
      pos += cwk_path_output_separator(buffer, buffer_size, pos);
    } while (cwk_path_get_next_segment_joined(&bsj));
  }

  // And if we have some segments available of the target path we will output
  // all of those.
  if (other_available) {
    do {
      // Again, skip any invisible segments since we don't need to navigate into
      // them.
      if (!cwk_path_segment_joined_skip_invisible(&osj, absolute)) {
        break;
      }

      // Toggle the flag if we have output. We need to remember that, since we
      // want to remove the trailing slash.
      has_output = true;

      // Output the current segment and a separator. No need to worry about the
      // superfluous segment since it will be removed later on.
      pos += cwk_path_output_sized(buffer, buffer_size, pos, osj.segment.begin,
        osj.segment.size);
      pos += cwk_path_output_separator(buffer, buffer_size, pos);
    } while (cwk_path_get_next_segment_joined(&osj));
  }

  // If we have some output by now we will have to remove the trailing slash. We
  // simply do that by moving back one character. The terminate output function
  // will then place the '\0' on this position. Otherwise, if there is no
  // output, we will have to output a "current directory", since the target path
  // points to the base path.
  if (has_output) {
    --pos;
  } else {
    pos += cwk_path_output_current(buffer, buffer_size, pos);
  }

  // Finally, we can terminate the output - which means we place a '\0' at the
  // current position or at the end of the buffer.
  cwk_path_terminate_output(buffer, buffer_size, pos);

  return pos;
}

size_t cwk_path_join(const char *path_a, const char *path_b, char *buffer,
  size_t buffer_size)
{
  const char *paths[3];

  // This is simple. We will just create an array with the two paths which we
  // wish to join.
  paths[0] = path_a;
  paths[1] = path_b;
  paths[2] = NULL;

  // And then call the join and normalize function which will do the hard work
  // for us.
  return cwk_path_join_and_normalize_multiple(paths, buffer, buffer_size);
}

size_t cwk_path_join_multiple(const char **paths, char *buffer,
  size_t buffer_size)
{
  // We can just call the internal join and normalize function for this one,
  // since it will handle everything.
  return cwk_path_join_and_normalize_multiple(paths, buffer, buffer_size);
}

void cwk_path_get_root(const char *path, size_t *length)
{
  // We use a different implementation here based on the configuration of the
  // library.
  if (path_style == CWK_STYLE_WINDOWS) {
    cwk_path_get_root_windows(path, length);
  } else {
    cwk_path_get_root_unix(path, length);
  }
}

size_t cwk_path_change_root(const char *path, const char *new_root,
  char *buffer, size_t buffer_size)
{
  const char *tail;
  size_t root_length, path_length, tail_length, new_root_length, new_path_size;

  // First we need to determine the actual size of the root which we will
  // change.
  cwk_path_get_root(path, &root_length);

  // Now we determine the sizes of the new root and the path. We need that to
  // determine the size of the part after the root (the tail).
  new_root_length = strlen(new_root);
  path_length = strlen(path);

  // Okay, now we calculate the position of the tail and the length of it.
  tail = path + root_length;
  tail_length = path_length - root_length;

  // We first output the tail and then the new root, that's because the source
  // path and the buffer may be overlapping. This way the root will not
  // overwrite the tail.
  cwk_path_output_sized(buffer, buffer_size, new_root_length, tail,
    tail_length);
  cwk_path_output_sized(buffer, buffer_size, 0, new_root, new_root_length);

  // Finally we calculate the size o the new path and terminate the output with
  // a '\0'.
  new_path_size = tail_length + new_root_length;
  cwk_path_terminate_output(buffer, buffer_size, new_path_size);

  return new_path_size;
}

bool cwk_path_is_absolute(const char *path)
{
  size_t length;

  // We grab the root of the path. This root does not include the first
  // separator of a path.
  cwk_path_get_root(path, &length);

  // Now we can determine whether the root is absolute or not.
  return cwk_path_is_root_absolute(path, length);
}

bool cwk_path_is_relative(const char *path)
{
  // The path is relative if it is not absolute.
  return !cwk_path_is_absolute(path);
}

void cwk_path_get_basename(const char *path, const char **basename,
  size_t *length)
{
  struct cwk_segment segment;

  // We get the last segment of the path. The last segment will contain the
  // basename if there is any. If there are no segments we will set the basename
  // to NULL and the length to 0.
  if (!cwk_path_get_last_segment(path, &segment)) {
    *basename = NULL;
    if (length) {
      *length = 0;
    }
    return;
  }

  // Now we can just output the segment contents, since that's our basename.
  // There might be trailing separators after the basename, but the size does
  // not include those.
  *basename = segment.begin;
  if (length) {
    *length = segment.size;
  }
}

size_t cwk_path_change_basename(const char *path, const char *new_basename,
  char *buffer, size_t buffer_size)
{
  struct cwk_segment segment;
  size_t pos, root_size, new_basename_size;

  // First we try to get the last segment. We may only have a root without any
  // segments, in which case we will create one.
  if (!cwk_path_get_last_segment(path, &segment)) {

    // So there is no segment in this path. First we grab the root and output
    // that. We are not going to modify the root in any way.
    cwk_path_get_root(path, &root_size);
    pos = cwk_path_output_sized(buffer, buffer_size, 0, path, root_size);

    // We have to trim the separators from the beginning of the new basename.
    // This is quite easy to do.
    while (cwk_path_is_separator(new_basename)) {
      ++new_basename;
    }

    // Now we measure the length of the new basename, this is a two step
    // process. First we find the '\0' character at the end of the string.
    new_basename_size = 0;
    while (new_basename[new_basename_size]) {
      ++new_basename_size;
    }

    // And then we trim the separators at the end of the basename until we reach
    // the first valid character.
    while (new_basename_size > 0 &&
           cwk_path_is_separator(&new_basename[new_basename_size - 1])) {
      --new_basename_size;
    }

    // Now we will output the new basename after the root.
    pos += cwk_path_output_sized(buffer, buffer_size, pos, new_basename,
      new_basename_size);

    // And finally terminate the output and return the total size of the path.
    cwk_path_terminate_output(buffer, buffer_size, pos);
    return pos;
  }

  // If there is a last segment we can just forward this call, which is fairly
  // easy.
  return cwk_path_change_segment(&segment, new_basename, buffer, buffer_size);
}

void cwk_path_get_dirname(const char *path, size_t *length)
{
  struct cwk_segment segment;

  // We get the last segment of the path. The last segment will contain the
  // basename if there is any. If there are no segments we will set the length
  // to 0.
  if (!cwk_path_get_last_segment(path, &segment)) {
    *length = 0;
    return;
  }

  // We can now return the length from the beginning of the string up to the
  // beginning of the last segment.
  *length = (size_t)(segment.begin - path);
}

bool cwk_path_get_extension(const char *path, const char **extension,
  size_t *length)
{
  struct cwk_segment segment;
  const char *c;

  // We get the last segment of the path. The last segment will contain the
  // extension if there is any.
  if (!cwk_path_get_last_segment(path, &segment)) {
    return false;
  }

  // Now we search for a dot within the segment. If there is a dot, we consider
  // the rest of the segment the extension. We do this from the end towards the
  // beginning, since we want to find the last dot.
  for (c = segment.end; c >= segment.begin; --c) {
    if (*c == '.') {
      // Okay, we found an extension. We can stop looking now.
      *extension = c;
      *length = (size_t)(segment.end - c);
      return true;
    }
  }

  // We couldn't find any extension.
  return false;
}

bool cwk_path_has_extension(const char *path)
{
  const char *extension;
  size_t length;

  // We just wrap the get_extension call which will then do the work for us.
  return cwk_path_get_extension(path, &extension, &length);
}

size_t cwk_path_change_extension(const char *path, const char *new_extension,
  char *buffer, size_t buffer_size)
{
  struct cwk_segment segment;
  const char *c, *old_extension;
  size_t pos, root_size, trail_size, new_extension_size;

  // First we try to get the last segment. We may only have a root without any
  // segments, in which case we will create one.
  if (!cwk_path_get_last_segment(path, &segment)) {

    // So there is no segment in this path. First we grab the root and output
    // that. We are not going to modify the root in any way. If there is no
    // root, this will end up with a root size 0, and nothing will be written.
    cwk_path_get_root(path, &root_size);
    pos = cwk_path_output_sized(buffer, buffer_size, 0, path, root_size);

    // Add a dot if the submitted value doesn't have any.
    if (*new_extension != '.') {
      pos += cwk_path_output_dot(buffer, buffer_size, pos);
    }

    // And finally terminate the output and return the total size of the path.
    pos += cwk_path_output(buffer, buffer_size, pos, new_extension);
    cwk_path_terminate_output(buffer, buffer_size, pos);
    return pos;
  }

  // Now we seek the old extension in the last segment, which we will replace
  // with the new one. If there is no old extension, it will point to the end of
  // the segment.
  old_extension = segment.end;
  for (c = segment.begin; c < segment.end; ++c) {
    if (*c == '.') {
      old_extension = c;
    }
  }

  pos = cwk_path_output_sized(buffer, buffer_size, 0, segment.path,
    (size_t)(old_extension - segment.path));

  // If the new extension starts with a dot, we will skip that dot. We always
  // output exactly one dot before the extension. If the extension contains
  // multiple dots, we will output those as part of the extension.
  if (*new_extension == '.') {
    ++new_extension;
  }

  // We calculate the size of the new extension, including the dot, in order to
  // output the trail - which is any part of the path coming after the
  // extension. We must output this first, since the buffer may overlap with the
  // submitted path - and it would be overridden by longer extensions.
  new_extension_size = strlen(new_extension) + 1;
  trail_size = cwk_path_output(buffer, buffer_size, pos + new_extension_size,
    segment.end);

  // Finally we output the dot and the new extension. The new extension itself
  // doesn't contain the dot anymore, so we must output that first.
  pos += cwk_path_output_dot(buffer, buffer_size, pos);
  pos += cwk_path_output(buffer, buffer_size, pos, new_extension);

  // Now we terminate the output with a null-terminating character, but before
  // we do that we must add the size of the trail to the position which we
  // output before.
  pos += trail_size;
  cwk_path_terminate_output(buffer, buffer_size, pos);

  // And the position is our output size now.
  return pos;
}

size_t cwk_path_normalize(const char *path, char *buffer, size_t buffer_size)
{
  const char *paths[2];

  // Now we initialize the paths which we will normalize. Since this function
  // only supports submitting a single path, we will only add that one.
  paths[0] = path;
  paths[1] = NULL;

  return cwk_path_join_and_normalize_multiple(paths, buffer, buffer_size);
}

size_t cwk_path_get_intersection(const char *path_base, const char *path_other)
{
  bool absolute;
  size_t base_root_length, other_root_length;
  const char *end;
  const char *paths_base[2], *paths_other[2];
  struct cwk_segment_joined base, other;

  // We first compare the two roots. We just return zero if they are not equal.
  // This will also happen to return zero if the paths are mixed relative and
  // absolute.
  cwk_path_get_root(path_base, &base_root_length);
  cwk_path_get_root(path_other, &other_root_length);
  if (!cwk_path_is_string_equal(path_base, path_other, base_root_length,
        other_root_length)) {
    return 0;
  }

  // Configure our paths. We just have a single path in here for now.
  paths_base[0] = path_base;
  paths_base[1] = NULL;
  paths_other[0] = path_other;
  paths_other[1] = NULL;

  // So we get the first segment of both paths. If one of those paths don't have
  // any segment, we will return 0.
  if (!cwk_path_get_first_segment_joined(paths_base, &base) ||
      !cwk_path_get_first_segment_joined(paths_other, &other)) {
    return base_root_length;
  }

  // We now determine whether the path is absolute or not. This is required
  // because if will ignore removed segments, and this behaves differently if
  // the path is absolute. However, we only need to check the base path because
  // we are guaranteed that both paths are either relative or absolute.
  absolute = cwk_path_is_root_absolute(path_base, base_root_length);

  // We must keep track of the end of the previous segment. Initially, this is
  // set to the beginning of the path. This means that 0 is returned if the
  // first segment is not equal.
  end = path_base + base_root_length;

  // Now we loop over both segments until one of them reaches the end or their
  // contents are not equal.
  do {
    // We skip all segments which will be removed in each path, since we want to
    // know about the true path.
    if (!cwk_path_segment_joined_skip_invisible(&base, absolute) ||
        !cwk_path_segment_joined_skip_invisible(&other, absolute)) {
      break;
    }

    if (!cwk_path_is_string_equal(base.segment.begin, other.segment.begin,
          base.segment.size, other.segment.size)) {
      // So the content of those two segments are not equal. We will return the
      // size up to the beginning.
      return (size_t)(end - path_base);
    }

    // Remember the end of the previous segment before we go to the next one.
    end = base.segment.end;
  } while (cwk_path_get_next_segment_joined(&base) &&
           cwk_path_get_next_segment_joined(&other));

  // Now we calculate the length up to the last point where our paths pointed to
  // the same place.
  return (size_t)(end - path_base);
}

bool cwk_path_get_first_segment(const char *path, struct cwk_segment *segment)
{
  size_t length;
  const char *segments;

  // We skip the root since that's not part of the first segment. The root is
  // treated as a separate entity.
  cwk_path_get_root(path, &length);
  segments = path + length;

  // Now, after we skipped the root we can continue and find the actual segment
  // content.
  return cwk_path_get_first_segment_without_root(path, segments, segment);
}

bool cwk_path_get_last_segment(const char *path, struct cwk_segment *segment)
{
  // We first grab the first segment. This might be our last segment as well,
  // but we don't know yet. There is no last segment if there is no first
  // segment, so we return false in that case.
  if (!cwk_path_get_first_segment(path, segment)) {
    return false;
  }

  // Now we find our last segment. The segment struct of the caller
  // will contain the last segment, since the function we call here will not
  // change the segment struct when it reaches the end.
  while (cwk_path_get_next_segment(segment)) {
    // We just loop until there is no other segment left.
  }

  return true;
}

bool cwk_path_get_next_segment(struct cwk_segment *segment)
{
  const char *c;

  // First we jump to the end of the previous segment. The first character must
  // be either a '\0' or a separator.
  c = segment->begin + segment->size;
  if (*c == '\0') {
    return false;
  }

  // Now we skip all separator until we reach something else. We are not yet
  // guaranteed to have a segment, since the string could just end afterwards.
  assert(cwk_path_is_separator(c));
  do {
    ++c;
  } while (cwk_path_is_separator(c));

  // If the string ends here, we can safely assume that there is no other
  // segment after this one.
  if (*c == '\0') {
    return false;
  }

  // Now we are safe to assume there is a segment. We store the beginning of
  // this segment in the segment struct of the caller.
  segment->begin = c;

  // And now determine the size of this segment, and store it in the struct of
  // the caller as well.
  c = cwk_path_find_next_stop(c);
  segment->end = c;
  segment->size = (size_t)(c - segment->begin);

  // Tell the caller that we found a segment.
  return true;
}

bool cwk_path_get_previous_segment(struct cwk_segment *segment)
{
  const char *c;

  // The current position might point to the first character of the path, which
  // means there are no previous segments available.
  c = segment->begin;
  if (c <= segment->segments) {
    return false;
  }

  // We move towards the beginning of the path until we either reached the
  // beginning or the character is no separator anymore.
  do {
    --c;
    if (c < segment->segments) {
      // So we reached the beginning here and there is no segment. So we return
      // false and don't change the segment structure submitted by the caller.
      return false;
    }
  } while (cwk_path_is_separator(c));

  // We are guaranteed now that there is another segment, since we moved before
  // the previous separator and did not reach the segment path beginning.
  segment->end = c + 1;
  segment->begin = cwk_path_find_previous_stop(segment->segments, c);
  segment->size = (size_t)(segment->end - segment->begin);

  return true;
}

enum cwk_segment_type cwk_path_get_segment_type(
  const struct cwk_segment *segment)
{
  // We just make a string comparison with the segment contents and return the
  // appropriate type.
  if (strncmp(segment->begin, ".", segment->size) == 0) {
    return CWK_CURRENT;
  } else if (strncmp(segment->begin, "..", segment->size) == 0) {
    return CWK_BACK;
  }

  return CWK_NORMAL;
}

bool cwk_path_is_separator(const char *str)
{
  const char *c;

  // We loop over all characters in the read symbols.
  c = separators[path_style];
  while (*c) {
    if (*c == *str) {
      return true;
    }

    ++c;
  }

  return false;
}

size_t cwk_path_change_segment(struct cwk_segment *segment, const char *value,
  char *buffer, size_t buffer_size)
{
  size_t pos, value_size, tail_size;

  // First we have to output the head, which is the whole string up to the
  // beginning of the segment. This part of the path will just stay the same.
  pos = cwk_path_output_sized(buffer, buffer_size, 0, segment->path,
    (size_t)(segment->begin - segment->path));

  // In order to trip the submitted value, we will skip any separator at the
  // beginning of it and behave as if it was never there.
  while (cwk_path_is_separator(value)) {
    ++value;
  }

  // Now we determine the length of the value. In order to do that we first
  // locate the '\0'.
  value_size = 0;
  while (value[value_size]) {
    ++value_size;
  }

  // Since we trim separators at the beginning and in the end of the value we
  // have to subtract from the size until there are either no more characters
  // left or the last character is no separator.
  while (value_size > 0 && cwk_path_is_separator(&value[value_size - 1])) {
    --value_size;
  }

  // We also have to determine the tail size, which is the part of the string
  // following the current segment. This part will not change.
  tail_size = strlen(segment->end);

  // Now we output the tail. We have to do that, because if the buffer and the
  // source are overlapping we would override the tail if the value is
  // increasing in length.
  cwk_path_output_sized(buffer, buffer_size, pos + value_size, segment->end,
    tail_size);

  // Finally we can output the value in the middle of the head and the tail,
  // where we have enough space to fit the whole trimmed value.
  pos += cwk_path_output_sized(buffer, buffer_size, pos, value, value_size);

  // Now we add the tail size to the current position and terminate the output -
  // basically, ensure that there is a '\0' at the end of the buffer.
  pos += tail_size;
  cwk_path_terminate_output(buffer, buffer_size, pos);

  // And now tell the caller how long the whole path would be.
  return pos;
}

enum cwk_path_style cwk_path_guess_style(const char *path)
{
  const char *c;
  size_t root_length;
  struct cwk_segment segment;

  // First we determine the root. Only windows roots can be longer than a single
  // slash, so if we can determine that it starts with something like "C:", we
  // know that this is a windows path.
  cwk_path_get_root_windows(path, &root_length);
  if (root_length > 1) {
    return CWK_STYLE_WINDOWS;
  }

  // Next we check for slashes. Windows uses backslashes, while unix uses
  // forward slashes. Windows actually supports both, but our best guess is to
  // assume windows with backslashes and unix with forward slashes.
  for (c = path; *c; ++c) {
    if (*c == *separators[CWK_STYLE_UNIX]) {
      return CWK_STYLE_UNIX;
    } else if (*c == *separators[CWK_STYLE_WINDOWS]) {
      return CWK_STYLE_WINDOWS;
    }
  }

  // This path does not have any slashes. We grab the last segment (which
  // actually must be the first one), and determine whether the segment starts
  // with a dot. A dot is a hidden folder or file in the UNIX world, in that
  // case we assume the path to have UNIX style.
  if (!cwk_path_get_last_segment(path, &segment)) {
    // We couldn't find any segments, so we default to a UNIX path style since
    // there is no way to make any assumptions.
    return CWK_STYLE_UNIX;
  }

  if (*segment.begin == '.') {
    return CWK_STYLE_UNIX;
  }

  // And finally we check whether the last segment contains a dot. If it
  // contains a dot, that might be an extension. Windows is more likely to have
  // file names with extensions, so our guess would be windows.
  for (c = segment.begin; *c; ++c) {
    if (*c == '.') {
      return CWK_STYLE_WINDOWS;
    }
  }

  // All our checks failed, so we will return a default value which is currently
  // UNIX.
  return CWK_STYLE_UNIX;
}

void cwk_path_set_style(enum cwk_path_style style)
{
  // We can just set the global path style variable and then the behaviour for
  // all functions will change accordingly.
  assert(style == CWK_STYLE_UNIX || style == CWK_STYLE_WINDOWS);
  path_style = style;
}

enum cwk_path_style cwk_path_get_style(void)
{
  // Simply return the path style which we store in a global variable.
  return path_style;
}
