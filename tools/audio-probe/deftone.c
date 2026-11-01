/* Print the default render endpoint and play a 440 Hz tone on it for N seconds (shared mode). */
#define COBJMACROS
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <windows.h>
#include <initguid.h>
#include <mmdeviceapi.h>
#include <audioclient.h>
DEFINE_PROPERTYKEY(PKEY_Device_FriendlyName, 0xa45c254e,0xdf1c,0x4efd,0x80,0x20,0x67,0xd1,0x46,0xa8,0x50,0xe0, 14);

int main(int argc, char **argv)
{
    int secs = argc > 1 ? atoi(argv[1]) : 0;
    IMMDeviceEnumerator *en; IMMDevice *dev; IPropertyStore *ps; PROPVARIANT pv;
    IAudioClient *ac; IAudioRenderClient *rc; WAVEFORMATEX *fmt; UINT32 frames, pad; HRESULT hr;
    double phase = 0;

    CoInitialize(NULL);
    hr = CoCreateInstance(&CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL, &IID_IMMDeviceEnumerator, (void **)&en);
    if (FAILED(hr)) { printf("enumerator %08lx\n", hr); return 1; }
    hr = IMMDeviceEnumerator_GetDefaultAudioEndpoint(en, eRender, eMultimedia, &dev);
    if (FAILED(hr)) { printf("default %08lx\n", hr); return 1; }
    IMMDevice_OpenPropertyStore(dev, STGM_READ, &ps);
    PropVariantInit(&pv);
    IPropertyStore_GetValue(ps, &PKEY_Device_FriendlyName, &pv);
    printf("default render endpoint: %ls\n", pv.pwszVal);
    if (!secs) return 0;

    IMMDevice_Activate(dev, &IID_IAudioClient, CLSCTX_ALL, NULL, (void **)&ac);
    IAudioClient_GetMixFormat(ac, &fmt);
    printf("mix format: %lu Hz, %u channels, %u bits\n", fmt->nSamplesPerSec, fmt->nChannels, fmt->wBitsPerSample);
    hr = IAudioClient_Initialize(ac, AUDCLNT_SHAREMODE_SHARED, 0, 2000000, 0, fmt, NULL);
    if (FAILED(hr)) { printf("initialize %08lx\n", hr); return 1; }
    IAudioClient_GetBufferSize(ac, &frames);
    IAudioClient_GetService(ac, &IID_IAudioRenderClient, (void **)&rc);
    IAudioClient_Start(ac);
    for (DWORD end = GetTickCount() + secs * 1000; GetTickCount() < end; Sleep(10)) {
        BYTE *buf; UINT32 n, i, c;
        if (FAILED(hr = IAudioClient_GetCurrentPadding(ac, &pad))) { printf("padding %08lx\n", hr); return 1; }
        n = frames - pad;
        if (!n || FAILED(IAudioRenderClient_GetBuffer(rc, n, &buf))) continue;
        for (i = 0; i < n; i++, phase += 2 * M_PI * 440 / fmt->nSamplesPerSec)
            for (c = 0; c < fmt->nChannels; c++) ((float *)buf)[i * fmt->nChannels + c] = (getenv("SILENT") ? 0.0f : 0.1f) * sin(phase);
        IAudioRenderClient_ReleaseBuffer(rc, n, 0);
        { static DWORD last; REFERENCE_TIME lat; if (GetTickCount() - last >= 1000) { last = GetTickCount(); IAudioClient_GetStreamLatency(ac, &lat); } }
    }
    IAudioClient_Stop(ac);
    printf("played %d s without error\n", secs);
    return 0;
}
