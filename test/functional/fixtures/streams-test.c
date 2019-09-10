/// Helper program to exit and keep stdout open (like "xclip -i -loops 1").
#include <stdio.h>

#include <uv.h>

uv_loop_t *loop;
uv_process_t child_req;
uv_process_options_t options;

int main(int argc, char **argv)
{
  loop = uv_default_loop();

  char * args[3];
  args[0] = "sleep";
  args[1] = "10";
  args[2] = NULL;

  options.exit_cb = NULL;
  options.file = "sleep";
  options.args = args;
  options.flags = UV_PROCESS_DETACHED;

  int r;
  if ((r = uv_spawn(loop, &child_req, &options))) {
    fprintf(stderr, "%s\n", uv_strerror(r));
    return 1;
  }
  fprintf(stderr, "pid: %d\n", child_req.pid);
  uv_unref((uv_handle_t *)&child_req);

  return uv_run(loop, UV_RUN_DEFAULT);
}
