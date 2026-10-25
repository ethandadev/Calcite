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

@implementation CalciteOnDevicePairing

#ifdef HAS_PAIRING
static void bonjourReply(DNSServiceRef ref, DNSServiceFlags flags, DNSServiceErrorType err, const char *name,
                         const char *type, const char *domain, void *ctx) {
    CalciteOnDevicePairing *self = (__bridge CalciteOnDevicePairing *)ctx;
    NSLog(@"[Pairing] Bonjour register reply: err=%d name=%s type=%s domain=%s", (int)err, name ?: "", type ?: "", domain ?: "");
    dispatch_async(dispatch_get_main_queue(), ^{
        if (err == kDNSServiceErr_NoError) {
            self.alert.title = @"Ready to pair";
            self.alert.message = @"On this iPhone open Settings > Privacy & Security > Developer Mode and choose \"Calcite\" from the computers list.";
        } else {
            self.alert.title = @"Couldn't advertise";
            self.alert.message = [NSString stringWithFormat:@"Bonjour error %d.\n\nIf the Local Network prompt appeared, allow it. Otherwise open Settings > Privacy & Security > Local Network and turn on Calcite, then try again.", (int)err];
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

    // TXT record via the C API so we get exact errors for bad keys/values.
    TXTRecordRef txtRef;
    uint8_t txtBuf[1300];
    TXTRecordCreate(&txtRef, sizeof(txtBuf), txtBuf);
    for (size_t i = 0; i < calcite_pairing_txt_count(session); i++) {
        const char *k = calcite_pairing_txt_key(session, i), *v = calcite_pairing_txt_value(session, i);
        if (!k || !v) continue;
        DNSServiceErrorType te = TXTRecordSetValue(&txtRef, k, (uint8_t)MIN(strlen(v), 255), v);
        NSLog(@"[Pairing] TXT %s (%zu bytes) -> %d", k, strlen(v), (int)te);
    }
    const char *svcName = calcite_pairing_service_name(session);
    uint16_t port = calcite_pairing_port(session);
    NSLog(@"[Pairing] publishing %s on port %d (TXT %d bytes)", svcName, (int)port, (int)TXTRecordGetLength(&txtRef));
    DNSServiceErrorType rc = DNSServiceRegister(&p->_bonjour, 0, kDNSServiceInterfaceIndexAny, svcName,
        "_remotepairing-pairable-host._tcp", NULL, NULL, htons(port),
        TXTRecordGetLength(&txtRef), TXTRecordGetBytesPtr(&txtRef), bonjourReply, (__bridge void *)p);
    TXTRecordDeallocate(&txtRef);
    NSLog(@"[Pairing] DNSServiceRegister returned %d", (int)rc);
    if (rc == kDNSServiceErr_NoError) {
        DNSServiceSetDispatchQueue(p.bonjour, dispatch_get_main_queue());
    } else {
        showDialog(@"Couldn't advertise", [NSString stringWithFormat:@"Bonjour error %d. Allow Local Network for Calcite in Settings > Privacy & Security > Local Network.", (int)rc]);
        calcite_pairing_free(session);
        current = nil;
        return;
    }

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
            if (p.bonjour) { DNSServiceRefDeallocate(p.bonjour); p.bonjour = NULL; }
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
