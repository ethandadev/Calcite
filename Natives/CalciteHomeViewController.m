#import "CalciteHomeViewController.h"
#import "CalciteTheme.h"
#import "CalciteBuiltInJIT.h"
#import "CalciteModBrowser.h"
#import "CalcitePerformancePack.h"
#import "CalciteSkinManager.h"
#import "CalciteHealthCheck.h"
#import "CalciteWorldBackup.h"
#import "LauncherMenuViewController.h"
#import "LauncherPreferences.h"
#import "PLProfiles.h"
#import "authenticator/BaseAuthenticator.h"
#import "ios_uikit_bridge.h"
#import "utils.h"

@interface CalciteHomeViewController ()
@property(nonatomic) UILabel *profileLabel, *versionLabel, *greetingLabel;
@property(nonatomic) UIStackView *chips;
@property(nonatomic) UILabel *tipLabel;
@end

@implementation CalciteHomeViewController

- (instancetype)init {
    self = [super init];
    self.title = @"Home";
    return self;
}

- (NSString *)imageName { return @"house.fill"; }

- (UIView *)chip:(NSString *)text ok:(BOOL)ok {
    UILabel *l = [UILabel new];
    l.text = [NSString stringWithFormat:@"  %@ %@  ", ok ? @"●" : @"○", text];
    l.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    l.textColor = ok ? [CalciteTheme accent] : UIColor.secondaryLabelColor;
    l.backgroundColor = [CalciteTheme cardBackground];
    l.layer.cornerRadius = 11;
    l.layer.masksToBounds = YES;
    return l;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [CalciteTheme background];
    self.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
    self.navigationItem.rightBarButtonItem = [sidebarViewController drawAccountButton];
    self.navigationItem.leftItemsSupplementBackButton = YES;

    UIScrollView *scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    [self.view addSubview:scroll];
    UIStackView *root = [UIStackView new];
    root.axis = UILayoutConstraintAxisVertical;
    root.spacing = 18;
    root.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:root];
    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:g.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [root.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16],
        [root.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24],
        [root.leadingAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.leadingAnchor constant:20],
        [root.trailingAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.trailingAnchor constant:-20],
        [root.widthAnchor constraintLessThanOrEqualToConstant:760],
    ]];
    NSLayoutConstraint *wide = [root.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-40];
    wide.priority = UILayoutPriorityDefaultHigh;
    wide.active = YES;

    // Hero play card
    UIView *hero = [UIView new];
    hero.layer.cornerRadius = 24;
    hero.layer.cornerCurve = kCACornerCurveContinuous;
    hero.layer.masksToBounds = YES;
    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.colors = @[(id)[CalciteTheme accent].CGColor, (id)[CalciteTheme accentDeep].CGColor];
    grad.startPoint = CGPointMake(0, 0);
    grad.endPoint = CGPointMake(1, 1);
    [hero.layer insertSublayer:grad atIndex:0];
    hero.tag = 7;
    self.greetingLabel = [UILabel new];
    self.greetingLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.greetingLabel.textColor = [UIColor colorWithWhite:1 alpha:0.8];
    self.profileLabel = [UILabel new];
    self.profileLabel.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold];
    self.profileLabel.textColor = UIColor.whiteColor;
    self.profileLabel.adjustsFontSizeToFitWidth = YES;
    self.versionLabel = [UILabel new];
    self.versionLabel.font = [UIFont systemFontOfSize:14];
    self.versionLabel.textColor = [UIColor colorWithWhite:1 alpha:0.85];
    UIButtonConfiguration *cfg = [UIButtonConfiguration filledButtonConfiguration];
    cfg.title = @"Play";
    cfg.image = [UIImage systemImageNamed:@"play.fill"];
    cfg.imagePadding = 8;
    cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    cfg.baseBackgroundColor = UIColor.whiteColor;
    cfg.baseForegroundColor = [CalciteTheme accentDeep];
    cfg.contentInsets = NSDirectionalEdgeInsetsMake(12, 28, 12, 28);
    UIButton *play = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    [play addTarget:self action:@selector(play:) forControlEvents:UIControlEventTouchUpInside];
    UIStackView *heroStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.greetingLabel, self.profileLabel, self.versionLabel, play]];
    heroStack.axis = UILayoutConstraintAxisVertical;
    heroStack.alignment = UIStackViewAlignmentLeading;
    heroStack.spacing = 6;
    [heroStack setCustomSpacing:16 afterView:self.versionLabel];
    heroStack.translatesAutoresizingMaskIntoConstraints = NO;
    [hero addSubview:heroStack];
    [NSLayoutConstraint activateConstraints:@[
        [heroStack.topAnchor constraintEqualToAnchor:hero.topAnchor constant:22],
        [heroStack.bottomAnchor constraintEqualToAnchor:hero.bottomAnchor constant:-22],
        [heroStack.leadingAnchor constraintEqualToAnchor:hero.leadingAnchor constant:22],
        [heroStack.trailingAnchor constraintEqualToAnchor:hero.trailingAnchor constant:-22],
    ]];
    [root addArrangedSubview:hero];

    // Status chips
    self.chips = [UIStackView new];
    self.chips.axis = UILayoutConstraintAxisHorizontal;
    self.chips.spacing = 8;
    UIScrollView *chipScroll = [UIScrollView new];
    chipScroll.showsHorizontalScrollIndicator = NO;
    self.chips.translatesAutoresizingMaskIntoConstraints = NO;
    chipScroll.translatesAutoresizingMaskIntoConstraints = NO;
    [chipScroll addSubview:self.chips];
    [NSLayoutConstraint activateConstraints:@[
        [self.chips.topAnchor constraintEqualToAnchor:chipScroll.contentLayoutGuide.topAnchor],
        [self.chips.bottomAnchor constraintEqualToAnchor:chipScroll.contentLayoutGuide.bottomAnchor],
        [self.chips.leadingAnchor constraintEqualToAnchor:chipScroll.contentLayoutGuide.leadingAnchor],
        [self.chips.trailingAnchor constraintEqualToAnchor:chipScroll.contentLayoutGuide.trailingAnchor],
        [self.chips.heightAnchor constraintEqualToAnchor:chipScroll.frameLayoutGuide.heightAnchor],
        [chipScroll.heightAnchor constraintEqualToConstant:24],
    ]];
    [root addArrangedSubview:chipScroll];

    // Quick actions
    UILabel *sec = [UILabel new];
    sec.text = @"Quick actions";
    sec.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    [root addArrangedSubview:sec];
    NSArray *actions = @[
        @[@"puzzlepiece.extension.fill", @"Mod Browser", @"Find and install mods", @"mods"],
        @[@"bolt.fill", @"Performance Pack", @"Sodium, Lithium and more", @"perf"],
        @[@"person.crop.square.fill", @"Skin Manager", @"Change your skin", @"skin"],
        @[@"clock.arrow.circlepath", @"Restore World", @"Bring back a backup", @"restore"],
        @[@"checkmark.shield.fill", @"Health Check", @"Is everything set up?", @"health"],
        @[@"slider.horizontal.3", @"Settings", @"Controls, JIT, Java", @"settings"],
    ];
    UIStackView *grid = [UIStackView new];
    grid.axis = UILayoutConstraintAxisVertical;
    grid.spacing = 12;
    for (NSUInteger i = 0; i < actions.count; i += 2) {
        UIStackView *row = [UIStackView new];
        row.distribution = UIStackViewDistributionFillEqually;
        row.spacing = 12;
        for (NSUInteger j = i; j < i + 2 && j < actions.count; j++) {
            NSArray *a = actions[j];
            UIControl *card = [CalciteTheme actionCardWithSymbol:a[0] title:a[1] subtitle:a[2]];
            card.accessibilityIdentifier = a[3];
            [card addTarget:self action:@selector(cardTapped:) forControlEvents:UIControlEventTouchUpInside];
            [row addArrangedSubview:card];
        }
        [grid addArrangedSubview:row];
    }
    [root addArrangedSubview:grid];

    // Tip
    self.tipLabel = [UILabel new];
    self.tipLabel.numberOfLines = 0;
    self.tipLabel.font = [UIFont systemFontOfSize:13];
    self.tipLabel.textColor = UIColor.secondaryLabelColor;
    [root addArrangedSubview:self.tipLabel];

    [self refresh];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIView *hero = [self.view viewWithTag:7];
    for (CALayer *l in hero.layer.sublayers) {
        if ([l isKindOfClass:CAGradientLayer.class]) l.frame = hero.bounds;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refresh];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    UIView *hero = [self.view viewWithTag:7];
    CAGradientLayer *grad = nil;
    for (CALayer *l in hero.layer.sublayers) if ([l isKindOfClass:CAGradientLayer.class]) grad = (CAGradientLayer *)l;
    UIView *play = nil;
    for (UIView *v in hero.subviews) for (UIView *w in v.subviews) if ([w isKindOfClass:UIButton.class]) play = w;
    if (grad && play) [CalciteTheme animateHero:hero gradient:grad play:play];
    static BOOL first = YES;
    if (first) {
        first = NO;
        UIStackView *root = nil;
        for (UIView *v in self.view.subviews) for (UIView *w in v.subviews) if ([w isKindOfClass:UIStackView.class]) root = (UIStackView *)w;
        if (root) [CalciteTheme riseIn:root.arrangedSubviews];
    }
}

- (void)refresh {
    NSDictionary *profile = PLProfiles.current.selectedProfile;
    NSString *name = PLProfiles.current.selectedProfileName ?: @"Minecraft";
    NSString *versionId = profile[@"lastVersionId"] ?: @"latest-release";
    NSString *user = BaseAuthenticator.current.authData[@"username"];
    self.greetingLabel.text = user ? [NSString stringWithFormat:@"WELCOME BACK, %@", user.uppercaseString] : @"WELCOME TO CALCITE";
    self.profileLabel.text = name;
    self.versionLabel.text = versionId;

    for (UIView *v in self.chips.arrangedSubviews) [v removeFromSuperview];
    BOOL jit = isJITEnabled(NO);
    [self.chips addArrangedSubview:[self chip:jit ? @"JIT on" : @"JIT off until launch" ok:jit]];
    BOOL bi = getPrefBool(@"general.builtin_jit");
    [self.chips addArrangedSubview:[self chip:bi ? @"Built-in JIT" : @"StikDebug JIT" ok:bi]];
    float mb = getPrefFloat(@"java.allocated_memory");
    [self.chips addArrangedSubview:[self chip:[NSString stringWithFormat:@"%.0f MB RAM", mb] ok:YES]];
    NSString *lower = versionId.lowercaseString;
    BOOL modded = [lower containsString:@"fabric"] || [lower containsString:@"forge"] || [lower containsString:@"quilt"];
    [self.chips addArrangedSubview:[self chip:modded ? @"Modded" : @"Vanilla" ok:modded]];

    NSArray *tips = @[
        @"Tip: swipe right on a profile to clone it with its own mods and worlds.",
        @"Tip: Performance Pack installs Sodium, Lithium and friends in one tap on Fabric profiles.",
        @"Tip: pick a control layout per profile in the profile editor. There are nine to try.",
        @"Tip: worlds are backed up automatically. Restore World brings one back safely.",
        @"Tip: Health Check tells you what's missing if the game won't start.",
    ];
    self.tipLabel.text = tips[(NSUInteger)(NSDate.date.timeIntervalSince1970 / 3600) % tips.count];
}

- (void)play:(UIButton *)sender {
    SEL sel = NSSelectorFromString(@"performInstallOrShowDetails:");
    if ([self.navigationController respondsToSelector:sel]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.navigationController performSelector:sel withObject:sender];
        #pragma clang diagnostic pop
    }
}

- (void)cardTapped:(UIControl *)card {
    NSString *k = card.accessibilityIdentifier;
    if ([k isEqualToString:@"mods"]) [CalciteModBrowser presentFrom:self];
    else if ([k isEqualToString:@"perf"]) [CalcitePerformancePack installForSelectedProfileFrom:self];
    else if ([k isEqualToString:@"skin"]) [CalciteSkinManager presentFrom:self];
    else if ([k isEqualToString:@"restore"]) [CalciteWorldBackup presentRestoreFrom:self];
    else if ([k isEqualToString:@"health"]) [CalciteHealthCheck presentFrom:self];
    else if ([k isEqualToString:@"settings"]) {
        UITableView *table = sidebarViewController.tableView;
        for (NSInteger i = 0; i < [table numberOfRowsInSection:0]; i++) {
            UITableViewCell *c = [table cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
            if ([c.textLabel.text isEqualToString:localize(@"Settings", nil)] || [c.textLabel.text.lowercaseString containsString:@"setting"]) {
                [table selectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] animated:YES scrollPosition:UITableViewScrollPositionNone];
                [sidebarViewController tableView:table didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
                break;
            }
        }
    }
}

@end
