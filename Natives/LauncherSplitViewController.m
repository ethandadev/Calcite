#import "LauncherSplitViewController.h"
#import "LauncherMenuViewController.h"
#import "LauncherProfilesViewController.h"
#import "LauncherNavigationController.h"
#import "LauncherPreferences.h"
#import "utils.h"
#import "CalciteTabBar.h"
#import "CalciteTheme.h"
#import "CalciteHomeViewController.h"
#import "CalciteHubViewController.h"
#import "CalciteModBrowser.h"
#import "CalciteSkinManager.h"
#import "CalcitePerformancePack.h"
#import "CalciteWorldBackup.h"
#import "CalciteHealthCheck.h"
#import "CalciteOnboardingViewController.h"
#import "LauncherNewsViewController.h"
#import "LauncherPreferencesViewController.h"
#import "ios_uikit_bridge.h"

extern NSMutableDictionary *prefDict;

@interface LauncherSplitViewController ()<UISplitViewControllerDelegate, UINavigationControllerDelegate>
@property(nonatomic) CalciteTabBar *tabBar;
@property(nonatomic) NSArray<UIViewController *> *tabRoots;
@end

@implementation LauncherSplitViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    if ([getPrefObject(@"control.control_safe_area") length] == 0) {
        setPrefObject(@"control.control_safe_area", NSStringFromUIEdgeInsets(getDefaultSafeArea()));
    }

    self.delegate = self;

    UINavigationController *masterVc = [[UINavigationController alloc] initWithRootViewController:[[LauncherMenuViewController alloc] init]];
    LauncherNavigationController *detailVc = [[LauncherNavigationController alloc] initWithRootViewController:[[LauncherProfilesViewController alloc] init]];
    detailVc.toolbarHidden = NO;

    self.viewControllers = @[masterVc, detailVc];
    [self changeDisplayModeForSize:self.view.frame.size];
    
    self.maximumPrimaryColumnWidth = self.view.bounds.size.width * 0.95;
    [self setupCalciteNavigationWithDetail:detailVc];
}

#pragma mark - Calcite navigation

- (UINavigationController *)contentNav { return (UINavigationController *)self.viewControllers[1]; }

- (void)setupCalciteNavigationWithDetail:(LauncherNavigationController *)detail {
    // The sidebar is replaced by a floating tab bar; keep the column hidden.
    self.preferredDisplayMode = UISplitViewControllerDisplayModeSecondaryOnly;
    self.presentsWithGesture = NO;
    self.view.backgroundColor = [CalciteTheme background];

    __weak typeof(self) weak = self;
    UIViewController *(^hub)(NSString *, NSArray *) = ^UIViewController *(NSString *t, NSArray *sections) {
        return [[CalciteHubViewController alloc] initWithTitle:t sections:sections];
    };
    typedef void (^Act)(UIViewController *);
    Act mods = ^(UIViewController *vc) { [CalciteModBrowser presentFrom:vc]; };
    Act perf = ^(UIViewController *vc) { [CalcitePerformancePack installForSelectedProfileFrom:vc]; };
    Act skin = ^(UIViewController *vc) { [CalciteSkinManager presentFrom:vc]; };
    Act news = ^(UIViewController *vc) { [vc.navigationController pushViewController:[LauncherNewsViewController new] animated:YES]; };
    Act restore = ^(UIViewController *vc) { [CalciteWorldBackup presentRestoreFrom:vc]; };
    Act health = ^(UIViewController *vc) { [CalciteHealthCheck presentFrom:vc]; };
    Act controls = ^(UIViewController *vc) { [(id)[weak contentNav] performSelector:@selector(enterCustomControls)]; };
    Act jar = ^(UIViewController *vc) { [(id)[weak contentNav] performSelector:@selector(enterModInstaller)]; };
    Act logs = ^(UIViewController *vc) {
        NSURL *u = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%s/latestlog.old.txt", getenv("AME_HOME")]];
        UIActivityViewController *a = [[UIActivityViewController alloc] initWithActivityItems:@[u] applicationActivities:nil];
        a.popoverPresentationController.sourceView = vc.view;
        a.popoverPresentationController.sourceRect = CGRectMake(vc.view.bounds.size.width / 2, vc.view.bounds.size.height / 2, 1, 1);
        [vc presentViewController:a animated:YES completion:nil];
    };
    Act tour = ^(UIViewController *vc) { [CalciteOnboardingViewController presentFrom:vc force:YES]; };
    Act bug = ^(UIViewController *vc) { [UIApplication.sharedApplication openURL:[NSURL URLWithString:@"https://github.com/ethandadev/Calcite/issues/new"] options:@{} completionHandler:nil]; };

    UIViewController *discover = hub(@"Discover", @[
        @{@"title": @"Make it yours", @"cards": @[
            @{@"symbol": @"puzzlepiece.extension.fill", @"title": @"Mods", @"subtitle": @"Search Modrinth, install with dependencies", @"action": mods},
            @{@"symbol": @"bolt.fill", @"title": @"Performance Pack", @"subtitle": @"Sodium, Lithium and friends in one tap", @"action": perf},
            @{@"symbol": @"person.crop.square.fill", @"title": @"Skins", @"subtitle": @"Change how you look in game", @"action": skin},
            @{@"symbol": @"newspaper.fill", @"title": @"News", @"subtitle": @"What's new in Minecraft", @"action": news},
        ]},
    ]);
    UIViewController *tools = hub(@"Tools", @[
        @{@"title": @"Your worlds", @"cards": @[
            @{@"symbol": @"clock.arrow.circlepath", @"title": @"Restore World", @"subtitle": @"Bring back an automatic backup", @"action": restore},
            @{@"symbol": @"checkmark.shield.fill", @"title": @"Health Check", @"subtitle": @"Is everything set up right?", @"action": health},
        ]},
        @{@"title": @"Play your way", @"cards": @[
            @{@"symbol": @"gamecontroller.fill", @"title": @"Controls", @"subtitle": @"Layouts, buttons and gestures", @"action": controls},
            @{@"symbol": @"shippingbox.fill", @"title": @"Run a .jar", @"subtitle": @"Install a mod loader or launch a jar", @"action": jar},
        ]},
        @{@"title": @"Help", @"cards": @[
            @{@"symbol": @"sparkles", @"title": @"Welcome Tour", @"subtitle": @"Replay the intro", @"action": tour},
            @{@"symbol": @"square.and.arrow.up", @"title": @"Share Last Log", @"subtitle": @"Send the log when asking for help", @"action": logs},
            @{@"symbol": @"ladybug.fill", @"title": @"Report a Bug", @"subtitle": @"Open an issue on GitHub", @"action": bug},
        ]},
    ]);
    self.tabRoots = @[
        [CalciteHomeViewController new],
        [LauncherProfilesViewController new],
        discover,
        tools,
        [LauncherPreferencesViewController new],
    ];
    self.tabBar = [[CalciteTabBar alloc] initWithItems:@[
        @{@"symbol": @"play.circle.fill", @"title": @"Play"},
        @{@"symbol": @"square.stack.3d.up.fill", @"title": @"Library"},
        @{@"symbol": @"safari.fill", @"title": @"Discover"},
        @{@"symbol": @"wrench.and.screwdriver.fill", @"title": @"Tools"},
        @{@"symbol": @"gearshape.fill", @"title": @"Settings"},
    ]];
    self.tabBar.onSelect = ^(NSInteger i) { [weak showTab:i]; };
    // The bar is attached to the window once the UI is on screen (see viewDidAppear); the split view's
    // own column containers would otherwise cover it, and the toolbar isn't in the hierarchy yet here.

    detail.delegate = self;
    detail.additionalSafeAreaInsets = UIEdgeInsetsMake(0, 0, 72, 0);
    [self showTab:0 animated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self layoutTabBar];
    dispatch_async(dispatch_get_main_queue(), ^{ [self layoutTabBar]; });
    [CalciteOnboardingViewController presentFrom:self force:NO];
}

- (void)showTab:(NSInteger)i { [self showTab:i animated:YES]; }

- (void)showTab:(NSInteger)i animated:(BOOL)animated {
    UINavigationController *nav = [self contentNav];
    UIViewController *vc = self.tabRoots[i];
    if (animated) {
        CATransition *t = [CATransition animation];
        t.type = kCATransitionFade;
        t.duration = 0.28;
        t.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [nav.view.layer addAnimation:t forKey:@"calciteTab"];
    }
    vc.navigationItem.leftBarButtonItem = nil;
    [nav setViewControllers:@[vc] animated:NO];
}

- (void)navigationController:(UINavigationController *)nav willShowViewController:(UIViewController *)vc animated:(BOOL)animated {
    BOOL root = nav.viewControllers.firstObject == vc || [self.tabRoots containsObject:vc];
    id<UIViewControllerTransitionCoordinator> tc = nav.transitionCoordinator;
    if (tc) {
        [tc animateAlongsideTransition:^(id ctx) { [self.tabBar setShown:root animated:NO]; } completion:nil];
    } else {
        [self.tabBar setShown:root animated:animated];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // Don't leave the bar floating over the game or full-screen covers.
    [self.tabBar removeFromSuperview];
}

- (void)layoutTabBar {
    UIWindow *window = self.view.window;
    if (!window || !self.tabBar) return;
    if (self.tabBar.superview != window) [window addSubview:self.tabBar];
    CGFloat h = 58;
    UINavigationController *nav = [self contentNav];
    UIToolbar *tb = nav.toolbar;
    // Line the bar up with the Play bar: same left edge as the version pill, same right edge as Play.
    CGFloat left = 16, right = window.bounds.size.width - 16;
    @try {
        UIView *field = [nav valueForKey:@"versionTextField"];
        UIBarButtonItem *play = [nav valueForKey:@"buttonInstallItem"];
        UIView *fieldBox = field.superview ?: field;
        if (fieldBox.window) {
            CGFloat l = [fieldBox convertRect:fieldBox.bounds toView:window].origin.x;
            if (l > 0 && l < window.bounds.size.width / 3) left = l;
        }
        UIView *playView = nil;
        if ([play respondsToSelector:NSSelectorFromString(@"buttonGlassView")]) playView = [play valueForKey:@"buttonGlassView"];
        if (!playView) playView = [play valueForKey:@"view"];
        if (playView.window) {
            CGFloat r = CGRectGetMaxX([playView convertRect:playView.bounds toView:window]);
            if (r > window.bounds.size.width * 2 / 3 && r <= window.bounds.size.width) right = r;
        }
    } @catch (NSException *e) {}
    CGFloat w = MIN(right - left, 460);
    CGFloat x = left + ((right - left) - w) / 2;
    CGFloat y;
    if (tb.window) {
        CGRect r = [tb convertRect:tb.bounds toView:window];
        y = r.origin.y - h - 8;
    } else {
        y = window.bounds.size.height - window.safeAreaInsets.bottom - 49 - h - 8;
    }
    CGAffineTransform t = self.tabBar.transform;
    self.tabBar.transform = CGAffineTransformIdentity;
    self.tabBar.frame = CGRectMake(x, y, w, h);
    self.tabBar.transform = t;
    [window bringSubviewToFront:self.tabBar];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutTabBar];
}

- (void)showTabIndex:(NSNumber *)index {
    [self.tabBar selectIndex:index.integerValue animated:YES notify:YES];
}

- (void)splitViewController:(UISplitViewController *)svc willChangeToDisplayMode:(UISplitViewControllerDisplayMode)displayMode {
    if (self.preferredDisplayMode != displayMode && self.displayMode != UISplitViewControllerDisplayModeSecondaryOnly) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.preferredDisplayMode = UISplitViewControllerDisplayModeSecondaryOnly;
        });
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [self changeDisplayModeForSize:size];
}

- (void)changeDisplayModeForSize:(CGSize)size {
    BOOL isPortrait = size.height > size.width;
    if (self.preferredDisplayMode == 0 || self.displayMode != UISplitViewControllerDisplayModeSecondaryOnly) {
        if(!getPrefBool(@"general.hidden_sidebar")) {
            self.preferredDisplayMode = isPortrait ?
                UISplitViewControllerDisplayModeOneOverSecondary :
                UISplitViewControllerDisplayModeOneBesideSecondary;
        } else {
            self.preferredDisplayMode = UISplitViewControllerDisplayModeSecondaryOnly;
        }
    }
    self.preferredSplitBehavior = isPortrait ?
        UISplitViewControllerSplitBehaviorOverlay :
        UISplitViewControllerSplitBehaviorTile;
}

- (void)dismissViewController {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
