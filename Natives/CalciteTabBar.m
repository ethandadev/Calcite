#import "CalciteTabBar.h"
#import "CalciteTheme.h"
#import "CalciteMotion.h"

@interface CalciteTabBar ()
@property(nonatomic) NSArray<NSDictionary *> *items;
@property(nonatomic) NSMutableArray<UIControl *> *buttons;
@property(nonatomic) UIView *highlight;
@property(nonatomic) UIVisualEffectView *blur;
@property(nonatomic) NSInteger selectedIndex;
@end

@implementation CalciteTabBar

- (instancetype)initWithItems:(NSArray<NSDictionary *> *)items {
    if (!(self = [super initWithFrame:CGRectZero])) return nil;
    self.items = items;
    self.buttons = [NSMutableArray array];
    self.selectedIndex = 0;

    self.blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]];
    self.blur.clipsToBounds = YES;
    self.blur.layer.cornerCurve = kCACornerCurveContinuous;
    [self addSubview:self.blur];
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = 0.22;
    self.layer.shadowRadius = 18;
    self.layer.shadowOffset = CGSizeMake(0, 8);

    self.highlight = [UIView new];
    self.highlight.backgroundColor = [[CalciteTheme accent] colorWithAlphaComponent:0.22];
    self.highlight.layer.cornerCurve = kCACornerCurveContinuous;
    [self.blur.contentView addSubview:self.highlight];

    for (NSUInteger i = 0; i < items.count; i++) {
        UIControl *c = [UIControl new];
        c.tag = i;
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightSemibold];
        UIImageView *iv = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:items[i][@"symbol"] withConfiguration:cfg]];
        iv.contentMode = UIViewContentModeCenter;
        iv.tag = 1;
        UILabel *l = [UILabel new];
        l.text = items[i][@"title"];
        l.font = [CalciteTheme roundedFont:10.5 weight:UIFontWeightSemibold];
        l.textAlignment = NSTextAlignmentCenter;
        l.tag = 2;
        [c addSubview:iv]; [c addSubview:l];
        [c addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.blur.contentView addSubview:c];
        [self.buttons addObject:c];
    }
    [self applySelectionColors];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.blur.frame = self.bounds;
    self.blur.layer.cornerRadius = self.bounds.size.height / 2;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:self.bounds.size.height / 2].CGPath;
    CGFloat inset = 6, w = (self.bounds.size.width - inset * 2) / self.buttons.count, h = self.bounds.size.height - inset * 2;
    for (UIControl *c in self.buttons) {
        c.frame = CGRectMake(inset + w * c.tag, inset, w, h);
        UIView *iv = [c viewWithTag:1], *l = [c viewWithTag:2];
        iv.frame = CGRectMake(0, 6, w, 24);
        l.frame = CGRectMake(0, 31, w, 14);
    }
    self.highlight.frame = CGRectMake(inset + w * self.selectedIndex + 2, inset, w - 4, h);
    self.highlight.layer.cornerRadius = h / 2;
}

- (void)applySelectionColors {
    for (UIControl *c in self.buttons) {
        BOOL sel = c.tag == self.selectedIndex;
        UIColor *col = sel ? [CalciteTheme accent] : UIColor.secondaryLabelColor;
        ((UIImageView *)[c viewWithTag:1]).tintColor = col;
        ((UILabel *)[c viewWithTag:2]).textColor = col;
    }
}

- (void)tapped:(UIControl *)c {
    [self selectIndex:c.tag animated:YES notify:YES];
}

- (void)selectIndex:(NSInteger)index animated:(BOOL)animated notify:(BOOL)notify {
    if (index < 0 || index >= (NSInteger)self.buttons.count) return;
    BOOL changed = index != self.selectedIndex;
    self.selectedIndex = index;
    void (^anim)(void) = ^{
        [self layoutSubviews];
        [self applySelectionColors];
    };
    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.55 delay:0 usingSpringWithDamping:0.72 initialSpringVelocity:0.6 options:UIViewAnimationOptionBeginFromCurrentState animations:anim completion:nil];
    } else anim();
    if (changed && animated) {
        [[UISelectionFeedbackGenerator new] selectionChanged];
        [CalciteMotion bounceSymbolIn:self.buttons[index]];
    }
    if (notify && changed && self.onSelect) self.onSelect(index);
}

- (void)setShown:(BOOL)shown animated:(BOOL)animated {
    void (^apply)(void) = ^{
        self.alpha = shown ? 1 : 0;
        self.transform = shown ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0, 40);
    };
    self.userInteractionEnabled = shown;
    if (animated) [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.2 options:UIViewAnimationOptionBeginFromCurrentState animations:apply completion:nil];
    else apply();
}

@end
