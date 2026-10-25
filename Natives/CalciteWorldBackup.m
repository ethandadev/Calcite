#import "CalciteWorldBackup.h"

static const NSInteger kKeepPerWorld = 3;

@implementation CalciteWorldBackup

+ (void)backupChangedWorldsInBackground {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @try { [self backupChangedWorlds]; }
        @catch (NSException *e) { NSLog(@"[Backup] failed: %@", e); }
    });
}

+ (NSArray<NSString *> *)subdirsOf:(NSString *)path {
    NSMutableArray *out = [NSMutableArray new];
    for (NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:path error:nil]) {
        BOOL isDir = NO;
        if ([NSFileManager.defaultManager fileExistsAtPath:[path stringByAppendingPathComponent:name] isDirectory:&isDir] && isDir) {
            [out addObject:name];
        }
    }
    return out;
}

+ (void)backupChangedWorlds {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *home = @(getenv("AME_HOME") ?: "");
    if (home.length == 0) return;
    NSString *instances = [home stringByAppendingPathComponent:@"instances"];
    NSString *backups = [home stringByAppendingPathComponent:@"backups"];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;

    NSDateFormatter *df = [NSDateFormatter new];
    df.dateFormat = @"yyyyMMdd-HHmmss";

    for (NSString *group in [self subdirsOf:instances]) {
        for (NSString *instance in [self subdirsOf:[instances stringByAppendingPathComponent:group]]) {
            NSString *saves = [[[instances stringByAppendingPathComponent:group] stringByAppendingPathComponent:instance] stringByAppendingPathComponent:@"saves"];
            for (NSString *world in [self subdirsOf:saves]) {
                NSString *worldPath = [saves stringByAppendingPathComponent:world];
                NSDictionary *attrs = [fm attributesOfItemAtPath:[worldPath stringByAppendingPathComponent:@"level.dat"] error:nil];
                NSDate *saved = attrs.fileModificationDate;
                if (!saved) continue; // not a world

                NSString *key = [NSString stringWithFormat:@"calcite.backup.%@/%@/%@", group, instance, world];
                if (saved.timeIntervalSince1970 <= [defaults doubleForKey:key]) continue;

                NSString *destDir = [[backups stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%@", group, instance]] stringByAppendingPathComponent:world];
                [fm createDirectoryAtPath:destDir withIntermediateDirectories:YES attributes:nil error:nil];
                NSString *dest = [destDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.zip", world, [df stringFromDate:NSDate.date]]];

                __block BOOL ok = NO;
                NSError *coordError = nil;
                // iOS zips a directory for us when it is read "for uploading"
                [[NSFileCoordinator new] coordinateReadingItemAtURL:[NSURL fileURLWithPath:worldPath]
                                                            options:NSFileCoordinatorReadingForUploading
                                                              error:&coordError
                                                         byAccessor:^(NSURL *zipURL) {
                    ok = [fm copyItemAtURL:zipURL toURL:[NSURL fileURLWithPath:dest] error:nil];
                }];
                if (!ok) { NSLog(@"[Backup] could not back up %@ (%@)", world, coordError); continue; }
                [defaults setDouble:saved.timeIntervalSince1970 forKey:key];
                NSLog(@"[Backup] saved %@", dest);

                // keep only the newest few
                NSArray *files = [[fm contentsOfDirectoryAtPath:destDir error:nil] sortedArrayUsingSelector:@selector(compare:)];
                for (NSInteger i = 0; i < (NSInteger)files.count - kKeepPerWorld; i++) {
                    [fm removeItemAtPath:[destDir stringByAppendingPathComponent:files[i]] error:nil];
                }
            }
        }
    }
}

@end
