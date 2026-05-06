#ifndef CC_SSH_H
#define CC_SSH_H

#ifdef __cplusplus
extern "C" {
#endif

int cc_ssh_connect(const char *host, int port, const char *user, const char *password, int timeout_ms);
int cc_ssh_exec(const char *command, int timeout_ms);
int cc_ssh_disconnect(void);
const char *cc_ssh_stdout(void);
const char *cc_ssh_stderr(void);
const char *cc_ssh_last_error(void);

#ifdef __cplusplus
}
#endif

#endif
