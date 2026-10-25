#import "CalciteOnDevicePairing.h"
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
@property(nonatomic) NSNetService *service;
@property(nonatomic, weak) UIViewController *presenter;
@property(nonatomic) UIAlertController *alert;
@property(nonatomic) BOOL finished;
@end

static CalciteOnDevicePairing *current; // one session at a time

static void pinShown(const char *pin, void *ctx) {
    NSString *code = @(pin);
    CalciteOnDevicePairing *self = (__bridge CalciteOnDevicePairing *)ctx;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.alert.title = @"Enter this code on your iPhone";
        self.alert.message = [NSString stringWithFormat:@"\n%@\n\nType it into the prompt that appeared on this iPhone.", code];
    });
}
#endif

@implementation CalciteOnDevicePairing

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

    NSMutableDictionary *txt = [NSMutableDictionary new];
    for (size_t i = 0; i < calcite_pairing_txt_count(session); i++) {
        const char *k = calcite_pairing_txt_key(session, i), *v = calcite_pairing_txt_value(session, i);
        if (k && v) txt[@(k)] = [@(v) dataUsingEncoding:NSUTF8StringEncoding];
    }
    p.service = [[NSNetService alloc] initWithDomain:@"" type:@"_remotepairing-pairable-host._tcp."
        name:@(calcite_pairing_service_name(session)) port:calcite_pairing_port(session)];
    [p.service setTXTRecordData:[NSNetService dataFromTXTRecordDictionary:txt]];
    [p.service publish];

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
            [p.service stop];
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
