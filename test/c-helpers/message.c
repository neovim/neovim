#include <stdint.h>

static emsg_mock _emsg_mock = NULL;

void set_emsg_mock(emsg_mock mock)
{
  _emsg_mock = mock;
}

int emsg_mocker(char *msg)
{
  if (!_emsg_mock) {
    return emsg((uint8_t *)msg);
  }

  return _emsg_mock(xstrdup(msg));
}
