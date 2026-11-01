/* Stand-in for ntdll's unix_private.h: just what hubrules.c uses, so the real file builds outside ntdll. */
#include <stdlib.h>
#include "winternl.h"
static const char *data_dir;
static PEB *peb;
static void set_process_env_var( const char *name, const char *value ) { (void)name; (void)value; }
#define NtCurrentProcess() ((HANDLE)~(ULONG_PTR)0)
#ifndef max
#define max(a,b) ((a) > (b) ? (a) : (b))
#define min(a,b) ((a) < (b) ? (a) : (b))
#endif
