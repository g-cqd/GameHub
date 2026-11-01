/*
 * WineKit's C interface, for Wine's Unix side (GameHub ADR-0020).
 *
 * `swift package wine-objects --output <dir>` writes this header and libwinekit.a, the Embedded Swift objects, into
 * <dir>; Wine builds with `make WINEKIT_DIR=<dir>`. The library needs libc only. Strings it returns are allocated by
 * it and given back with winekit_free.
 */

#ifndef __WINE_WINEKIT_H
#define __WINE_WINEKIT_H

#include <stddef.h>
#include <stdint.h>

/* Reads up to count bytes at offset into buffer, as pread: returns the number read, 0 at the end, -1 on error. */
typedef long (*winekit_read_fn)( void *context, int64_t offset, void *buffer, size_t count );

/*
 * The runtime rules (hub-rules.txt) for the executable named exe (a file name), read through read/context (NULL: no
 * facts), after which the launcher's own WINE_COMPATDB value comes. Byte strings are given with their lengths and need
 * no NUL. On return:
 *   *compatdb            the WINE_COMPATDB value, NUL-terminated
 *   *dll_dir             the hub_dll_dir a matching rule chose (relative to lib/wine), or NULL
 *   *messages            what to print, in rule order, NUL-terminated: one line per message, whose first byte
 *                        says where it goes, 'R' a report line for stderr, 'W' a warning for WARN; the text
 *                        follows that byte
 *   *gate_selector_fixup whether a matching rule asked for it
 * Returns 0, or -1 when an output pointer is NULL. Free each returned string with winekit_free.
 */
int winekit_hub_rules_apply( const char *rules, size_t rules_len, const char *exe, size_t exe_len,
                             winekit_read_fn read, void *context, const char *launcher, size_t launcher_len,
                             char **compatdb, char **dll_dir, char **messages, int *gate_selector_fixup );

void winekit_free( void *ptr );

#endif /* __WINE_WINEKIT_H */
