#define COBJMACROS
#define INITGUID
#include <windows.h>
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <stdio.h>
#include <stdlib.h>
static const GUID FLOATSUB = {0x00000003,0x0000,0x0010,{0x80,0x00,0x00,0xaa,0x00,0x38,0x9b,0x71}};
int main(int argc,char**argv){
    int ch=atoi(argv[1]); DWORD mask=strtoul(argv[2],0,16);
    CoInitializeEx(0,COINIT_MULTITHREADED); IMMDeviceEnumerator *e; IMMDevice *d; IAudioClient *ac; WAVEFORMATEX *mf;
    CoCreateInstance(&CLSID_MMDeviceEnumerator,0,CLSCTX_ALL,&IID_IMMDeviceEnumerator,(void**)&e);
    IMMDeviceEnumerator_GetDefaultAudioEndpoint(e,eRender,eConsole,&d); IMMDevice_Activate(d,&IID_IAudioClient,CLSCTX_ALL,0,(void**)&ac);
    IAudioClient_GetMixFormat(ac,&mf);
    WAVEFORMATEXTENSIBLE f={0}; f.Format.wFormatTag=WAVE_FORMAT_EXTENSIBLE; f.Format.nChannels=ch; f.Format.nSamplesPerSec=48000; f.Format.wBitsPerSample=32;
    f.Format.nBlockAlign=4*ch; f.Format.nAvgBytesPerSec=48000*4*ch; f.Format.cbSize=22; f.Samples.wValidBitsPerSample=32; f.dwChannelMask=mask; f.SubFormat=FLOATSUB;
    WAVEFORMATEX *closest=NULL; HRESULT s=IAudioClient_IsFormatSupported(ac,AUDCLNT_SHAREMODE_SHARED,&f.Format,&closest);
    HRESULT h=IAudioClient_Initialize(ac,AUDCLNT_SHAREMODE_SHARED,0,2000000,0,&f.Format,0);
    printf("%d ch mask %03lx: IsFormatSupported %08lx Initialize %08lx (mix format %u ch mask %03lx)\n",ch,mask,s,h,mf->nChannels,((WAVEFORMATEXTENSIBLE*)mf)->dwChannelMask);
    return 0; }
