#import <UIKit/UIKit.h>

/// One-tap performance mods (Sodium, Lithium, FerriteCore, ImmediatelyFast, Entity Culling,
/// Dynamic FPS) downloaded from Modrinth for the selected Fabric profile.
@interface CalcitePerformancePack : NSObject
+ (void)installForSelectedProfileFrom:(UIViewController *)presenter;
@end
