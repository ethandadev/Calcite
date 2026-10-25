#import <Foundation/Foundation.h>

/// Automatic world backups. When the launcher opens, every world that was saved since its last
/// backup is zipped into backups/<instance>/<world>/ (newest 3 are kept per world).
@interface CalciteWorldBackup : NSObject
+ (void)backupChangedWorldsInBackground;
@end
