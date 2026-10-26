#import "CalciteOnDevicePairing.h"
#include <dns_sd.h>
#include <arpa/inet.h>
#import "CalciteBuiltInJIT.h"
#import "ios_uikit_bridge.h"
#import "utils.h"

#if __has_include("pairing/calcite_pairing.h") && defined(CALCITE_HAS_PAIRING)
#include "pairing/calcite_pairing.h"
#define HAS_PAIRING 1
#endif

#ifdef HAS_PAIRING
@interface CalciteOnDevicePairing ()
@property(nonatomic) CalcitePairing *session;
@property(nonatomic) DNSServiceRef bonjour;
@property(nonatomic, weak) UIViewController *presenter;
@property(nonatomic) UIAlertController *alert;
@property(nonatomic) BOOL finished;
@property(nonatomic) int retries;
@end

static CalciteOnDevicePairing *current; // one session at a time

static void pinShown(const char *msg, void *ctx) {
    NSString *text = @(msg);
    NSLog(@"[Pairing] %@", text);
    CalciteOnDevicePairing *self = (__bridge CalciteOnDevicePairing *)ctx;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([text hasPrefix:@"PIN:"]) {
            self.alert.title = @"Enter this code on your iPhone";
            self.alert.message = [NSString stringWithFormat:@"\n%@\n\nType it into the prompt that appeared on this iPhone.", [text substringFromIndex:4]];
        } else if ([text hasPrefix:@"EVT:"]) {
            self.alert.title = @"Pairing…";
            self.alert.message = [text substringFromIndex:4];
        }
    });
}
#endif

#ifdef HAS_PAIRING
static void bonjourReply(DNSServiceRef ref, DNSServiceFlags flags, DNSServiceErrorType err, const char *name,
                         const char *type, const char *domain, void *ctx);
static void registerService(CalciteOnDevicePairing *p) {
    if (p.finished || !p.session) return;
    CalcitePairing *session = p.session;
    TXTRecordRef txtRef;
    uint8_t txtBuf[1300];
    TXTRecordCreate(&txtRef, sizeof(txtBuf), txtBuf);
    for (size_t i = 0; i < calcite_pairing_txt_count(session); i++) {
        const char *k = calcite_pairing_txt_key(session, i), *v = calcite_pairing_txt_value(session, i);
        if (!k || !v) continue;
        TXTRecordSetValue(&txtRef, k, (uint8_t)MIN(strlen(v), 255), v);
    }
    const char *svcName = calcite_pairing_service_name(session);
    uint16_t port = calcite_pairing_port(session);
    DNSServiceRef ref = NULL;
    DNSServiceErrorType rc = DNSServiceRegister(&ref, 0, kDNSServiceInterfaceIndexAny, svcName,
        "_remotepairing-pairable-host._tcp", NULL, NULL, htons(port),
        TXTRecordGetLength(&txtRef), TXTRecordGetBytesPtr(&txtRef), bonjourReply, (__bridge void *)p);
    TXTRecordDeallocate(&txtRef);
    NSLog(@"[Pairing] DNSServiceRegister (try %d) returned %d", (int)p.retries, (int)rc);
    if (rc == kDNSServiceErr_NoError) {
        p.bonjour = ref;
        DNSServiceSetDispatchQueue(ref, dispatch_get_main_queue());
    } else {
        showDialog(@"Couldn't advertise", [NSString stringWithFormat:@"Bonjour error %d. Allow Local Network for Calcite in Settings > Privacy & Security > Local Network.", (int)rc]);
    }
}
#endif

@implementation CalciteOnDevicePairing

#ifdef HAS_PAIRING
static void bonjourReply(DNSServiceRef ref, DNSServiceFlags flags, DNSServiceErrorType err, const char *name,
                         const char *type, const char *domain, void *ctx) {
    CalciteOnDevicePairing *self = (__bridge CalciteOnDevicePairing *)ctx;
    NSLog(@"[Pairing] Bonjour register reply: err=%d name=%s type=%s domain=%s", (int)err, name ?: "", type ?: "", domain ?: "");
    dispatch_async(dispatch_get_main_queue(), ^{
        if (err == kDNSServiceErr_NoError) {
            self.retries = 0;
            self.alert.title = @"Ready to pair";
            self.alert.message = @"On this iPhone open Settings > Privacy & Security > Developer Mode and choose \"Calcite\" from the computers list.";
        } else if (self.retries < 25 && !self.finished) {
            // mDNSResponder sometimes drops the registration right after accepting it; the listener is
            // still open, so just register again.
            self.retries++;
            if (self.bonjour) { DNSServiceRefDeallocate(self.bonjour); self.bonjour = NULL; }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ registerService(self); });
        } else if (!self.finished) {
            self.alert.title = @"Couldn't advertise";
            self.alert.message = [NSString stringWithFormat:@"Bonjour error %d after %d tries.\n\nMake sure Local Network is on for Calcite in Settings, then try again.", (int)err, (int)self.retries];
        }
    });
}
#endif

+ (BOOL)isSupported {
#ifdef HAS_PAIRING
    return YES;
#else
    return NO;
#endif
}

+ (void)startFrom:(UIViewController *)presenter {
#ifndef HAS_PAIRING
    showDialog(@"Not in this build", @"This build of Calcite was made without the on-device pairing library. Import a pairing file instead.");
#else
    if (current) return;
    char *err = NULL;
    CalcitePairing *session = calcite_pairing_new("Calcite", &err);
    if (!session) {
        showDialog(@"Couldn't start pairing", err ? @(err) : @"Unknown error");
        if (err) calcite_pairing_string_free(err);
        return;
    }
    CalciteOnDevicePairing *p = [CalciteOnDevicePairing new];
    p.session = session;
    p.presenter = presenter;
    current = p;

    registerService(p);
    if (!p.bonjour) { calcite_pairing_free(session); current = nil; return; }

    p.alert = [UIAlertController alertControllerWithTitle:@"Pair this iPhone"
        message:@"Open Settings > Privacy & Security > Developer Mode on this iPhone and choose \"Calcite\" from the list of computers. A code will appear here.\n\nAllow Local Network access if asked."
        preferredStyle:UIAlertControllerStyleAlert];
    [p.alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a) {
        calcite_pairing_cancel(p.session);
    }]];
    [presenter presentViewController:p.alert animated:YES completion:nil];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        uint8_t *bytes = NULL; size_t len = 0; char *error = NULL;
        int32_t rc = calcite_pairing_accept(p.session, pinShown, (__bridge void *)p, &bytes, &len, &error);
        NSData *plist = (rc == 0 && bytes) ? [NSData dataWithBytes:bytes length:len] : nil;
        NSString *msg = error ? @(error) : nil;
        if (bytes) calcite_pairing_bytes_free(bytes, len);
        if (error) calcite_pairing_string_free(error);
        dispatch_async(dispatch_get_main_queue(), ^{
            p.finished = YES; if (p.bonjour) { DNSServiceRefDeallocate(p.bonjour); p.bonjour = NULL; }
            calcite_pairing_free(p.session);
            p.session = NULL;
            current = nil;
            [p.alert dismissViewControllerAnimated:YES completion:^{
                if (rc == 0 && plist) {
                    NSURL *dest = CalciteBuiltInJIT.pairingFileURL;
                    [NSFileManager.defaultManager createDirectoryAtURL:dest.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
                    if ([plist writeToURL:dest options:NSDataWritingAtomic error:nil]) {
                        showDialog(@"Paired", @"Pairing file saved. Connect LocalDevVPN, then tap \"Prepare JIT\".");
                    } else {
                        showDialog(@"Couldn't save", @"The pairing file could not be written.");
                    }
                } else if (rc == 1) {
                    showDialog(@"Pairing failed", msg ?: @"Unknown error");
                }
            }];
        });
    });
#endif
}

@end
