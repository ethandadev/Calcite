#import <UIKit/UIKit.h>

// App-wide motion: springy press feedback on buttons and table rows, staggered row reveal,
// and animated text changes. Install once at launch.
@interface CalciteMotion : NSObject
+ (void)install;
+ (void)crossfadeLabel:(UILabel *)label to:(NSString *)text;
+ (void)bounceSymbolIn:(UIView *)root;
@end
