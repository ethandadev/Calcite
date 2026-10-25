#import <objc/runtime.h>
#import "CalciteMotion.h"
#import "CalciteTheme.h"

static void swizzle(Class c, SEL orig, SEL repl) {
    Method a = class_getInstanceMethod(c, orig), b = class_getInstanceMethod(c, repl);
    if (class_addMethod(c, orig, method_getImplementation(b), method_getTypeEncoding(b))) {
        class_replaceMethod(c, repl, method_getImplementation(a), method_getTypeEncoding(a));
    } else {
        method_exchangeImplementations(a, b);
    }
}

static void springTo(UIView *v, CGFloat scale, CGFloat alpha, BOOL pressing) {
    [UIView animateWithDuration:pressing ? 0.22 : 0.5 delay:0
         usingSpringWithDamping:pressing ? 0.8 : 0.5 initialSpringVelocity:pressing ? 0 : 0.9
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{ v.transform = CGAffineTransformMakeScale(scale, scale); v.alpha = alpha; }
                     completion:nil];
}

@interface UIButton (CalciteMotion) @end
@implementation UIButton (CalciteMotion)
- (void)calcite_setHighlighted:(BOOL)highlighted {
    BOOL was = self.highlighted;
    [self calcite_setHighlighted:highlighted];
    // Leave UIKit's own bar-button / system buttons alone; scale everything the app draws itself.
    if (was == highlighted || UIAccessibilityIsReduceMotionEnabled()) return;
    if (self.bounds.size.width > 220 && self.bounds.size.height > 120) return; // huge tap areas feel odd scaled
    springTo(self, highlighted ? 0.95 : 1, highlighted ? 0.88 : 1, highlighted);
}
@end

@interface UITableViewCell (CalciteMotion) @end
@implementation UITableViewCell (CalciteMotion)
- (void)calcite_setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [self calcite_setHighlighted:highlighted animated:animated];
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    springTo(self.contentView, highlighted ? 0.975 : 1, 1, highlighted);
}
- (void)calcite_didMoveToWindow {
    [self calcite_didMoveToWindow];
    if (self.window) [CalciteTheme revealCell:self atRow:(NSInteger)(self.frame.origin.y / 56.0)];
}
@end

@implementation CalciteMotion

+ (void)install {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        swizzle(UIButton.class, @selector(setHighlighted:), @selector(calcite_setHighlighted:));
        swizzle(UITableViewCell.class, @selector(setHighlighted:animated:), @selector(calcite_setHighlighted:animated:));
        swizzle(UITableViewCell.class, @selector(didMoveToWindow), @selector(calcite_didMoveToWindow));
    });
}

+ (void)crossfadeLabel:(UILabel *)label to:(NSString *)text {
    if ([label.text isEqualToString:text]) return;
    [UIView transitionWithView:label duration:0.35 options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction
                    animations:^{ label.text = text; } completion:nil];
}

+ (void)bounceSymbolIn:(UIView *)root {
    if (@available(iOS 17.0, *)) {
        for (UIView *v in root.subviews) {
            if ([v isKindOfClass:UIImageView.class] && ((UIImageView *)v).image.isSymbolImage) {
                [(UIImageView *)v addSymbolEffect:[NSSymbolBounceEffect effect]];
            }
            [self bounceSymbolIn:v];
        }
    }
}

@end
