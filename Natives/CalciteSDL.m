#import <dlfcn.h>
#import "CalciteSDL.h"
#import "SurfaceViewController.h"
#import "glfw_keycodes.h"
#import "utils.h"
#import "environ.h"

// Minimal mirror of the SDL3 ABI pieces we need. SDL_Event is a 128 byte union; we fill the raw
// bytes at the documented offsets rather than importing SDL's headers (the library is loaded
// dynamically by LWJGL, we never link against it).
typedef struct SDL_Window SDL_Window;
typedef union { uint8_t raw[128]; uint32_t type; } CalciteSDLEvent;

enum {
    kKeyDown = 0x300, kKeyUp = 0x301, kTextInput = 0x303,
    kMouseMotion = 0x400, kMouseDown = 0x401, kMouseUp = 0x402, kMouseWheel = 0x403,
};

static bool (*p_PushEvent)(CalciteSDLEvent *);
static SDL_Window **(*p_GetWindows)(int *);
static bool (*p_GetRelative)(SDL_Window *);
static uint32_t (*p_GetWindowID)(SDL_Window *);
static void (*p_Warp)(SDL_Window *, float, float);
static void (*p_SetMod)(uint16_t);
static void (*p_Free)(void *);

static SDL_Window *sdlWindow;
static uint16_t modState;
static CGFloat lastX, lastY;
static BOOL started;

static BOOL resolve(void) {
    static void *lib;
    if (!lib) {
        const char *fw = [NSString stringWithFormat:@"%@/Frameworks341/libSDL3.dylib", NSBundle.mainBundle.bundlePath].UTF8String;
        lib = dlopen(fw, RTLD_LAZY | RTLD_NOLOAD);   // only if the game already loaded it
        if (!lib) return NO;
        p_PushEvent = dlsym(lib, "SDL_PushEvent");
        p_GetWindows = dlsym(lib, "SDL_GetWindows");
        p_GetRelative = dlsym(lib, "SDL_GetWindowRelativeMouseMode");
        p_GetWindowID = dlsym(lib, "SDL_GetWindowID");
        p_Warp = dlsym(lib, "SDL_WarpMouseInWindow");
        p_SetMod = dlsym(lib, "SDL_SetModState");
        p_Free = dlsym(lib, "SDL_free");
        void (*setMainReady)(void) = dlsym(lib, "SDL_SetMainReady");
        if (setMainReady) setMainReady();
        NSLog(@"[CalciteSDL] SDL3 resolved (push=%p windows=%p)", p_PushEvent, p_GetWindows);
    }
    return p_PushEvent && p_GetWindows;
}

static SDL_Window *currentWindow(void) {
    if (sdlWindow) return sdlWindow;
    if (!resolve()) return NULL;
    int n = 0;
    SDL_Window **list = p_GetWindows(&n);
    if (list && n > 0) {
        sdlWindow = list[0];
        NSLog(@"[CalciteSDL] adopted SDL window %p (%d total)", sdlWindow, n);
    }
    if (list && p_Free) p_Free(list);
    return sdlWindow;
}

BOOL CalciteSDL_active(void) {
    if (!getenv("CALCITE_LWJGL34")) return NO;
    return currentWindow() != NULL;
}

#pragma mark - Event helpers

static void fill(CalciteSDLEvent *e, uint32_t type) {
    memset(e, 0, sizeof(*e));
    e->type = type;
    uint64_t ts = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    memcpy(e->raw + 8, &ts, 8);
    uint32_t wid = p_GetWindowID ? p_GetWindowID(sdlWindow) : 0;
    memcpy(e->raw + 16, &wid, 4);
    uint32_t which = 1;
    memcpy(e->raw + 20, &which, 4);
}

// GLFW key -> USB HID usage (== SDL scancode).
static int scancodeForGLFW(int k) {
    if (k >= 65 && k <= 90) return 4 + (k - 65);          // A-Z
    if (k >= 49 && k <= 57) return 30 + (k - 49);         // 1-9
    if (k == 48) return 39;
    if (k >= 290 && k <= 301) return 58 + (k - 290);      // F1-F12
    if (k >= 302 && k <= 313) return 104 + (k - 302);     // F13-F24
    if (k >= 321 && k <= 329) return 89 + (k - 321);      // KP 1-9
    switch (k) {
        case 32: return 44;  case 39: return 52;  case 44: return 54;  case 45: return 45;
        case 46: return 55;  case 47: return 56;  case 59: return 51;  case 61: return 46;
        case 91: return 47;  case 92: return 49;  case 93: return 48;  case 96: return 53;
        case 256: return 41; case 257: return 40; case 258: return 43; case 259: return 42;
        case 260: return 73; case 261: return 76; case 262: return 79; case 263: return 80;
        case 264: return 81; case 265: return 82; case 266: return 75; case 267: return 78;
        case 268: return 74; case 269: return 77; case 280: return 57; case 281: return 71;
        case 282: return 83; case 283: return 70; case 284: return 72;
        case 320: return 98; case 330: return 99; case 331: return 84; case 332: return 85;
        case 333: return 86; case 334: return 87; case 335: return 88; case 336: return 103;
        case 340: return 225; case 341: return 224; case 342: return 226; case 343: return 227;
        case 344: return 229; case 345: return 228; case 346: return 230; case 347: return 231;
        case 348: return 101;
    }
    return 0;
}

static uint16_t modForScancode(int sc) {
    switch (sc) {
        case 225: return 0x1;   case 229: return 0x2;
        case 224: return 0x40;  case 228: return 0x80;
        case 226: return 0x100; case 230: return 0x200;
        case 227: return 0x400; case 231: return 0x800;
    }
    return 0;
}

// SDL keycode: lowercase ASCII for printable keys, scancode | 1<<30 for the rest.
static uint32_t keycodeFor(int glfwKey, int scancode) {
    if (glfwKey >= 65 && glfwKey <= 90) return glfwKey + 32;
    if (glfwKey >= 32 && glfwKey < 127) return glfwKey;
    if (glfwKey == 257) return '\r';
    if (glfwKey == 258) return '\t';
    if (glfwKey == 259) return '\b';
    if (glfwKey == 256) return 0x1B;
    if (glfwKey == 261) return 0x7F;
    return scancode | 0x40000000;
}

#pragma mark - Public input API

void CalciteSDL_key(int glfwKey, int action) {
    if (!currentWindow()) return;
    int sc = scancodeForGLFW(glfwKey);
    if (sc == 0) return;
    uint16_t m = modForScancode(sc);
    if (m) {
        if (action) modState |= m; else modState &= ~m;
        if (p_SetMod) p_SetMod(modState);
    }
    CalciteSDLEvent e;
    fill(&e, action ? kKeyDown : kKeyUp);
    uint32_t scu = sc, key = keycodeFor(glfwKey, sc);
    memcpy(e.raw + 24, &scu, 4);
    memcpy(e.raw + 28, &key, 4);
    memcpy(e.raw + 32, &modState, 2);
    e.raw[36] = action ? 1 : 0;   // down
    e.raw[37] = 0;                // repeat
    p_PushEvent(&e);
}

void CalciteSDL_button(int glfwButton, int action) {
    if (!currentWindow()) return;
    // GLFW: 0 left, 1 right, 2 middle.  SDL: 1 left, 2 middle, 3 right, 4/5 extra.
    static const uint8_t map[] = {1, 3, 2, 4, 5};
    uint8_t b = glfwButton >= 0 && glfwButton < 5 ? map[glfwButton] : 0;
    if (!b) return;
    CalciteSDLEvent e;
    fill(&e, action ? kMouseDown : kMouseUp);
    e.raw[24] = b;
    e.raw[25] = action ? 1 : 0;
    e.raw[26] = 1;                // clicks
    float x = lastX, y = lastY;
    memcpy(e.raw + 28, &x, 4);
    memcpy(e.raw + 32, &y, 4);
    p_PushEvent(&e);
}

void CalciteSDL_cursor(char event, CGFloat x, CGFloat y) {
    if (!currentWindow()) return;
    CGFloat scale = UIScreen.mainScreen.scale;
    BOOL relative = p_GetRelative && p_GetRelative(sdlWindow);
    CGFloat nx = x / scale, ny = y / scale;   // pixels -> points

    CGFloat dx = 0, dy = 0;
    if (event == ACTION_MOVE_MOTION) {          // x/y already are deltas
        dx = nx; dy = ny;
        lastX += dx; lastY += dy;
    } else {
        dx = nx - lastX; dy = ny - lastY;
        if (event == ACTION_DOWN || event == ACTION_UP) { dx = 0; dy = 0; }
        lastX = nx; lastY = ny;
    }

    if (relative) {
        if (dx == 0 && dy == 0) return;
        CalciteSDLEvent e;
        fill(&e, kMouseMotion);
        float fx = lastX, fy = lastY, fdx = dx, fdy = dy;
        memcpy(e.raw + 28, &fx, 4);
        memcpy(e.raw + 32, &fy, 4);
        memcpy(e.raw + 36, &fdx, 4);
        memcpy(e.raw + 40, &fdy, 4);
        p_PushEvent(&e);
    } else if (p_Warp) {
        p_Warp(sdlWindow, lastX, lastY);
    }
}

void CalciteSDL_scroll(CGFloat x, CGFloat y) {
    if (!currentWindow()) return;
    CalciteSDLEvent e;
    fill(&e, kMouseWheel);
    float fx = x, fy = y, mx = lastX, my = lastY;
    memcpy(e.raw + 24, &fx, 4);
    memcpy(e.raw + 28, &fy, 4);
    memcpy(e.raw + 36, &mx, 4);
    memcpy(e.raw + 40, &my, 4);
    p_PushEvent(&e);
}

void CalciteSDL_text(unsigned int cp) {
    if (!currentWindow() || cp == 0) return;
    static char buf[8];
    int n = 0;
    if (cp < 0x80) { buf[n++] = cp; }
    else if (cp < 0x800) { buf[n++] = 0xC0 | (cp >> 6); buf[n++] = 0x80 | (cp & 0x3F); }
    else if (cp < 0x10000) { buf[n++] = 0xE0 | (cp >> 12); buf[n++] = 0x80 | ((cp >> 6) & 0x3F); buf[n++] = 0x80 | (cp & 0x3F); }
    else { buf[n++] = 0xF0 | (cp >> 18); buf[n++] = 0x80 | ((cp >> 12) & 0x3F); buf[n++] = 0x80 | ((cp >> 6) & 0x3F); buf[n++] = 0x80 | (cp & 0x3F); }
    buf[n] = 0;
    CalciteSDLEvent e;
    fill(&e, kTextInput);
    const char *p = buf;
    memcpy(e.raw + 24, &p, sizeof(p));
    p_PushEvent(&e);
}

#pragma mark - Window adoption / grab sync

static void adoptSDLWindows(void) {
    UIWindow *main = UIWindow.mainWindow;
    if (!main) return;
    BOOL found = NO;
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        if (w == main) continue;
        if (![NSStringFromClass(w.class) hasPrefix:@"SDL"]) continue;
        found = YES;
        if (w.windowLevel >= main.windowLevel) {
            w.windowLevel = main.windowLevel - 1;   // behind us; we are transparent over it
            w.hidden = NO;
            [main makeKeyWindow];
            main.backgroundColor = UIColor.clearColor;
            main.rootViewController.view.backgroundColor = UIColor.clearColor;
            SurfaceViewController *vc = (SurfaceViewController *)main.rootViewController;
            if ([vc isKindOfClass:SurfaceViewController.class]) {
                vc.touchView.backgroundColor = UIColor.clearColor;
                vc.surfaceView.hidden = YES;
            }
            NSLog(@"[CalciteSDL] moved SDL window %@ behind the Calcite window", w);
        }
    }
    if (!found) return;

    // Mirror SDL's relative-mouse mode (the game's "grab") into Calcite's touch handling.
    if (CalciteSDL_active() && p_GetRelative) {
        BOOL grab = p_GetRelative(sdlWindow);
        if (grab != (isGrabbing == JNI_TRUE)) {
            isGrabbing = grab ? JNI_TRUE : JNI_FALSE;
            SurfaceViewController *vc = (SurfaceViewController *)main.rootViewController;
            if ([vc isKindOfClass:SurfaceViewController.class]) [vc updateGrabState];
        }
    }
}

void CalciteSDL_startAdopter(void) {
    if (started || !getenv("CALCITE_LWJGL34")) return;
    started = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *t) { adoptSDLWindows(); }];
    });
}

void CalciteSDL_preseedHints(void) {
    NSString *path = [NSString stringWithFormat:@"%@/Frameworks341/libSDL3.dylib", NSBundle.mainBundle.bundlePath];
    void *lib = dlopen(path.UTF8String, RTLD_LAZY | RTLD_GLOBAL);
    if (!lib) { NSLog(@"[CalciteSDL] could not preload SDL3: %s", dlerror()); return; }
    bool (*setHint)(const char *, const char *) = dlsym(lib, "SDL_SetHint");
    if (!setHint) return;
    setHint("SDL_ORIENTATIONS", "LandscapeLeft LandscapeRight");
    setHint("SDL_ENABLE_SCREEN_KEYBOARD", "0");
    NSLog(@"[CalciteSDL] preseeded SDL hints");
}
