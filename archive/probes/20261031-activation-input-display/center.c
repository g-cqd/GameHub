#define COBJMACROS
#define INITGUID
#include <windows.h>
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <functiondiscoverykeys_devpkey.h>
#include <ksmedia.h>
static const GUID FLOATSUB = {0x00000003,0x0000,0x0010,{0x80,0x00,0x00,0xaa,0x00,0x38,0x9b,0x71}};
#include <math.h>
#include <stdio.h>
static IMMDevice *find(IMMDeviceEnumerator *e, EDataFlow f, const WCHAR *needle){
    IMMDeviceCollection *c; UINT n; IMMDeviceEnumerator_EnumAudioEndpoints(e,f,DEVICE_STATE_ACTIVE,&c); IMMDeviceCollection_GetCount(c,&n);
    for(UINT i=0;i<n;i++){ IMMDevice *d; IPropertyStore *ps; PROPVARIANT v; IMMDeviceCollection_Item(c,i,&d); IMMDevice_OpenPropertyStore(d,STGM_READ,&ps);
        PropVariantInit(&v); IPropertyStore_GetValue(ps,&PKEY_Device_FriendlyName,&v); if(v.pwszVal && wcsstr(v.pwszVal,needle)) return d; }
    return NULL; }
int main(int argc,char**argv){
    int channels=atoi(argv[1]); DWORD mask=strtoul(argv[2],0,16); int tonech=atoi(argv[3]);
    CoInitializeEx(0,COINIT_MULTITHREADED); IMMDeviceEnumerator *e; CoCreateInstance(&CLSID_MMDeviceEnumerator,0,CLSCTX_ALL,&IID_IMMDeviceEnumerator,(void**)&e);
    IMMDevice *out=find(e,eRender,L"BlackHole"), *in=find(e,eCapture,L"BlackHole"); if(!out){ IMMDeviceEnumerator_GetDefaultAudioEndpoint(e,eRender,eConsole,&out); in=NULL; printf("using default render device, silent\n"); }
    IAudioClient *ac,*cc; IMMDevice_Activate(out,&IID_IAudioClient,CLSCTX_ALL,0,(void**)&ac); if(in) IMMDevice_Activate(in,&IID_IAudioClient,CLSCTX_ALL,0,(void**)&cc); else { printf("render-only test done\n"); HRESULT h=IAudioClient_Initialize(ac,AUDCLNT_SHAREMODE_SHARED,0,2000000,0,(WAVEFORMATEX*)&(WAVEFORMATEXTENSIBLE){{WAVE_FORMAT_EXTENSIBLE,channels,48000,48000*4*channels,4*channels,32,22},{32},mask,FLOATSUB},0); WAVEFORMATEX *mf; IAudioClient_GetMixFormat(ac,&mf); printf("%d ch mask %lx: Initialize %08lx (mix format %u ch)\n",channels,mask,h,mf->nChannels); return 0; }
    WAVEFORMATEXTENSIBLE f={0}; f.Format.wFormatTag=WAVE_FORMAT_EXTENSIBLE; f.Format.nChannels=channels; f.Format.nSamplesPerSec=48000; f.Format.wBitsPerSample=32;
    f.Format.nBlockAlign=4*channels; f.Format.nAvgBytesPerSec=48000*f.Format.nBlockAlign; f.Format.cbSize=22; f.Samples.wValidBitsPerSample=32; f.dwChannelMask=mask; f.SubFormat=FLOATSUB;
    HRESULT hr=IAudioClient_Initialize(ac,AUDCLNT_SHAREMODE_SHARED,0,2000000,0,&f.Format,0); printf("render init %08lx\n",hr);
    WAVEFORMATEX *cf; IAudioClient_GetMixFormat(cc,&cf); hr=IAudioClient_Initialize(cc,AUDCLNT_SHAREMODE_SHARED,0,2000000,0,cf,0); printf("capture init %08lx (%u ch)\n",hr,cf->nChannels);
    IAudioRenderClient *rc; IAudioCaptureClient *capc; IAudioClient_GetService(ac,&IID_IAudioRenderClient,(void**)&rc); IAudioClient_GetService(cc,&IID_IAudioCaptureClient,(void**)&capc);
    UINT32 bufsz; IAudioClient_GetBufferSize(ac,&bufsz); BYTE *b; IAudioRenderClient_GetBuffer(rc,bufsz,&b); float *s=(float*)b;
    for(UINT32 i=0;i<bufsz;i++) for(int c=0;c<channels;c++) s[i*channels+c]= c==tonech ? 0.5f*sinf(i*2*3.14159f*440/48000) : 0;
    IAudioRenderClient_ReleaseBuffer(rc,bufsz,0); IAudioClient_Start(cc); IAudioClient_Start(ac);
    double sum[8]={0}; long frames=0; DWORD t0=GetTickCount();
    while(GetTickCount()-t0<1500){ UINT32 n; BYTE *d; DWORD fl; while(IAudioCaptureClient_GetBuffer(capc,&d,&n,&fl,0,0)==S_OK && n){ float *x=(float*)d;
        for(UINT32 i=0;i<n;i++) for(int c=0;c<cf->nChannels&&c<8;c++) sum[c]+=x[i*cf->nChannels+c]*x[i*cf->nChannels+c]; frames+=n; IAudioCaptureClient_ReleaseBuffer(capc,n); } Sleep(10); }
    printf("%d ch mask %lx tone on ch %d -> captured %ld frames, RMS L=%.3f R=%.3f\n",channels,mask,tonech,frames,sqrt(sum[0]/(frames?frames:1)),sqrt(sum[1]/(frames?frames:1)));
    return 0; }
