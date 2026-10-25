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
    // press feedback
    [card addAction:[UIAction actionWithHandler:^(UIAction *a) { card.alpha = 0.6; }] forControlEvents:UIControlEventTouchDown];
    UIAction *restore = [UIAction actionWithHandler:^(UIAction *a) {
        [UIView animateWithDuration:0.2 animations:^{ card.alpha = 1; }];
    }];
    [card addAction:restore forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    return card;
}

@end
