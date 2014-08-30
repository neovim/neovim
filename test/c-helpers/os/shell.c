static os_system_mock _os_system_mock = NULL;

void set_os_system_mock(os_system_mock mock)
{
  _os_system_mock = mock;
}

int os_system_mocker(const char *cmd,
                     const char *input,
                     size_t len,
                     char **output,
                     size_t *nread)
{
  if (!_os_system_mock) {
    return os_system(cmd, input, len, output, nread);
  }

  *output = _os_system_mock(cmd, input, len);

  if (*output == NULL) {
    return 1;
  }

  *output = xstrdup(*output);

  if (nread) {
    *nread = strlen(*output);
  }

  return 0;
}
