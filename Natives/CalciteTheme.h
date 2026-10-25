#import <UIKit/UIKit.h>

/// Calcite's look: a teal crystal accent, soft cards and rounded controls.
@interface CalciteTheme : NSObject
+ (UIColor *)accent;      // teal
+ (UIColor *)accentDeep;  // darker teal for gradients and pressed states
+ (UIColor *)cardBackground;
+ (void)applyToWindow:(UIWindow *)window;
/// A tappable rounded card with a symbol, title and subtitle.
+ (UIControl *)actionCardWithSymbol:(NSString *)symbol title:(NSString *)title subtitle:(NSString *)subtitle;
@end
