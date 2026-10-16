/* Time the CoreText calls of win32u load_mac_fonts() vs alternatives; print the URL set. */
#include <CoreText/CoreText.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <stdlib.h>

static double now(void){ struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t); return t.tv_sec+t.tv_nsec*1e-9; }
static double cpu(void){ struct timespec t; clock_gettime(CLOCK_PROCESS_CPUTIME_ID,&t); return t.tv_sec+t.tv_nsec*1e-9; }

static int skip_ext(CFURLRef url){
    CFStringRef ext = CFURLCopyPathExtension(url); int skip=0;
    if (ext){ skip = CFStringCompare(ext,CFSTR("pfa"),kCFCompareCaseInsensitive)==0 || CFStringCompare(ext,CFSTR("pfb"),kCFCompareCaseInsensitive)==0; CFRelease(ext);}
    return skip;
}
static void dump(const void *v, void *ctx){
    char p[4096]; CFStringRef s = CFURLCopyFileSystemPath(v,kCFURLPOSIXPathStyle);
    if (s && CFStringGetFileSystemRepresentation(s,p,sizeof p)) fprintf(ctx,"%s\n",p);
    if (s) CFRelease(s);
}
int main(int argc, char **argv){
    const char *mode = argc>1?argv[1]:"orig"; FILE *out = argc>2?fopen(argv[2],"w"):NULL;
    double t0=now(), c0=cpu(), t1, t2;
    CFMutableSetRef urls = CFSetCreateMutable(NULL,0,&kCFTypeSetCallBacks);
    long ndesc=0;
    if (!strcmp(mode,"orig") || !strcmp(mode,"nodup")){
        CFStringRef k = kCTFontCollectionRemoveDuplicatesOption; CFBooleanRef v = kCFBooleanTrue;
        CFDictionaryRef opt = !strcmp(mode,"orig") ? CFDictionaryCreate(NULL,(const void**)&k,(const void**)&v,1,&kCFTypeDictionaryKeyCallBacks,&kCFTypeDictionaryValueCallBacks) : NULL;
        CTFontCollectionRef col = CTFontCollectionCreateFromAvailableFonts(opt);
        if (opt) CFRelease(opt);
        t1=now();
        CFArrayRef descs = CTFontCollectionCreateMatchingFontDescriptors(col); CFRelease(col);
        t2=now();
        ndesc = CFArrayGetCount(descs);
        for (CFIndex i=0;i<ndesc;i++){
            CFURLRef u = CTFontDescriptorCopyAttribute(CFArrayGetValueAtIndex(descs,i),kCTFontURLAttribute);
            if (!u) continue; if (!skip_ext(u)) CFSetAddValue(urls,u); CFRelease(u);
        }
        CFRelease(descs);
    } else { /* fmurls */
        CFArrayRef a = CTFontManagerCopyAvailableFontURLs();
        t1=t2=now();
        ndesc = CFArrayGetCount(a);
        for (CFIndex i=0;i<ndesc;i++){ CFURLRef u=CFArrayGetValueAtIndex(a,i); if (!skip_ext(u)) CFSetAddValue(urls,u); }
        CFRelease(a);
    }
    double t3=now(), c3=cpu();
    fprintf(stderr,"%s wall_ms=%.1f (create=%.1f match=%.1f urls=%.1f) cpu_ms=%.1f ndesc=%ld nurls=%ld\n",mode,(t3-t0)*1e3,(t1-t0)*1e3,(t2-t1)*1e3,(t3-t2)*1e3,(c3-c0)*1e3,ndesc,(long)CFSetGetCount(urls));
    if (out){ CFSetApplyFunction(urls,dump,out); fclose(out);}
    return 0;
}
