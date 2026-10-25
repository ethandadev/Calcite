#import "CalciteTheme.h"

@implementation CalciteTheme

+ (UIColor *)accent { return [UIColor colorWithRed:0.17 green:0.70 blue:0.64 alpha:1]; }
+ (UIColor *)accentDeep { return [UIColor colorWithRed:0.07 green:0.45 blue:0.50 alpha:1]; }

+ (UIColor *)cardBackground {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1 alpha:0.07]
            : [UIColor colorWithRed:0.17 green:0.70 blue:0.64 alpha:0.10];
    }];
}

+ (void)applyToWindow:(UIWindow *)window {
    window.tintColor = [self accent];
}

+ (UIControl *)actionCardWithSymbol:(NSString *)symbol title:(NSString *)title subtitle:(NSString *)subtitle {
    UIControl *card = [UIControl new];
    card.backgroundColor = [self cardBackground];
    card.layer.cornerRadius = 18;
    card.layer.cornerCurve = kCACornerCurveContinuous;

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightSemibold];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol withConfiguration:cfg]];
    icon.tintColor = [self accent];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [icon setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    UILabel *t = [UILabel new];
    t.text = title;
    t.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    t.numberOfLines = 1;
    UILabel *s = [UILabel new];
    s.text = subtitle;
    s.font = [UIFont systemFontOfSize:12];
    s.textColor = UIColor.secondaryLabelColor;
    s.numberOfLines = 2;

    UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[t, s]];
    text.axis = UILayoutConstraintAxisVertical;
    text.spacing = 2;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[icon, text]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentLeading;
    stack.spacing = 10;
    stack.userInteractionEnabled = NO;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14],
    ]];
    // press feedback
    [card addAction:[UIAction actionWithHandler:^(UIAction *a) { card.alpha = 0.6; }] forControlEvents:UIControlEventTouchDown];
    UIAction *restore = [UIAction actionWithHandler:^(UIAction *a) {
        [UIView animateWithDuration:0.2 animations:^{ card.alpha = 1; }];
    }];
    [card addAction:restore forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    return card;
}

@end
