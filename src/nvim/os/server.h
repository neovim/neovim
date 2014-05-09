#ifndef NVIM_OS_SERVER_H
#define NVIM_OS_SERVER_H

void server_init();

void server_teardown();

void server_start(char *endpoint);

void server_stop(char *endpoint);

#endif  // NVIM_OS_SERVER_H

