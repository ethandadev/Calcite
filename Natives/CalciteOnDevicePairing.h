#import <UIKit/UIKit.h>

/// iOS 27+ on-device pairing: Calcite advertises itself as a pairable computer; the user picks it in
/// Settings > Privacy & Security > Developer Mode and types the code Calcite shows.
@interface CalciteOnDevicePairing : NSObject
+ (BOOL)isSupported;
+ (void)startFrom:(UIViewController *)presenter;
@end
