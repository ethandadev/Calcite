#import "CalciteOnboardingViewController.h"
#import "CalciteOnDevicePairing.h"
#import "CalciteTheme.h"

static NSString *const kOnboarded = @"calcite.onboarded.v1";

@interface CalciteOnboardingViewController () <UIScrollViewDelegate>
@property(nonatomic) UIScrollView *pager;
@property(nonatomic) NSArray<UIView *> *pages;
@property(nonatomic) NSArray<NSArray<UIView *> *> *pageItems;
@property(nonatomic) NSArray<UIView *> *blobs;
@property(nonatomic) UIButton *nextButton;
@property(nonatomic) UIButton *skipButton;
@property(nonatomic) NSArray<UIView *> *dots;
@property(nonatomic) NSInteger current;
@property(nonatomic) NSMutableSet<NSNumber *> *revealed;
@property(nonatomic) BOOL laidOut;
@end

@implementation CalciteOnboardingViewController

+ (BOOL)shouldPresent {
    return ![NSUserDefaults.standardUserDefaults boolForKey:kOnboarded];
}

+ (void)presentFrom:(UIViewController *)presenter force:(BOOL)force {
    if (!force && ![self shouldPresent]) return;
    CalciteOnboardingViewController *vc = [CalciteOnboardingViewController new];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    vc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [presenter presentViewController:vc animated:YES completion:nil];
}

- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleLightContent; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskLandscape; }

#pragma mark - Building

- (UILabel *)labelWithText:(NSString *)t size:(CGFloat)size weight:(UIFontWeight)w alpha:(CGFloat)a {
    UILabel *l = [UILabel new];
    l.text = t;
    l.font = [CalciteTheme roundedFont:size weight:w];
    l.textColor = [UIColor colorWithWhite:1 alpha:a];
    l.numberOfLines = 0;
    l.textAlignment = NSTextAlignmentCenter;
    return l;
}

- (UIView *)glassSymbol:(NSString *)name size:(CGFloat)diameter {
    UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    glass.frame = CGRectMake(0, 0, diameter, diameter);
    glass.layer.cornerRadius = diameter * 0.28;
    glass.layer.cornerCurve = kCACornerCurveContinuous;
    glass.clipsToBounds = YES;
    glass.layer.borderWidth = 1;
    glass.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.22].CGColor;
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:diameter * 0.42 weight:UIImageSymbolWeightMedium];
    UIImageView *iv = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:name withConfiguration:cfg]];
    iv.tintColor = UIColor.whiteColor;
    iv.contentMode = UIViewContentModeCenter;
    iv.frame = glass.bounds;
    iv.tag = 99;
    [glass.contentView addSubview:iv];
    return glass;
}

- (UIView *)featureRow:(NSString *)symbol title:(NSString *)title detail:(NSString *)detail {
    UIView *row = [UIView new];
    UIView *chip = [self glassSymbol:symbol size:48];
    chip.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *t = [self labelWithText:title size:17 weight:UIFontWeightSemibold alpha:1];
    UILabel *d = [self labelWithText:detail size:14 weight:UIFontWeightRegular alpha:0.7];
    t.textAlignment = d.textAlignment = NSTextAlignmentNatural;
    UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[t, d]];
    text.axis = UILayoutConstraintAxisVertical;
    text.spacing = 2;
    text.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:chip]; [row addSubview:text];
    [NSLayoutConstraint activateConstraints:@[
        [chip.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [chip.topAnchor constraintEqualToAnchor:row.topAnchor],
        [chip.bottomAnchor constraintLessThanOrEqualToAnchor:row.bottomAnchor],
        [chip.widthAnchor constraintEqualToConstant:48], [chip.heightAnchor constraintEqualToConstant:48],
        [text.leadingAnchor constraintEqualToAnchor:chip.trailingAnchor constant:16],
        [text.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [text.topAnchor constraintEqualToAnchor:row.topAnchor],
        [text.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
    ]];
    return row;
}

- (UIButton *)pillButton:(NSString *)title filled:(BOOL)filled {
    UIButtonConfiguration *cfg = filled ? [UIButtonConfiguration filledButtonConfiguration] : [UIButtonConfiguration plainButtonConfiguration];
    cfg.title = title;
    cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    cfg.contentInsets = NSDirectionalEdgeInsetsMake(15, 36, 15, 36);
    cfg.baseBackgroundColor = filled ? UIColor.whiteColor : nil;
    cfg.baseForegroundColor = filled ? [CalciteTheme accentDeep] : [UIColor colorWithWhite:1 alpha:0.75];
    cfg.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *attrs) {
        NSMutableDictionary *m = [attrs mutableCopy];
        m[NSFontAttributeName] = [CalciteTheme roundedFont:17 weight:UIFontWeightSemibold];
        return m;
    };
    return [UIButton buttonWithConfiguration:cfg primaryAction:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.revealed = [NSMutableSet set];
    self.view.backgroundColor = [UIColor colorWithRed:0.02 green:0.06 blue:0.07 alpha:1];

    // Aurora: three big soft blobs drifting forever under a heavy blur.
    NSArray *colors = @[[UIColor colorWithRed:0.17 green:0.80 blue:0.70 alpha:1],
                        [UIColor colorWithRed:0.10 green:0.45 blue:0.85 alpha:1],
                        [UIColor colorWithRed:0.45 green:0.30 blue:0.85 alpha:1]];
    NSMutableArray *blobs = [NSMutableArray array];
    for (UIColor *c in colors) {
        UIView *b = [UIView new];
        b.backgroundColor = [c colorWithAlphaComponent:0.85];
        [self.view addSubview:b];
        [blobs addObject:b];
    }
    self.blobs = blobs;
    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark]];
    blur.frame = self.view.bounds;
    blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:blur];

    self.pager = [UIScrollView new];
    self.pager.pagingEnabled = YES;
    self.pager.showsHorizontalScrollIndicator = NO;
    self.pager.delegate = self;
    self.pager.bounces = YES;
    [self.view addSubview:self.pager];

    // Pages
    UIView *p1 = [UIView new], *p2 = [UIView new], *p3 = [UIView new], *p4 = [UIView new];

    UIView *logo = [self glassSymbol:@"cube.fill" size:128];
    UILabel *t1 = [self labelWithText:@"Welcome to Calcite" size:36 weight:UIFontWeightHeavy alpha:1];
    UILabel *s1 = [self labelWithText:@"Minecraft: Java Edition, running natively on your iPhone." size:18 weight:UIFontWeightRegular alpha:0.75];
    UILabel *s1b = [self labelWithText:@"Swipe to take a quick look around" size:14 weight:UIFontWeightMedium alpha:0.45];

    UILabel *t2 = [self labelWithText:@"Everything built in" size:32 weight:UIFontWeightHeavy alpha:1];
    UIView *f1 = [self featureRow:@"puzzlepiece.extension.fill" title:@"Mods in two taps" detail:@"Browse Modrinth and install with dependencies."];
    UIView *f2 = [self featureRow:@"bolt.fill" title:@"Performance Pack" detail:@"Sodium and friends, one tap per profile."];
    UIView *f3 = [self featureRow:@"clock.arrow.circlepath" title:@"World backups" detail:@"Automatic copies, restore any time."];
    UIView *f4 = [self featureRow:@"gamecontroller.fill" title:@"Controls your way" detail:@"Nine layouts, including left-handed."];

    UIView *jit = [self glassSymbol:@"bolt.horizontal.fill" size:112];
    UILabel *t3 = [self labelWithText:@"JIT, without a computer" size:32 weight:UIFontWeightHeavy alpha:1];
    UILabel *s3 = [self labelWithText:@"Calcite can turn on JIT by itself. Pair once on this device and games start fast every time." size:17 weight:UIFontWeightRegular alpha:0.75];
    UIButton *pair = [self pillButton:@"Pair this device" filled:NO];
    [pair addTarget:self action:@selector(pairTapped) forControlEvents:UIControlEventTouchUpInside];

    UIView *ready = [self glassSymbol:@"checkmark.seal.fill" size:112];
    UILabel *t4 = [self labelWithText:@"You're all set" size:34 weight:UIFontWeightHeavy alpha:1];
    UILabel *s4 = [self labelWithText:@"Pick a version, press Play, and build something." size:18 weight:UIFontWeightRegular alpha:0.75];

    self.pages = @[p1, p2, p3, p4];
    self.pageItems = @[@[logo, t1, s1, s1b], @[t2, f1, f2, f3, f4], @[jit, t3, s3, pair], @[ready, t4, s4]];
    for (NSUInteger i = 0; i < self.pages.count; i++) {
        [self.pager addSubview:self.pages[i]];
        for (UIView *v in self.pageItems[i]) { [self.pages[i] addSubview:v]; v.alpha = 0; }
    }

    // Bottom controls
    self.nextButton = [self pillButton:@"Continue" filled:YES];
    [self.nextButton addTarget:self action:@selector(nextTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.nextButton];
    self.skipButton = [self pillButton:@"Skip" filled:NO];
    [self.skipButton addTarget:self action:@selector(finish) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.skipButton];

    NSMutableArray *dots = [NSMutableArray array];
    for (NSUInteger i = 0; i < self.pages.count; i++) {
        UIView *d = [UIView new];
        d.backgroundColor = [UIColor colorWithWhite:1 alpha:0.3];
        d.layer.cornerRadius = 4;
        [self.view addSubview:d];
        [dots addObject:d];
    }
    self.dots = dots;
}

#pragma mark - Layout

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect b = self.view.bounds;
    UIEdgeInsets safe = self.view.safeAreaInsets;
    self.pager.frame = b;
    self.pager.contentSize = CGSizeMake(b.size.width * self.pages.count, b.size.height);
    if (!self.pager.isDragging && !self.pager.isDecelerating) {
        self.pager.contentOffset = CGPointMake(b.size.width * self.current, 0);
    }

    CGFloat contentW = MIN(b.size.width - 56, 460);
    CGFloat bottomArea = safe.bottom + 150;
    CGFloat midY = (b.size.height - bottomArea) / 2 + safe.top / 2;

    for (NSUInteger i = 0; i < self.pages.count; i++) {
        UIView *page = self.pages[i];
        page.frame = CGRectMake(b.size.width * i, 0, b.size.width, b.size.height);
        NSArray<UIView *> *items = self.pageItems[i];
        // Simple vertical flow, centred as a block.
        CGFloat gap = (i == 1) ? 18 : 18;
        CGFloat total = 0;
        NSMutableArray *sizes = [NSMutableArray array];
        for (UIView *v in items) {
            CGSize s;
            if ([v isKindOfClass:UIVisualEffectView.class]) s = v.bounds.size;
            else if ([v isKindOfClass:UIButton.class]) s = [v sizeThatFits:CGSizeMake(contentW, CGFLOAT_MAX)];
            else s = [v sizeThatFits:CGSizeMake(contentW, CGFLOAT_MAX)];
            if ([v isKindOfClass:UILabel.class]) s.width = contentW;
            if (v.tag == 0 && ![v isKindOfClass:UILabel.class] && ![v isKindOfClass:UIButton.class] && ![v isKindOfClass:UIVisualEffectView.class]) s = CGSizeMake(contentW, 52); // feature rows
            [sizes addObject:[NSValue valueWithCGSize:s]];
            total += s.height + gap;
        }
        total -= gap;
        CGFloat y = MAX(safe.top + 24, midY - total / 2);
        for (NSUInteger k = 0; k < items.count; k++) {
            CGSize s = [sizes[k] CGSizeValue];
            UIView *v = items[k];
            CGAffineTransform saved = v.transform;
            v.transform = CGAffineTransformIdentity;
            v.bounds = CGRectMake(0, 0, s.width, s.height);
            v.center = CGPointMake(b.size.width / 2, y + s.height / 2);
            v.transform = saved;
            y += s.height + gap + ([v isKindOfClass:UIVisualEffectView.class] ? 14 : 0);
        }
    }

    CGFloat btnW = MIN(b.size.width - 56, 340);
    CGSize bs = [self.nextButton sizeThatFits:CGSizeMake(btnW, 60)];
    self.nextButton.frame = CGRectMake((b.size.width - btnW) / 2, b.size.height - safe.bottom - 100, btnW, MAX(bs.height, 54));
    self.skipButton.frame = CGRectMake((b.size.width - 120) / 2, CGRectGetMaxY(self.nextButton.frame) + 2, 120, 40);
    [self layoutDots];

    // Blobs
    CGFloat d = MAX(b.size.width, b.size.height) * 0.9;
    for (NSUInteger i = 0; i < self.blobs.count; i++) {
        UIView *blob = self.blobs[i];
        if (!self.laidOut) {
            blob.bounds = CGRectMake(0, 0, d, d);
            blob.layer.cornerRadius = d / 2;
            blob.center = CGPointMake(b.size.width * (0.2 + 0.3 * i), b.size.height * (0.25 + 0.25 * i));
            [self driftBlob:blob index:i];
        }
    }
    if (!self.laidOut) {
        self.laidOut = YES;
        dispatch_async(dispatch_get_main_queue(), ^{ [self revealPage:0]; });
    }
}

- (void)driftBlob:(UIView *)blob index:(NSUInteger)i {
    CGRect b = self.view.bounds;
    CAKeyframeAnimation *a = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    CGPoint c = blob.center;
    CGFloat r = 90 + 40 * i;
    a.values = @[[NSValue valueWithCGPoint:c],
                 [NSValue valueWithCGPoint:CGPointMake(c.x + r, c.y - r * 0.6)],
                 [NSValue valueWithCGPoint:CGPointMake(c.x - r * 0.5, c.y + r)],
                 [NSValue valueWithCGPoint:c]];
    a.duration = 16 + 5 * i;
    a.repeatCount = HUGE_VALF;
    a.calculationMode = kCAAnimationCubic;
    [blob.layer addAnimation:a forKey:@"drift"];
    CABasicAnimation *s = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    s.fromValue = @0.9; s.toValue = @1.15; s.duration = 7 + 2 * i; s.autoreverses = YES; s.repeatCount = HUGE_VALF;
    s.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [blob.layer addAnimation:s forKey:@"breathe"];
    (void)b;
}

- (void)layoutDots {
    CGRect b = self.view.bounds;
    CGFloat x = 0, total = 0;
    NSMutableArray<NSNumber *> *w = [NSMutableArray array];
    for (NSUInteger i = 0; i < self.dots.count; i++) {
        CGFloat dw = (NSInteger)i == self.current ? 24 : 8;
        [w addObject:@(dw)]; total += dw + (i ? 8 : 0);
    }
    x = (b.size.width - total) / 2;
    CGFloat y = CGRectGetMinY(self.nextButton.frame) - 28;
    for (NSUInteger i = 0; i < self.dots.count; i++) {
        self.dots[i].frame = CGRectMake(x, y, w[i].doubleValue, 8);
        self.dots[i].backgroundColor = [UIColor colorWithWhite:1 alpha:(NSInteger)i == self.current ? 0.95 : 0.3];
        x += w[i].doubleValue + 8;
    }
}

#pragma mark - Motion

- (void)revealPage:(NSInteger)idx {
    if (idx < 0 || idx >= (NSInteger)self.pages.count) return;
    if ([self.revealed containsObject:@(idx)]) return;
    [self.revealed addObject:@(idx)];
    NSArray<UIView *> *items = self.pageItems[idx];
    [items enumerateObjectsUsingBlock:^(UIView *v, NSUInteger i, BOOL *stop) {
        v.transform = CGAffineTransformConcat(CGAffineTransformMakeScale(0.94, 0.94), CGAffineTransformMakeTranslation(0, 34));
        [UIView animateWithDuration:0.9 delay:0.09 * i usingSpringWithDamping:0.78 initialSpringVelocity:0.3
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{ v.alpha = 1; v.transform = CGAffineTransformIdentity; } completion:nil];
        // Animate the symbol inside glass tiles.
        UIView *sym = [v viewWithTag:99];
        if (!sym && [v isKindOfClass:UIVisualEffectView.class]) sym = [((UIVisualEffectView *)v).contentView viewWithTag:99];
        if ([sym isKindOfClass:UIImageView.class]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((0.35 + 0.09 * i) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (@available(iOS 17.0, *)) {
                    [(UIImageView *)sym addSymbolEffect:[NSSymbolBounceEffect effect]];
                }
            });
        }
        // feature rows: bounce their glass tile too
        for (UIView *sub in v.subviews) {
            if ([sub isKindOfClass:UIVisualEffectView.class]) {
                UIView *s2 = [((UIVisualEffectView *)sub).contentView viewWithTag:99];
                if ([s2 isKindOfClass:UIImageView.class]) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((0.5 + 0.09 * i) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        if (@available(iOS 17.0, *)) { [(UIImageView *)s2 addSymbolEffect:[NSSymbolBounceEffect effect]]; }
                    });
                }
            }
        }
    }];
    // Idle breathing on hero tiles
    UIView *hero = items.firstObject;
    if ([hero isKindOfClass:UIVisualEffectView.class]) {
        CABasicAnimation *f = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
        f.fromValue = @(-6); f.toValue = @6; f.duration = 2.6; f.autoreverses = YES; f.repeatCount = HUGE_VALF;
        f.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [hero.layer addAnimation:f forKey:@"float"];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)sv {
    CGFloat w = self.view.bounds.size.width;
    if (w <= 0) return;
    CGFloat progress = sv.contentOffset.x / w;
    // Parallax: content drifts slower than the page; blobs drift slower still.
    for (NSUInteger i = 0; i < self.pages.count; i++) {
        CGFloat rel = progress - (CGFloat)i;           // -1..1 around the page
        CGFloat fade = 1 - MIN(1, fabs(rel) * 1.3);
        NSArray<UIView *> *items = self.pageItems[i];
        [items enumerateObjectsUsingBlock:^(UIView *v, NSUInteger k, BOOL *stop) {
            if (![self.revealed containsObject:@(i)]) return;
            CGFloat depth = 40 + 18 * k;
            v.layer.transform = CATransform3DMakeTranslation(rel * depth, 0, 0);
            v.alpha = MAX(0, fade);
        }];
    }
    for (NSUInteger i = 0; i < self.blobs.count; i++) {
        self.blobs[i].layer.transform = CATransform3DMakeTranslation(-progress * w * (0.10 + 0.07 * i), 0, 0);
    }
    NSInteger page = (NSInteger)llround(progress);
    page = MAX(0, MIN(page, (NSInteger)self.pages.count - 1));
    if (page != self.current) {
        self.current = page;
        [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.2 options:0 animations:^{ [self layoutDots]; } completion:nil];
        [[UISelectionFeedbackGenerator new] selectionChanged];
        [self updateButtonForPage:YES];
    }
    NSInteger nearest = (NSInteger)llround(progress);
    [self revealPage:nearest];
}

- (void)updateButtonForPage:(BOOL)animated {
    BOOL last = self.current == (NSInteger)self.pages.count - 1;
    UIButtonConfiguration *cfg = self.nextButton.configuration;
    cfg.title = last ? @"Get Started" : @"Continue";
    void (^apply)(void) = ^{
        self.nextButton.configuration = cfg;
        self.skipButton.alpha = last ? 0 : 1;
    };
    if (animated) [UIView transitionWithView:self.nextButton duration:0.35 options:UIViewAnimationOptionTransitionCrossDissolve animations:apply completion:nil];
    else apply();
}

#pragma mark - Actions

- (void)nextTapped {
    [[UIImpactFeedbackGenerator.alloc initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
    if (self.current >= (NSInteger)self.pages.count - 1) { [self finish]; return; }
    CGFloat w = self.view.bounds.size.width;
    [UIView animateWithDuration:0.65 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:0 options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{ self.pager.contentOffset = CGPointMake(w * (self.current + 1), 0); } completion:nil];
}

- (void)pairTapped {
    [[UIImpactFeedbackGenerator.alloc initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];
    [CalciteOnDevicePairing startFrom:self];
}

- (void)finish {
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:kOnboarded];
    [[UINotificationFeedbackGenerator new] notificationOccurred:UINotificationFeedbackTypeSuccess];
    [UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.view.transform = CGAffineTransformMakeScale(1.08, 1.08);
        self.view.alpha = 0;
    } completion:^(BOOL f) {
        self.view.transform = CGAffineTransformIdentity;
        [self dismissViewControllerAnimated:NO completion:nil];
    }];
}

@end
