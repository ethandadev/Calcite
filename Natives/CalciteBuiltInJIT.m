#import "CalciteBuiltInJIT.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#include <unistd.h>
#import "ios_uikit_bridge.h"
#import "utils.h"

// Security SPI to read our own entitlements (see StikJIT's integration guide).
extern void *SecTaskCreateFromSelf(CFAllocatorRef allocator);
extern CFTypeRef SecTaskCopyValueForEntitlement(void *task, CFStringRef entitlement, CFErrorRef *error);

// The private NSExtension API that starts an app extension of our own (the same calls
// LiveContainer uses for its LiveProcess).
@interface NSObject (CalciteNSExtension)
+ (id)extensionWithIdentifier:(NSString *)identifier error:(NSError **)error;
- (void)beginExtensionRequestWithInputItems:(NSArray *)items completion:(void (^)(NSUUID *))completion;
- (void)setRequestCompletionBlock:(void (^)(NSUUID *, NSArray *))block;
- (void)setRequestCancellationBlock:(void (^)(NSUUID *, NSError *))block;
- (void)setRequestInterruptionBlock:(void (^)(NSUUID *))block;
@end

static NSString *const kRequestKey = @"calcite-jit-request";
static NSString *const kResponseKey = @"calcite-jit-response";
static NSMutableArray *sRunning; // keeps extension objects alive until their request ends

@implementation CalciteBuiltInJIT

#pragma mark Pairing file

+ (NSURL *)pairingFileURL {
    NSURL *docs = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    return [[docs URLByAppendingPathComponent:@"StikJIT" isDirectory:YES] URLByAppendingPathComponent:@"pairingFile.plist"];
}

+ (BOOL)hasPairingFile {
    return [NSFileManager.defaultManager fileExistsAtPath:self.pairingFileURL.path];
}

+ (void)importPairingFileFrom:(UIViewController *)presenter {
    NSArray<UTType *> *types = @[
        [UTType typeWithFilenameExtension:@"mobiledevicepairing"] ?: UTTypeData,
        [UTType typeWithFilenameExtension:@"mobiledevicepair"] ?: UTTypeData,
        UTTypePropertyList, UTTypeData,
    ];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
    CalcitePairingPickerDelegate *delegate = [CalcitePairingPickerDelegate delegateWithCompletion:^(NSURL *picked) {
        if (!picked) return;
        NSData *data = [NSData dataWithContentsOfURL:picked];
        if (data.length < 32) {
            showDialog(@"Not a pairing file", @"That file is empty or too small to be a pairing file. Create one for this iPhone with StikDebug's pairing guide, then pick it here.");
            return;
        }
        NSURL *dest = self.pairingFileURL;
        [NSFileManager.defaultManager createDirectoryAtURL:dest.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
        if ([data writeToURL:dest options:NSDataWritingAtomic error:nil]) {
            showDialog(@"Pairing file saved", @"Next: connect LocalDevVPN, then tap \"Prepare JIT\" in these settings.");
        } else {
            showDialog(@"Couldn't save", @"The pairing file could not be saved.");
        }
    }];
    picker.delegate = delegate;
    objc_setAssociatedObject(picker, "calcite.delegate", delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [presenter presentViewController:picker animated:YES completion:nil];
}

#pragma mark Checks

+ (BOOL)hasGetTaskAllow {
    void *task = SecTaskCreateFromSelf(NULL);
    if (!task) return NO;
    CFTypeRef value = SecTaskCopyValueForEntitlement(task, CFSTR("get-task-allow"), NULL);
    BOOL result = value == kCFBooleanTrue;
    if (value) CFRelease(value);
    CFRelease(task);
    return result;
}

+ (NSString *)helperIdentifier {
    NSURL *url = [NSBundle.mainBundle.builtInPlugInsURL URLByAppendingPathComponent:@"CalciteJITHelper.appex"];
    return url ? [NSBundle bundleWithURL:url].bundleIdentifier : nil;
}

+ (NSString *)unavailableReason {
    if (@available(iOS 17.4, *)) {} else return @"Built-in JIT needs iOS 17.4 or later.";
    if (getenv("LC_HOME_PATH") != NULL) return @"Built-in JIT can't run inside LiveContainer. Use StikDebug instead.";
    if (![self helperIdentifier]) return @"This Calcite build has no JIT helper (a sideloader may have removed it). Reinstall Calcite and keep its app extensions.";
    if (![self hasGetTaskAllow]) return @"This installation doesn't have the get-task-allow entitlement. Reinstall with SideStore.";
    if (![self hasPairingFile]) return @"No pairing file yet. Import one in Settings > Import pairing file.";
    return nil;
}

#pragma mark Helper requests

+ (void)send:(NSDictionary *)request completion:(void(^)(BOOL ok, NSString *message, NSNumber *txm))completion {
    void (^fail)(NSString *) = ^(NSString *m) {
        NSLog(@"[CalciteJIT] %@", m);
        dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, m, nil); });
    };
    NSString *identifier = [self helperIdentifier];
    if (!identifier) return fail(@"The JIT helper is missing from this installation.");
    if (!NSClassFromString(@"NSExtension")) {
        dlopen("/System/Library/Frameworks/ExtensionFoundation.framework/ExtensionFoundation", RTLD_NOW);
    }
    Class cls = NSClassFromString(@"NSExtension");
    if (!cls) return fail(@"iOS didn't provide the extension API the JIT helper needs.");

    NSError *error = nil;
    id ext = [cls extensionWithIdentifier:identifier error:&error];
    if (!ext) return fail([NSString stringWithFormat:@"Couldn't find the JIT helper (%@): %@", identifier, error.localizedDescription]);

    NSData *json = [NSJSONSerialization dataWithJSONObject:request options:0 error:nil];
    NSExtensionItem *item = [NSExtensionItem new];
    item.userInfo = @{kRequestKey: json};

    static dispatch_once_t once;
    dispatch_once(&once, ^{ sRunning = [NSMutableArray new]; });
    @synchronized (sRunning) { [sRunning addObject:ext]; }

    __block BOOL done = NO;
    void (^finish)(BOOL, NSString *, NSNumber *) = ^(BOOL ok, NSString *msg, NSNumber *txm) {
        @synchronized (sRunning) {
            if (done) return;
            done = YES;
            [sRunning removeObject:ext];
        }
        dispatch_async(dispatch_get_main_queue(), ^{ completion(ok, msg, txm); });
    };

    [ext setRequestCompletionBlock:^(NSUUID *uuid, NSArray *items) {
        NSData *payload = ((NSExtensionItem *)items.firstObject).userInfo[kResponseKey];
        NSDictionary *resp = payload ? [NSJSONSerialization JSONObjectWithData:payload options:0 error:nil] : nil;
        if (![resp isKindOfClass:NSDictionary.class]) return finish(NO, @"The JIT helper returned no answer.", nil);
        finish([resp[@"success"] boolValue], resp[@"message"] ?: @"", resp[@"txm"]);
    }];
    [ext setRequestCancellationBlock:^(NSUUID *uuid, NSError *err) {
        finish(NO, [NSString stringWithFormat:@"The JIT helper stopped: %@", err.localizedDescription ?: @"cancelled"], nil);
    }];
    [ext setRequestInterruptionBlock:^(NSUUID *uuid) {
        finish(NO, @"The JIT helper was interrupted by iOS.", nil);
    }];
    [ext beginExtensionRequestWithInputItems:@[item] completion:^(NSUUID *uuid) {
        NSLog(@"[CalciteJIT] helper request started: %@", uuid);
    }];
}

+ (NSMutableDictionary *)baseRequest:(NSString *)op {
    NSMutableDictionary *r = [@{@"op": op} mutableCopy];
    NSData *pairing = [NSData dataWithContentsOfURL:self.pairingFileURL];
    if (pairing) r[@"pairing"] = [pairing base64EncodedStringWithOptions:0];
    return r;
}

+ (void)enableForCurrentProcess:(void (^)(BOOL, NSString *))completion {
    NSString *reason = [self unavailableReason];
    if (reason) { completion(NO, reason); return; }
    NSData *script = [NSData dataWithContentsOfFile:[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"UniversalJIT26.js"]];
    if (!script) { completion(NO, @"The bundled JIT script is missing."); return; }
    NSMutableDictionary *r = [self baseRequest:@"enable"];
    r[@"pid"] = @(getpid());
    r[@"script"] = [script base64EncodedStringWithOptions:0];
    r[@"force"] = @YES;
    [self send:r completion:^(BOOL ok, NSString *message, NSNumber *txm) { completion(ok, message); }];
}

+ (void)prepareFrom:(UIViewController *)presenter {
    NSString *reason = [self unavailableReason];
    if (reason) { showDialog(@"Built-in JIT", reason); return; }
    UIAlertController *wait = [UIAlertController alertControllerWithTitle:@"Preparing JIT"
        message:@"Checking LocalDevVPN and the Developer Disk Image. The first run downloads a few files, so this can take a minute."
        preferredStyle:UIAlertControllerStyleAlert];
    [presenter presentViewController:wait animated:YES completion:nil];
    [self send:[self baseRequest:@"prepare"] completion:^(BOOL ok, NSString *message, NSNumber *txm) {
        [wait dismissViewControllerAnimated:YES completion:^{
            NSString *txmText = txm ? (txm.boolValue ? @"TXM: present" : @"TXM: not present") : @"TXM: unknown";
            showDialog(ok ? @"JIT is ready" : @"JIT isn't ready", [NSString stringWithFormat:@"%@\n\n%@", message, txmText]);
        }];
    }];
}

+ (void)resetDDIFrom:(UIViewController *)presenter {
    NSString *reason = [self unavailableReason];
    if (reason) { showDialog(@"Built-in JIT", reason); return; }
    [self send:[self baseRequest:@"reset"] completion:^(BOOL ok, NSString *message, NSNumber *txm) {
        showDialog(ok ? @"Done" : @"Failed", message);
    }];
}

@end

#pragma mark - Picker delegate

@implementation CalcitePairingPickerDelegate {
    void (^_completion)(NSURL *);
}
+ (instancetype)delegateWithCompletion:(void (^)(NSURL *))completion {
    CalcitePairingPickerDelegate *d = [self new];
    d->_completion = [completion copy];
    return d;
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    _completion(urls.firstObject);
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    _completion(nil);
}
@end
