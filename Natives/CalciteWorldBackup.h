#import <UIKit/UIKit.h>

/// Automatic world backups. When the launcher opens, every world that was saved since its last
/// backup is zipped into backups/<instance>/<world>/ (newest 3 are kept per world).
@interface CalciteWorldBackup : NSObject
+ (void)backupChangedWorldsInBackground;
/// Lets the user pick a world and one of its backups; restores it next to the original as "<world> (restored)".
+ (void)presentRestoreFrom:(UIViewController *)presenter;
@end
