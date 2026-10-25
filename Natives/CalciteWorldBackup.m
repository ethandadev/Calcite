#import "CalciteWorldBackup.h"
#import "UnzipKit.h"
#import "ios_uikit_bridge.h"

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


#pragma mark Restore

+ (void)presentRestoreFrom:(UIViewController *)presenter {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *backups = [@(getenv("AME_HOME") ?: "") stringByAppendingPathComponent:@"backups"];
    NSMutableArray<NSDictionary *> *worlds = [NSMutableArray new]; // {title, instanceDir, world, dir}
    for (NSString *inst in [fm contentsOfDirectoryAtPath:backups error:nil]) {
        NSString *instDir = [backups stringByAppendingPathComponent:inst];
        for (NSString *world in [fm contentsOfDirectoryAtPath:instDir error:nil]) {
            NSString *dir = [instDir stringByAppendingPathComponent:world];
            NSArray *zips = [[fm contentsOfDirectoryAtPath:dir error:nil] filteredArrayUsingPredicate:
                [NSPredicate predicateWithFormat:@"self ENDSWITH '.zip'"]];
            if (zips.count) [worlds addObject:@{@"title": [NSString stringWithFormat:@"%@ · %@", world, inst], @"inst": inst, @"world": world, @"dir": dir}];
        }
    }
    if (!worlds.count) {
        showDialog(@"No backups yet", @"Calcite backs up your worlds automatically when you open the launcher after playing.");
        return;
    }
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Restore a world" message:@"Pick a world" preferredStyle:UIAlertControllerStyleActionSheet];
    a.popoverPresentationController.sourceView = presenter.view;
    a.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds), CGRectGetMidY(presenter.view.bounds), 1, 1);
    for (NSDictionary *w in worlds) {
        [a addAction:[UIAlertAction actionWithTitle:w[@"title"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
            [self pickBackupOf:w from:presenter];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [presenter presentViewController:a animated:YES completion:nil];
}

+ (void)pickBackupOf:(NSDictionary *)w from:(UIViewController *)presenter {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray *zips = [[[fm contentsOfDirectoryAtPath:w[@"dir"] error:nil] filteredArrayUsingPredicate:
        [NSPredicate predicateWithFormat:@"self ENDSWITH '.zip'"]] sortedArrayUsingSelector:@selector(compare:)].reverseObjectEnumerator.allObjects;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:w[@"world"] message:@"Pick a backup (newest first)" preferredStyle:UIAlertControllerStyleActionSheet];
    a.popoverPresentationController.sourceView = presenter.view;
    a.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds), CGRectGetMidY(presenter.view.bounds), 1, 1);
    for (NSString *zip in zips) {
        [a addAction:[UIAlertAction actionWithTitle:[zip stringByDeletingPathExtension] style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
            [self restoreZip:[w[@"dir"] stringByAppendingPathComponent:zip] instance:w[@"inst"] world:w[@"world"]];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [presenter presentViewController:a animated:YES completion:nil];
}

+ (void)restoreZip:(NSString *)zip instance:(NSString *)inst world:(NSString *)world {
    // inst is "<group>_<instance>"; the group name itself can contain underscores, so try each split.
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *root = [@(getenv("AME_HOME") ?: "") stringByAppendingPathComponent:@"instances"];
    NSString *saves = nil;
    for (NSUInteger i = 0; i < inst.length && !saves; i++) {
        if ([inst characterAtIndex:i] != '_') continue;
        NSString *cand = [NSString stringWithFormat:@"%@/%@/%@/saves", root, [inst substringToIndex:i], [inst substringFromIndex:i + 1]];
        if ([fm fileExistsAtPath:cand]) saves = cand;
    }
    if (!saves) { showDialog(@"Can't restore", @"The instance this backup belongs to no longer exists."); return; }

    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    NSError *err = nil;
    UZKArchive *archive = [[UZKArchive alloc] initWithPath:zip error:&err];
    if (!err) [archive extractFilesTo:tmp overWrite:YES error:&err];
    NSString *extracted = [[fm contentsOfDirectoryAtPath:tmp error:nil] firstObject];
    if (err || !extracted) {
        showDialog(@"Restore failed", err.localizedDescription ?: @"The backup is empty or damaged.");
        return;
    }
    NSString *name = [NSString stringWithFormat:@"%@ (restored)", world];
    for (int n = 2; [fm fileExistsAtPath:[saves stringByAppendingPathComponent:name]]; n++) name = [NSString stringWithFormat:@"%@ (restored %d)", world, n];
    if ([fm moveItemAtPath:[tmp stringByAppendingPathComponent:extracted] toPath:[saves stringByAppendingPathComponent:name] error:&err]) {
        showDialog(@"World restored", [NSString stringWithFormat:@"Restored as \"%@\". Open Minecraft's world list to play it. Your original world was not touched.", name]);
    } else {
        showDialog(@"Restore failed", err.localizedDescription);
    }
    [fm removeItemAtPath:tmp error:nil];
}

@end
