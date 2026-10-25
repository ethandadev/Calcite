#import "CalciteSkinManager.h"
#import "authenticator/BaseAuthenticator.h"
#import "ios_uikit_bridge.h"
#import "utils.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface CalciteSkinManager ()
@property(nonatomic, weak) UIViewController *presenter;
@property(nonatomic) NSString *variant;
@end

static CalciteSkinManager *activeManager; // keeps the picker delegate alive

@implementation CalciteSkinManager

+ (void)presentFrom:(UIViewController *)presenter {
    BaseAuthenticator *auth = BaseAuthenticator.current;
    NSString *token = auth.authData[@"accessToken"];
    if (!auth || !token || [token isEqualToString:@"offline"]) {
        showDialog(@"Microsoft account needed",
            @"Skins live on Mojang's servers, so they can only be changed for a signed-in Microsoft account. "
            @"Offline accounts show a skin through Cosmetica instead (Settings > General > Cosmetica).");
        return;
    }
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Skin Manager"
        message:[NSString stringWithFormat:@"Signed in as %@", auth.authData[@"username"] ?: @"your account"]
        preferredStyle:UIAlertControllerStyleActionSheet];
    a.popoverPresentationController.sourceView = presenter.view;
    a.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds), CGRectGetMidY(presenter.view.bounds), 1, 1);
    for (NSArray *v in @[@[@"Upload skin (Classic arms)", @"classic"], @[@"Upload skin (Slim arms)", @"slim"]]) {
        [a addAction:[UIAlertAction actionWithTitle:v[0] style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
            CalciteSkinManager *m = [CalciteSkinManager new];
            m.presenter = presenter;
            m.variant = v[1];
            activeManager = m;
            UIDocumentPickerViewController *p = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypePNG] asCopy:YES];
            p.delegate = m;
            [presenter presentViewController:p animated:YES completion:nil];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Reset to default skin" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x) {
        [self call:@"DELETE" token:nil body:nil boundary:nil from:presenter done:@"Your skin was reset."];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [presenter presentViewController:a animated:YES completion:nil];
}

+ (void)call:(NSString *)method token:(id)unused body:(NSData *)body boundary:(NSString *)boundary
        from:(UIViewController *)presenter done:(NSString *)okMessage {
    UIAlertController *wait = [UIAlertController alertControllerWithTitle:@"Working..." message:nil preferredStyle:UIAlertControllerStyleAlert];
    [presenter presentViewController:wait animated:YES completion:nil];
    void (^send)(void) = ^{
        NSString *token = BaseAuthenticator.current.authData[@"accessToken"];
        NSString *url = [method isEqualToString:@"DELETE"]
            ? @"https://api.minecraftservices.com/minecraft/profile/skins/active"
            : @"https://api.minecraftservices.com/minecraft/profile/skins";
        NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
        r.HTTPMethod = method;
        r.timeoutInterval = 30;
        [r setValue:[@"Bearer " stringByAppendingString:token ?: @""] forHTTPHeaderField:@"Authorization"];
        if (body) {
            [r setValue:[@"multipart/form-data; boundary=" stringByAppendingString:boundary] forHTTPHeaderField:@"Content-Type"];
            r.HTTPBody = body;
        }
        [[NSURLSession.sharedSession dataTaskWithRequest:r completionHandler:^(NSData *d, NSURLResponse *resp, NSError *err) {
            NSInteger code = [(NSHTTPURLResponse *)resp statusCode];
            dispatch_async(dispatch_get_main_queue(), ^{
                [wait dismissViewControllerAnimated:YES completion:^{
                    if (!err && code >= 200 && code < 300) {
                        showDialog(@"Done", [okMessage stringByAppendingString:@" It can take a minute to show up in game."]);
                    } else {
                        NSString *detail = d.length ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] : err.localizedDescription;
                        showDialog(@"Skin change failed", [NSString stringWithFormat:@"HTTP %ld\n%@\n\nIf the login expired, log out and in again from the account menu.", (long)code, detail ?: @""]);
                    }
                }];
            });
        }] resume];
    };
    [BaseAuthenticator.current refreshTokenWithCallback:^(id status, BOOL success) { send(); }];
}

- (void)documentPicker:(UIDocumentPickerViewController *)c didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSData *png = [NSData dataWithContentsOfURL:urls.firstObject];
    UIImage *img = png ? [UIImage imageWithData:png] : nil;
    // Skins are 64x64 (or legacy 64x32).
    if (!img || (int)img.size.width != 64 || ((int)img.size.height != 64 && (int)img.size.height != 32)) {
        showDialog(@"Not a skin", @"Skin files must be 64×64 PNG images.");
        activeManager = nil;
        return;
    }
    NSString *boundary = [NSString stringWithFormat:@"calcite-%@", NSUUID.UUID.UUIDString];
    NSMutableData *body = [NSMutableData new];
    void (^add)(NSString *) = ^(NSString *s) { [body appendData:[s dataUsingEncoding:NSUTF8StringEncoding]]; };
    add([NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"variant\"\r\n\r\n%@\r\n", boundary, self.variant]);
    add([NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"file\"; filename=\"skin.png\"\r\nContent-Type: image/png\r\n\r\n", boundary]);
    [body appendData:png];
    add([NSString stringWithFormat:@"\r\n--%@--\r\n", boundary]);
    [CalciteSkinManager call:@"POST" token:nil body:body boundary:boundary from:self.presenter done:@"Skin uploaded."];
    activeManager = nil;
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)c { activeManager = nil; }

@end
