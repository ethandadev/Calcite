#import "CalciteHealthCheck.h"
#import "CalciteBuiltInJIT.h"
#import "authenticator/BaseAuthenticator.h"
#import "LauncherPreferences.h"
#import "PLProfiles.h"
#import "ios_uikit_bridge.h"
#import "utils.h"

@implementation CalciteHealthCheck

+ (NSString *)line:(BOOL)ok title:(NSString *)t detail:(NSString *)d {
    return [NSString stringWithFormat:@"%@ %@%@", ok ? @"✅" : @"⚠️", t, d.length ? [@"\n    " stringByAppendingString:d] : @""];
}

+ (void)presentFrom:(UIViewController *)presenter {
    NSMutableArray *lines = [NSMutableArray new];

    // JIT
    BOOL jit = isJITEnabled(NO);
    NSString *jitDetail = jit ? @"" : @"Not enabled yet. It turns on when you launch a game (StikDebug or Built-in JIT).";
    [lines addObject:[self line:jit title:(jit ? @"JIT is active" : @"JIT is not active") detail:jitDetail]];

    if (getPrefBool(@"general.builtin_jit")) {
        NSString *why = CalciteBuiltInJIT.unavailableReason;
        BOOL ok = !why && CalciteBuiltInJIT.hasPairingFile;
        [lines addObject:[self line:ok title:@"Built-in JIT" detail:ok ? @"Ready (remember to connect LocalDevVPN)." :
            (why ?: @"No pairing file yet. Settings > General > Pair on this iPhone or Import pairing file.")]];
    }

    // Java for the selected profile
    NSString *versionId = PLProfiles.current.selectedProfile[@"lastVersionId"] ?: @"";
    NSString *java = getSelectedJavaHome(nil, 8);
    [lines addObject:[self line:java != nil title:@"Java runtime"
        detail:java ? [NSString stringWithFormat:@"%@ (profile: %@)", java.lastPathComponent, versionId] : @"No Java runtime found. Reinstall Calcite."]];

    // Memory
    float mb = getPrefFloat(@"java.allocated_memory");
    unsigned long long total = NSProcessInfo.processInfo.physicalMemory / 1048576;
    BOOL memOK = mb <= total * 0.6;
    [lines addObject:[self line:memOK title:[NSString stringWithFormat:@"Game memory: %.0f MB of %llu MB", mb, total]
        detail:memOK ? @"" : @"That's a lot. iOS may close the game. Try about a quarter of your RAM."]];

    // Storage
    NSDictionary *attrs = [NSFileManager.defaultManager attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
    double freeGB = [attrs[NSFileSystemFreeSize] doubleValue] / 1e9;
    [lines addObject:[self line:freeGB > 2 title:[NSString stringWithFormat:@"Free storage: %.1f GB", freeGB]
        detail:freeGB > 2 ? @"" : @"Low. Minecraft needs space for versions and worlds."]];

    // Account
    BaseAuthenticator *auth = BaseAuthenticator.current;
    NSString *user = auth.authData[@"username"];
    BOOL offline = [auth.authData[@"accessToken"] isEqualToString:@"offline"];
    [lines addObject:[self line:user != nil title:user ? [NSString stringWithFormat:@"Account: %@%@", user, offline ? @" (offline)" : @""] : @"No account selected"
        detail:user ? (offline ? @"Offline accounts can't join most servers." : @"") : @"Tap the account button to sign in."]];

    // Mods
    BOOL modded = [versionId.lowercaseString containsString:@"fabric"] || [versionId.lowercaseString containsString:@"forge"] ||
                  [versionId.lowercaseString containsString:@"quilt"];
    [lines addObject:[self line:YES title:modded ? @"Modded profile" : @"Vanilla profile"
        detail:modded ? @"Use Mod Browser to add mods and Performance Pack for speed." : @""]];

    showDialog(@"Health Check", [lines componentsJoinedByString:@"\n\n"]);
}

@end
