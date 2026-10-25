#import "CalcitePerformancePack.h"
#import "PLProfiles.h"
#import "LauncherPreferences.h"
#import "ios_uikit_bridge.h"
#import "utils.h"

@implementation CalcitePerformancePack

+ (NSArray<NSDictionary *> *)mods {
    return @[
        @{@"slug": @"sodium",          @"name": @"Sodium"},
        @{@"slug": @"lithium",         @"name": @"Lithium"},
        @{@"slug": @"ferrite-core",    @"name": @"FerriteCore"},
        @{@"slug": @"immediatelyfast", @"name": @"ImmediatelyFast"},
        @{@"slug": @"entityculling",   @"name": @"Entity Culling"},
        @{@"slug": @"dynamic-fps",     @"name": @"Dynamic FPS"},
    ];
}

+ (NSData *)fetch:(NSURL *)url {
    __block NSData *result = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.timeoutInterval = 30;
    [req setValue:@"ethandadev/Calcite (https://github.com/ethandadev/Calcite)" forHTTPHeaderField:@"User-Agent"];
    [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (!err && [(NSHTTPURLResponse *)resp statusCode] == 200) result = data;
        dispatch_semaphore_signal(sem);
    }] resume];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

+ (void)installForSelectedProfileFrom:(UIViewController *)presenter {
    NSDictionary *profile = PLProfiles.current.selectedProfile;
    NSString *versionId = profile[@"lastVersionId"] ?: @"";
    if ([versionId rangeOfString:@"fabric" options:NSCaseInsensitiveSearch].location == NSNotFound &&
        [versionId rangeOfString:@"quilt" options:NSCaseInsensitiveSearch].location == NSNotFound) {
        showDialog(@"Fabric profile needed",
            @"The performance pack works with Fabric. Install Fabric for your Minecraft version first (menu > Install .jar / Fabric), select that profile, then try again.");
        return;
    }
    // "fabric-loader-0.16.9-1.21.4" -> "1.21.4"
    NSString *mc = [versionId componentsSeparatedByString:@"-"].lastObject;
    NSString *gameDir = [NSString stringWithFormat:@"%s/instances/%@/%@", getenv("AME_HOME"),
        getPrefObject(@"general.game_directory"), [PLProfiles resolveKeyForCurrentProfile:@"gameDir"]];
    NSString *modsDir = [[gameDir stringByStandardizingPath] stringByAppendingPathComponent:@"mods"];

    UIAlertController *progress = [UIAlertController alertControllerWithTitle:@"Installing Performance Pack"
        message:[NSString stringWithFormat:@"Minecraft %@\nPlease wait...", mc] preferredStyle:UIAlertControllerStyleAlert];
    [presenter presentViewController:progress animated:YES completion:nil];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray *installed = [NSMutableArray new], *missing = [NSMutableArray new];
        [NSFileManager.defaultManager createDirectoryAtPath:modsDir withIntermediateDirectories:YES attributes:nil error:nil];
        for (NSDictionary *mod in [self mods]) {
            NSString *query = [NSString stringWithFormat:@"https://api.modrinth.com/v2/project/%@/version?loaders=%%5B%%22fabric%%22%%5D&game_versions=%%5B%%22%@%%22%%5D",
                mod[@"slug"], mc];
            NSData *data = [self fetch:[NSURL URLWithString:query]];
            NSArray *versions = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
            NSDictionary *file = nil;
            if ([versions isKindOfClass:NSArray.class] && versions.count > 0) {
                for (NSDictionary *f in versions[0][@"files"]) {
                    if ([f[@"primary"] boolValue]) { file = f; break; }
                }
                file = file ?: [versions[0][@"files"] firstObject];
            }
            NSString *dest = file ? [modsDir stringByAppendingPathComponent:file[@"filename"]] : nil;
            if (!file) { [missing addObject:mod[@"name"]]; continue; }
            if ([NSFileManager.defaultManager fileExistsAtPath:dest]) { [installed addObject:mod[@"name"]]; continue; }
            NSData *jar = [self fetch:[NSURL URLWithString:file[@"url"]]];
            if (jar && [jar writeToFile:dest atomically:YES]) {
                [installed addObject:mod[@"name"]];
            } else {
                [missing addObject:mod[@"name"]];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [progress dismissViewControllerAnimated:YES completion:^{
                NSMutableString *msg = [NSMutableString new];
                if (installed.count) [msg appendFormat:@"Installed: %@.", [installed componentsJoinedByString:@", "]];
                if (missing.count) [msg appendFormat:@"\n\nNot available for %@ yet: %@.", mc, [missing componentsJoinedByString:@", "]];
                [msg appendString:@"\n\nTip: Sodium needs a compatible renderer. Pick MobileGlues in the profile's renderer setting."];
                showDialog(installed.count ? @"Performance Pack ready" : @"Nothing installed", msg);
            }];
        });
    });
}

@end
