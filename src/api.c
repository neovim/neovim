#include <stdint.h>
#include <stdlib.h>

#include "api.h"

void api_push_keys(char *str)
{
  abort();
}

void api_command(char *str)
{
  abort();
}

void api_eval(char *str)
{
  abort();
}

uint32_t api_bind_eval(char *str)
{
  abort();
}

char **api_list_runtime_paths()
{
  abort();
}

char **api_list_buffers(void)
{
  abort();
  return NULL;
}

char **api_list_windows(void)
{
  abort();
  return NULL;
}

char **api_list_tabpages(void)
{
  abort();
  return NULL;
}

char *api_get_current_line(void)
{
  abort();
  return NULL;
}

uint32_t api_get_current_buffer(void)
{
  abort();
  return 0;
}

uint32_t api_get_current_window(void)
{
  abort();
  return 0;
}

uint32_t api_get_current_tabpage(void)
{
  abort();
  return 0;
}

void api_set_current_line(char *line)
{
  abort();
}

void api_set_current_buffer(uint32_t id)
{
  abort();
}

void api_set_current_window(uint32_t id)
{
  abort();
}

void api_set_current_tabpage(uint32_t id)
{
  abort();
}

char *api_get_option(char *name)
{
  abort();
  return NULL;
}

void api_set_option(char *name, char *value)
{
  abort();
}

void api_out_write(char *str)
{
  abort();
}

void api_err_write(char *str)
{
  abort();
}
