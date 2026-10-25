#import <objc/runtime.h>
#import "CalciteTheme.h"
#import "CalciteMotion.h"

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

+ (UIColor *)background {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0.035 green:0.075 blue:0.085 alpha:1]
            : [UIColor colorWithRed:0.93 green:0.97 blue:0.96 alpha:1];
    }];
}

+ (UIColor *)surface {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0.075 green:0.135 blue:0.150 alpha:1]
            : UIColor.whiteColor;
    }];
}

+ (UIFont *)roundedFont:(CGFloat)size weight:(UIFontWeight)weight {
    UIFont *base = [UIFont systemFontOfSize:size weight:weight];
    UIFontDescriptor *d = [base.fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignRounded];
    return d ? [UIFont fontWithDescriptor:d size:size] : base;
}

// Global look: rounded type, deep-teal canvas, raised surfaces, teal controls.
+ (void)applyAppearance {
    UIColor *accent = [self accent];

    UINavigationBarAppearance *nav = [UINavigationBarAppearance new];
    [nav configureWithTransparentBackground];
    nav.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
    nav.titleTextAttributes = @{NSFontAttributeName: [self roundedFont:18 weight:UIFontWeightBold]};
    nav.largeTitleTextAttributes = @{NSFontAttributeName: [self roundedFont:32 weight:UIFontWeightHeavy]};
    UINavigationBar *bar = [UINavigationBar appearance];
    bar.standardAppearance = nav;
    bar.scrollEdgeAppearance = nav;
    bar.compactAppearance = nav;
    bar.tintColor = accent;

    UIToolbarAppearance *tb = [UIToolbarAppearance new];
    [tb configureWithDefaultBackground];
    [UIToolbar appearance].standardAppearance = tb;
    [UIToolbar appearance].tintColor = accent;

    [UITableView appearance].backgroundColor = [self background];
    [UITableViewCell appearance].backgroundColor = [self surface];
    UILabel *cellLabel = (UILabel *)[UILabel appearanceWhenContainedInInstancesOfClasses:@[UITableViewCell.class]];
    cellLabel.font = [self roundedFont:16 weight:UIFontWeightMedium];

    [UISwitch appearance].onTintColor = accent;
    [UISlider appearance].minimumTrackTintColor = accent;
    [UIProgressView appearance].progressTintColor = accent;
    [UISegmentedControl appearance].selectedSegmentTintColor = accent;
    [UISegmentedControl appearance].tintColor = accent;
    [UISegmentedControl appearance]; 
    [[UISegmentedControl appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName: UIColor.whiteColor}
                                                   forState:UIControlStateSelected];
    [UIRefreshControl appearance].tintColor = accent;
    [UIActivityIndicatorView appearance].color = accent;
}

+ (void)applyToWindow:(UIWindow *)window {
    [self applyAppearance];
    [CalciteMotion install];
    window.tintColor = [self accent];
    window.backgroundColor = [self background];
}

// Sidebar rows become rounded teal "pills" when selected.
+ (void)styleSidebarCell:(UITableViewCell *)cell {
    cell.backgroundColor = UIColor.clearColor;
    cell.textLabel.font = [self roundedFont:17 weight:UIFontWeightSemibold];
    cell.imageView.tintColor = [self accent];
    UIView *pill = [UIView new];
    pill.backgroundColor = [[self accent] colorWithAlphaComponent:0.22];
    pill.layer.cornerRadius = 14;
    pill.layer.cornerCurve = kCACornerCurveContinuous;
    UIView *holder = [UIView new];
    [holder addSubview:pill];
    pill.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [pill.topAnchor constraintEqualToAnchor:holder.topAnchor constant:3],
        [pill.bottomAnchor constraintEqualToAnchor:holder.bottomAnchor constant:-3],
        [pill.leadingAnchor constraintEqualToAnchor:holder.leadingAnchor constant:8],
        [pill.trailingAnchor constraintEqualToAnchor:holder.trailingAnchor constant:-8],
    ]];
    cell.selectedBackgroundView = holder;
}

// Profile / instance rows: raised rounded surface with a hairline.
+ (void)styleCardCell:(UITableViewCell *)cell {
    cell.textLabel.font = [self roundedFont:17 weight:UIFontWeightSemibold];
    cell.detailTextLabel.font = [self roundedFont:13 weight:UIFontWeightRegular];
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.imageView.layer.cornerRadius = 10;
    cell.imageView.layer.cornerCurve = kCACornerCurveContinuous;
    cell.imageView.clipsToBounds = YES;
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
    // press feedback: springy squish + light haptic
    [card addAction:[UIAction actionWithHandler:^(UIAction *a) {
        [[UIImpactFeedbackGenerator.alloc initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
        [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{ card.transform = CGAffineTransformMakeScale(0.95, 0.95); card.alpha = 0.85; } completion:nil];
    }] forControlEvents:UIControlEventTouchDown];
    UIAction *restore = [UIAction actionWithHandler:^(UIAction *a) {
        [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:0.55 initialSpringVelocity:0.8
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{ card.transform = CGAffineTransformIdentity; card.alpha = 1; } completion:nil];
    }];
    [card addAction:restore forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
    return card;
}

// Rows slide and fade in the first time they appear, staggered by position.
+ (void)revealCell:(UITableViewCell *)cell atRow:(NSInteger)row {
    static const void *key = &key;
    if (objc_getAssociatedObject(cell, key)) return;
    objc_setAssociatedObject(cell, key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    cell.contentView.alpha = 0;
    cell.contentView.transform = CGAffineTransformMakeTranslation(-14, 0);
    [UIView animateWithDuration:0.55 delay:MIN(row, 12) * 0.04 usingSpringWithDamping:0.82 initialSpringVelocity:0.2
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{ cell.contentView.alpha = 1; cell.contentView.transform = CGAffineTransformIdentity; }
                     completion:nil];
}

// Staggered rise-in for a list of views (used by Home).
+ (void)riseIn:(NSArray<UIView *> *)views {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    [views enumerateObjectsUsingBlock:^(UIView *v, NSUInteger i, BOOL *stop) {
        v.alpha = 0;
        v.transform = CGAffineTransformMakeTranslation(0, 24);
        [UIView animateWithDuration:0.7 delay:0.06 * i usingSpringWithDamping:0.8 initialSpringVelocity:0.2
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{ v.alpha = 1; v.transform = CGAffineTransformIdentity; }
                         completion:nil];
    }];
}

// Slow living gradient + breathing glow for the hero card.
+ (void)animateHero:(UIView *)hero gradient:(CAGradientLayer *)grad play:(UIView *)play {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    CABasicAnimation *shift = [CABasicAnimation animationWithKeyPath:@"endPoint"];
    shift.fromValue = [NSValue valueWithCGPoint:CGPointMake(1, 1)];
    shift.toValue = [NSValue valueWithCGPoint:CGPointMake(0.6, 1.4)];
    shift.duration = 5; shift.autoreverses = YES; shift.repeatCount = HUGE_VALF;
    shift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [grad addAnimation:shift forKey:@"shift"];
    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulse.fromValue = @1.0; pulse.toValue = @1.045;
    pulse.duration = 1.4; pulse.autoreverses = YES; pulse.repeatCount = HUGE_VALF;
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [play.layer addAnimation:pulse forKey:@"pulse"];
}

// iOS-Settings style icon: white symbol on a coloured rounded square.
+ (UIImage *)settingsTile:(NSString *)symbol destructive:(BOOL)destructive {
    UIImage *glyph = [UIImage systemImageNamed:symbol];
    if (!glyph) return nil;
    NSArray<UIColor *> *palette = @[
        [UIColor colorWithRed:0.17 green:0.70 blue:0.64 alpha:1], [UIColor colorWithRed:0.20 green:0.50 blue:0.95 alpha:1],
        [UIColor colorWithRed:0.95 green:0.55 blue:0.15 alpha:1], [UIColor colorWithRed:0.60 green:0.38 blue:0.90 alpha:1],
        [UIColor colorWithRed:0.90 green:0.30 blue:0.45 alpha:1], [UIColor colorWithRed:0.25 green:0.75 blue:0.40 alpha:1],
        [UIColor colorWithRed:0.45 green:0.50 blue:0.58 alpha:1],
    ];
    UIColor *bg = destructive ? [UIColor colorWithRed:0.92 green:0.28 blue:0.27 alpha:1] : palette[symbol.hash % palette.count];
    CGSize size = CGSizeMake(30, 30);
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    UIImage *img = [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [bg setFill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 30, 30) cornerRadius:7] fill];
        UIImage *white = [[glyph imageWithConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold]]
                          imageWithTintColor:UIColor.whiteColor renderingMode:UIImageRenderingModeAlwaysOriginal];
        CGSize g = white.size;
        CGFloat k = MIN(1, 18 / MAX(g.width, g.height));
        [white drawInRect:CGRectMake((30 - g.width * k) / 2, (30 - g.height * k) / 2, g.width * k, g.height * k)];
    }];
    return [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

@end
