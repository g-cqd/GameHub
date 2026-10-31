#define DIRECTINPUT_VERSION 0x0800
#define INITGUID
#include <windows.h>
#include <dinput.h>
#include <stdio.h>
static GUID pad; static int found;
static BOOL CALLBACK cb(LPCDIDEVICEINSTANCEA d, LPVOID p){ pad=d->guidInstance; found=1; return DIENUM_STOP; }
int main(void){ IDirectInput8A *di; IDirectInputDevice8A *dev; DirectInput8Create(GetModuleHandleA(0),DIRECTINPUT_VERSION,&IID_IDirectInput8A,(void**)&di,0);
 IDirectInput8_EnumDevices(di,DI8DEVCLASS_GAMECTRL,cb,0,DIEDFL_ATTACHEDONLY); if(!found){printf("no pad\n");return 1;}
 IDirectInput8_CreateDevice(di,&pad,&dev,0); IDirectInputDevice8_SetDataFormat(dev,&c_dfDIJoystick2);
 DIPROPDWORD b={{sizeof(b),sizeof(DIPROPHEADER),0,DIPH_DEVICE},64}; IDirectInputDevice8_SetProperty(dev,DIPROP_BUFFERSIZE,&b.diph);
 printf("acquire %08lx\n", IDirectInputDevice8_Acquire(dev));
 HRESULT last=1; for(int i=0;i<300;i++){ DIJOYSTATE2 st; IDirectInputDevice8_Poll(dev); HRESULT hr=IDirectInputDevice8_GetDeviceState(dev,sizeof(st),&st);
   DIDEVICEOBJECTDATA d[64]; DWORD n=64; HRESULT h2=IDirectInputDevice8_GetDeviceData(dev,sizeof(d[0]),d,&n,0);
   if(hr!=last){ printf("t=%4d ms GetDeviceState %08lx GetDeviceData %08lx n=%lu\n",i*10,hr,h2,n); last=hr; } Sleep(10); }
 return 0; }
