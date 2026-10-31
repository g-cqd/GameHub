#include <windows.h>
#include <stdio.h>
int main(void) {
    DEVMODEA dm = {0}; dm.dmSize = sizeof(dm);
    EnumDisplaySettingsA(NULL, ENUM_CURRENT_SETTINGS, &dm);
    printf("current %lux%lu\n", dm.dmPelsWidth, dm.dmPelsHeight);
    DEVMODEA m = dm; m.dmPelsWidth = 1920; m.dmPelsHeight = 1080; m.dmFields = DM_PELSWIDTH | DM_PELSHEIGHT;
    printf("set 1920x1080: %ld\n", ChangeDisplaySettingsA(&m, CDS_FULLSCREEN));
    Sleep(1500);
    printf("restore: %ld\n", ChangeDisplaySettingsA(NULL, 0));
    return 0;
}
