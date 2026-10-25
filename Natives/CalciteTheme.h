#import <UIKit/UIKit.h>

/// Calcite's look: a teal crystal accent, soft cards and rounded controls.
@interface CalciteTheme : NSObject
+ (UIColor *)accent;      // teal
+ (UIColor *)accentDeep;  // darker teal for gradients and pressed states
+ (UIColor *)cardBackground;
+ (void)applyToWindow:(UIWindow *)window;
+ (void)applyAppearance;
+ (UIColor *)background;
+ (UIColor *)surface;
+ (UIFont *)roundedFont:(CGFloat)size weight:(UIFontWeight)weight;
+ (void)styleSidebarCell:(UITableViewCell *)cell;
+ (void)styleCardCell:(UITableViewCell *)cell;
+ (void)revealCell:(UITableViewCell *)cell atRow:(NSInteger)row;
+ (void)riseIn:(NSArray<UIView *> *)views;
+ (void)animateHero:(UIView *)hero gradient:(CAGradientLayer *)grad play:(UIView *)play;
/// A tappable rounded card with a symbol, title and subtitle.
+ (UIControl *)actionCardWithSymbol:(NSString *)symbol title:(NSString *)title subtitle:(NSString *)subtitle;
@end
