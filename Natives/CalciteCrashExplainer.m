#import "CalciteCrashExplainer.h"

static NSString *const kLastExplainedKey = @"calcite.crashexplainer.last_mtime";

@implementation CalciteCrashExplainer

+ (BOOL)log:(NSString *)log contains:(NSString *)needle {
    return [log rangeOfString:needle options:NSCaseInsensitiveSearch].location != NSNotFound;
}

+ (NSString *)explanationForLog:(NSString *)log {
    if (log.length == 0) return nil;

    // Wrong Java version: "class file version 69.0" -> Java 25
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"class file version (\\d+)\\.\\d+" options:0 error:nil];
    NSTextCheckingResult *m = [re firstMatchInString:log options:0 range:NSMakeRange(0, log.length)];
    if (m && [self log:log contains:@"UnsupportedClassVersionError"]) {
        int java = [[log substringWithRange:[m rangeAtIndex:1]] intValue] - 44;
        return [NSString stringWithFormat:@"This version of Minecraft (or a mod) needs Java %d, but an older Java was used.\n\nOpen Settings > Java and make sure Java %d is installed, or set the profile's Java version to %d.", java, java, java];
    }
    if ([self log:log contains:@"OutOfMemoryError"] || [self log:log contains:@"Java heap space"]) {
        return @"Minecraft ran out of memory.\n\nTry lowering Render Distance, turning off heavy mods or shaders, or raising the allocated RAM in Settings > Java.";
    }
    if ([self log:log contains:@"Mixin apply failed"] || [self log:log contains:@"MixinTransformerError"] || [self log:log contains:@"MixinApplyError"]) {
        return @"A mod doesn't fit this Minecraft version or clashes with another mod (Mixin error).\n\nRemove the most recently added mod, or check that every mod is built for your Minecraft version and loader.";
    }
    if ([self log:log contains:@"Incompatible mod set"] || [self log:log contains:@"Mod resolution failed"] || [self log:log contains:@"requires any version of"] || [self log:log contains:@"Missing or unsupported mandatory dependencies"]) {
        return @"A mod is missing a required library mod or is the wrong version.\n\nLook for the line that says which mod is required (often Fabric API) and install it.";
    }
    if ([self log:log contains:@"UnknownHostException"] || [self log:log contains:@"Failed to download"] || [self log:log contains:@"SSLHandshakeException"]) {
        return @"Minecraft couldn't reach the internet to download something.\n\nCheck your connection and try again.";
    }
    if ([self log:log contains:@"GLFW error"] || [self log:log contains:@"Failed to create window"] || [self log:log contains:@"Failed to initialize OpenGL"] || [self log:log contains:@"GLX"] || [self log:log contains:@"OpenGL ES"] ) {
        return @"The graphics renderer failed to start.\n\nTry a different renderer in the profile settings (for example MobileGlues or Zink), and turn off shaders and mods that change rendering.";
    }
    if ([self log:log contains:@"A fatal error has been detected by the Java Runtime Environment"] || [self log:log contains:@"SIGBUS"] || [self log:log contains:@"SIGILL"]) {
        return @"Java crashed hard. This most often means JIT wasn't enabled when the game started.\n\nEnable JIT (StikDebug) before pressing Play, then try again.";
    }
    if ([self log:log contains:@"UnsatisfiedLinkError"]) {
        return @"A native library failed to load. This usually comes from a mod that needs a desktop-only library.\n\nTry removing recently added mods.";
    }
    if ([self log:log contains:@"NoClassDefFoundError"] || [self log:log contains:@"ClassNotFoundException"]) {
        return @"Something is missing a piece it needs to run, usually a mod for the wrong Minecraft version, or a missing library mod.\n\nRemove recently added mods and try again.";
    }
    return nil;
}

+ (void)presentIfNeededFrom:(UIViewController *)viewController {
    NSString *home = @(getenv("AME_HOME") ?: "");
    NSString *path = [home stringByAppendingPathComponent:@"latestlog.old.txt"];
    NSDictionary *attrs = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    NSDate *mtime = attrs.fileModificationDate;
    if (!mtime) return;
    NSTimeInterval last = [NSUserDefaults.standardUserDefaults doubleForKey:kLastExplainedKey];
    if (mtime.timeIntervalSince1970 <= last) return;
    [NSUserDefaults.standardUserDefaults setDouble:mtime.timeIntervalSince1970 forKey:kLastExplainedKey];

    NSData *data = [NSData dataWithContentsOfFile:path];
    // Only the tail matters, and logs can be huge
    if (data.length > 600 * 1024) data = [data subdataWithRange:NSMakeRange(data.length - 600 * 1024, 600 * 1024)];
    NSString *log = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    NSString *text = [self explanationForLog:log];
    if (!text) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Calcite found a likely cause"
        message:text preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Share log" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        UIActivityViewController *vc = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
        vc.popoverPresentationController.sourceView = viewController.view;
        vc.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(viewController.view.bounds), CGRectGetMidY(viewController.view.bounds), 1, 1);
        [viewController presentViewController:vc animated:YES completion:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [viewController presentViewController:alert animated:YES completion:nil];
}

@end
