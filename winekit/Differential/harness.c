/* harness <rules-dir> <executable> [launcher-compatdb-file]: runs Wine's hub_rules_apply and prints WINE_COMPATDB and the
 * capabilities in the format of hubrules-swift. */
#include <stdio.h>
#include "hubrules.c"

/* the gate fixup patches a loaded image, which no case here does */
NTSTATUS WINAPI NtProtectVirtualMemory( HANDLE p, PVOID *a, SIZE_T *s, ULONG n, ULONG *o )
{ (void)p; (void)a; (void)s; (void)n; (void)o; return 0; }

unsigned char __wine_dbg_get_channel_flags( struct __wine_debug_channel *channel ) { (void)channel; return 0; }
const char *__wine_dbg_strdup( const char *str ) { return str; }
int __wine_dbg_output( const char *str ) { return fputs( str, stderr ); }
int __wine_dbg_header( enum __wine_debug_class cls, struct __wine_debug_channel *channel, const char *function )
{ (void)cls; (void)channel; (void)function; return 0; }

int main( int argc, char **argv )
{
    static char launcher[1 << 20];
    const char *value;

    if (argc < 3) return 2;
    data_dir = argv[1];
    unsetenv( "WINE_COMPATDB" );
    unsetenv( BASE_ENV );
    if (argc > 3)
    {
        FILE *f = fopen( argv[3], "rb" );
        size_t n = f ? fread( launcher, 1, sizeof(launcher) - 1, f ) : 0;
        if (f) fclose( f );
        launcher[n] = 0;
        setenv( "WINE_COMPATDB", launcher, 1 );
    }
    hub_rules_apply( argv[2] );
    value = getenv( "WINE_COMPATDB" );
    printf( "%s\n--\ngate_selector_fixup=%d\nhub_dll_dir=%s\n", value ? value : "", gate_selector_fixup ? 1 : 0,
            hub_dll_dir ? hub_dll_dir : "" );
    return 0;
}
