#import <UIKit/UIKit.h>

// Bridge between Calcite's touch/keyboard handling and SDL3, which Minecraft 26.3+ uses
// for its window and input instead of GLFW. All of this is inert unless the game was launched
// with the LWJGL 3.4 stack (CALCITE_LWJGL34=1).

// YES once SDL has been loaded into this process by the game and has a window.
BOOL CalciteSDL_active(void);

// Starts the main-thread watcher that finds SDL's UIWindow and places it behind the
// (transparent) Calcite window so the game shows through under our touch controls.
void CalciteSDL_startAdopter(void);

void CalciteSDL_key(int glfwKey, int action);
void CalciteSDL_button(int glfwButton, int action);
// event is Calcite's ACTION_* value; x/y are pixel coordinates (or deltas for ACTION_MOVE_MOTION).
void CalciteSDL_cursor(char event, CGFloat x, CGFloat y);
void CalciteSDL_scroll(CGFloat x, CGFloat y);
void CalciteSDL_text(unsigned int codepoint);
