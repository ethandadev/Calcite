#import <UIKit/UIKit.h>

/// Built-in JIT. Instead of bouncing to StikDebug, Calcite asks its own helper app extension
/// (which links StikJIT) to attach a debugger to Calcite from the outside. Needs an imported
/// pairing file and LocalDevVPN.
@interface CalciteBuiltInJIT : NSObject

/// nil when built-in JIT can be used, otherwise a human-readable reason it can't.
+ (NSString *)unavailableReason;

+ (BOOL)hasPairingFile;

/// Lets the user pick a pairing file and stores it for the helper.
+ (void)importPairingFileFrom:(UIViewController *)presenter;

/// Checks the device is reachable and the Developer Disk Image is mounted (downloads it if needed).
+ (void)prepareFrom:(UIViewController *)presenter;

/// Clears the cached Developer Disk Image.
+ (void)resetDDIFrom:(UIViewController *)presenter;

/// Starts JIT for this process. `completion(success, message)` runs when the helper finishes:
/// failure comes back quickly; success only once the debugger has detached again.
+ (void)enableForCurrentProcess:(void(^)(BOOL success, NSString *message))completion;

@end

/// Internal: delegate for the pairing-file picker.
@interface CalcitePairingPickerDelegate : NSObject <UIDocumentPickerDelegate>
+ (instancetype)delegateWithCompletion:(void(^)(NSURL *picked))completion;
@end
