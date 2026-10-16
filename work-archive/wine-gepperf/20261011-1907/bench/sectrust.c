/* Host side of crypt32's root import (load_root_certs on macOS), timed per domain. */
#include <Security/Security.h>
#include <stdio.h>
#include <time.h>
static double ms(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1e3 + t.tv_nsec / 1e6; }
int main(void)
{
    SecTrustSettingsDomain d[] = { kSecTrustSettingsDomainSystem, kSecTrustSettingsDomainAdmin, kSecTrustSettingsDomainUser };
    double t0 = ms();
    for (int i = 0; i < 3; i++)
    {
        double t = ms(); CFArrayRef certs; int n = 0;
        OSStatus s = SecTrustSettingsCopyCertificates(d[i], &certs);
        double t1 = ms();
        if (s == noErr)
        {
            for (CFIndex j = 0; j < CFArrayGetCount(certs); j++)
            {
                CFDataRef data;
                if (SecItemExport(CFArrayGetValueAtIndex(certs, j), kSecFormatX509Cert, 0, NULL, &data) == noErr) { n++; CFRelease(data); }
            }
            CFRelease(certs);
        }
        printf("domain %d: status %d, copy %.1f ms, export %d certs %.1f ms\n", i, (int)s, t1 - t, n, ms() - t1);
    }
    printf("total %.1f ms\n", ms() - t0);
    return 0;
}
