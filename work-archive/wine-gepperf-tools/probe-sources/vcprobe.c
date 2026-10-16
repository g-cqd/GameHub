/* Times the pieces of WMI Win32_VideoController in a fresh process, in the order EAGEP's
 * machash path hits them.  usage: vcprobe [wmi|getdc|both]  (default: wmi) */
#define COBJMACROS
#include <windows.h>
#include <wbemcli.h>
#include <stdio.h>
#include <string.h>
static double now(void) { LARGE_INTEGER f, c; QueryPerformanceFrequency(&f); QueryPerformanceCounter(&c); return (double)c.QuadPart * 1000.0 / f.QuadPart; }
static void wmi_query(const WCHAR *q, const WCHAR *prop)
{
    IWbemLocator *loc; IWbemServices *svc; IEnumWbemClassObject *en; IWbemClassObject *obj; ULONG n; VARIANT v;
    BSTR ns = SysAllocString(L"ROOT\\CIMV2"), wql = SysAllocString(L"WQL"), qs = SysAllocString(q);
    double t0 = now();
    CoCreateInstance(&CLSID_WbemLocator, NULL, CLSCTX_INPROC_SERVER, &IID_IWbemLocator, (void **)&loc);
    IWbemLocator_ConnectServer(loc, ns, NULL, NULL, NULL, 0, NULL, NULL, &svc);
    IWbemServices_ExecQuery(svc, wql, qs, WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY, NULL, &en);
    if (IEnumWbemClassObject_Next(en, WBEM_INFINITE, 1, &obj, &n) == S_OK && n)
    {
        VariantInit(&v);
        IWbemClassObject_Get(obj, prop, 0, &v, NULL, NULL);
        printf("%-40ls %8.1f ms  %ls=%ls\n", q, now() - t0, prop, V_VT(&v) == VT_BSTR ? V_BSTR(&v) : L"?");
        IWbemClassObject_Release(obj);
    }
    IEnumWbemClassObject_Release(en); IWbemServices_Release(svc); IWbemLocator_Release(loc);
}
int main(int argc, char **argv)
{
    const char *mode = argc > 1 ? argv[1] : "wmi";
    double t0 = now();
    CoInitializeEx(NULL, COINIT_MULTITHREADED);
    printf("CoInitializeEx                           %8.1f ms\n", now() - t0);
    if (!strcmp(mode, "getdc") || !strcmp(mode, "both"))
    {
        double t = now(); HDC hdc = GetDC(NULL);
        printf("GetDC(NULL) first                        %8.1f ms\n", now() - t);
        t = now(); int bpp = GetDeviceCaps(hdc, BITSPIXEL), w = GetDeviceCaps(hdc, HORZRES); ReleaseDC(NULL, hdc);
        printf("GetDeviceCaps                            %8.1f ms (%d bpp, %d px)\n", now() - t, bpp, w);
    }
    if (strcmp(mode, "getdc"))
    {
        wmi_query(L"Select * from Win32_BaseBoard", L"SerialNumber");
        wmi_query(L"Select * from Win32_BIOS", L"SerialNumber");
        wmi_query(L"Select * from Win32_VideoController", L"PNPDeviceId");
        wmi_query(L"Select * from Win32_VideoController", L"PNPDeviceId");
    }
    printf("total                                    %8.1f ms\n", now() - t0);
    return 0;
}
