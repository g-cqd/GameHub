/* Times the first open of the ROOT store in a fresh process (crypt32 host root import). */
#include <windows.h>
#include <wincrypt.h>
#include <stdio.h>
static double now(void) { LARGE_INTEGER f, c; QueryPerformanceFrequency(&f); QueryPerformanceCounter(&c); return (double)c.QuadPart * 1000.0 / f.QuadPart; }
int main(int argc, char **argv)
{
    double t = now(); HCERTSTORE s = CertOpenSystemStoreW(0, L"ROOT"); double t1 = now();
    PCCERT_CONTEXT c = NULL; int n = 0;
    while ((c = CertEnumCertificatesInStore(s, c))) n++;
    printf("first ROOT open %.1f ms, %d certs (enum %.1f ms)\n", t1 - t, n, now() - t1);
    if (argc > 1)   /* dump SHA-1 of every cert, sorted by caller, for equality checks */
    {
        while ((c = CertEnumCertificatesInStore(s, c)))
        {
            BYTE h[20]; DWORD sz = sizeof(h); int i;
            CertGetCertificateContextProperty(c, CERT_HASH_PROP_ID, h, &sz);
            for (i = 0; i < 20; i++) printf("%02x", h[i]);
            printf("\n");
        }
    }
    CertCloseStore(s, 0);
    return 0;
}
