/* Injected into a Wine process: does this process hear the HAL's default-output changes? */
#include <CoreAudio/CoreAudio.h>
#include <dispatch/dispatch.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

static FILE *out;
static const AudioObjectPropertyAddress addr = { kAudioHardwarePropertyDefaultOutputDevice,
    kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain };

static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec / 1e9; }
static AudioDeviceID current(void) {
    AudioDeviceID id = 0; UInt32 size = sizeof(id);
    AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, &id);
    return id;
}
static OSStatus listener(AudioObjectID o, UInt32 n, const AudioObjectPropertyAddress *a, void *c) {
    fprintf(out, "%.2f %d listener(callback) fired: default now %u\n", now(), getpid(), current()); fflush(out);
    return 0;
}
static UInt32 running(AudioDeviceID dev) {
    AudioObjectPropertyAddress a = { kAudioDevicePropertyDeviceIsRunningSomewhere, kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain };
    UInt32 v = 0, size = sizeof(v);
    AudioObjectGetPropertyData(dev, &a, 0, NULL, &size, &v);
    return v;
}
static void *poll_thread(void *arg) {
    AudioDeviceID last = 0; UInt32 last87 = 9;
    for (int i = 0; i < 600; i++) {
        AudioDeviceID id = current();
        if (id != last) { fprintf(out, "%.2f %d poll: default %u\n", now(), getpid(), id); fflush(out); last = id; }
        UInt32 r = running(87);
        if (r != last87) { fprintf(out, "%.2f %d poll: speakers (87) running %u\n", now(), getpid(), r); fflush(out); last87 = r; }
        usleep(250000);
    }
    return NULL;
}
static void *late(void *arg);
__attribute__((constructor)) static void start(void) {
    const char *path = getenv("HALPROBE_LOG");
    if (!path) return;
    out = fopen(path, "a");
    fprintf(out, "%.2f %d constructor, main thread %d\n", now(), getpid(), pthread_main_np()); fflush(out);
    if (getenv("HALPROBE_LATE")) { pthread_t t; pthread_create(&t, NULL, late, NULL); return; }
    late(NULL);
}
static void *late(void *arg) {
    if (arg == NULL && getenv("HALPROBE_LATE")) {}
    if (getenv("HALPROBE_LATE")) sleep(4);
    fprintf(out, "%.2f %d first CoreAudio call, main thread %d\n", now(), getpid(), pthread_main_np()); fflush(out);
    if (getenv("HALPROBE_RUNLOOP_NULL")) {
        CFRunLoopRef rl = NULL;
        AudioObjectPropertyAddress r = { kAudioHardwarePropertyRunLoop, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain };
        OSStatus s = AudioObjectSetPropertyData(kAudioObjectSystemObject, &r, 0, NULL, sizeof(rl), &rl);
        fprintf(out, "%.2f set RunLoop NULL: %d\n", now(), (int)s);
    }
    AudioObjectAddPropertyListener(kAudioObjectSystemObject, &addr, listener, NULL);
    AudioObjectAddPropertyListenerBlock(kAudioObjectSystemObject, &addr, dispatch_queue_create("halprobe", NULL),
        ^(UInt32 n, const AudioObjectPropertyAddress *a) {
            fprintf(out, "%.2f %d listener(block) fired: default now %u\n", now(), getpid(), current()); fflush(out);
        });
    pthread_t t; pthread_create(&t, NULL, poll_thread, NULL);
    return NULL;
}
