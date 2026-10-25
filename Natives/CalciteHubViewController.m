#import "CalciteHubViewController.h"
#import "CalciteTheme.h"
#import "CalciteMotion.h"
#import "LauncherMenuViewController.h"

@interface CalciteHubViewController ()
@property(nonatomic) NSArray<NSDictionary *> *sections;
@property(nonatomic) NSMutableArray<UIView *> *revealables;
@property(nonatomic) BOOL revealed;
@end

@implementation CalciteHubViewController

- (instancetype)initWithTitle:(NSString *)title sections:(NSArray<NSDictionary *> *)sections {
    if (!(self = [super init])) return nil;
    self.title = title;
    self.sections = sections;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [CalciteTheme background];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.rightBarButtonItem = [sidebarViewController drawAccountButton];

    UIScrollView *scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    [self.view addSubview:scroll];
    UIStackView *root = [UIStackView new];
    root.axis = UILayoutConstraintAxisVertical;
    root.spacing = 14;
    root.layoutMargins = UIEdgeInsetsMake(8, 16, 24, 16);
    root.layoutMarginsRelativeArrangement = YES;
    root.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:root];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [root.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [root.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [root.leadingAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.leadingAnchor],
        [root.trailingAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.trailingAnchor],
        [root.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],
    ]];
    self.revealables = [NSMutableArray array];

    __weak typeof(self) weak = self;
    for (NSDictionary *section in self.sections) {
        if ([section[@"title"] length]) {
            UILabel *h = [UILabel new];
            h.text = section[@"title"];
            h.font = [CalciteTheme roundedFont:20 weight:UIFontWeightBold];
            [root addArrangedSubview:h];
            [self.revealables addObject:h];
            [root setCustomSpacing:10 afterView:h];
        }
        NSArray *cards = section[@"cards"];
        UIStackView *grid = [UIStackView new];
        grid.axis = UILayoutConstraintAxisVertical;
        grid.spacing = 12;
        for (NSUInteger i = 0; i < cards.count; i += 2) {
            UIStackView *row = [UIStackView new];
            row.distribution = UIStackViewDistributionFillEqually;
            row.spacing = 12;
            for (NSUInteger j = i; j < i + 2; j++) {
                if (j >= cards.count) { [row addArrangedSubview:[UIView new]]; continue; }
                NSDictionary *c = cards[j];
                UIControl *card = [CalciteTheme actionCardWithSymbol:c[@"symbol"] title:c[@"title"] subtitle:c[@"subtitle"]];
                void (^action)(UIViewController *) = c[@"action"];
                [card addAction:[UIAction actionWithHandler:^(UIAction *a) {
                    [CalciteMotion bounceSymbolIn:card];
                    if (action) action(weak);
                }] forControlEvents:UIControlEventTouchUpInside];
                [row addArrangedSubview:card];
                [self.revealables addObject:card];
            }
            [grid addArrangedSubview:row];
        }
        [root addArrangedSubview:grid];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.revealed) {
        self.revealed = YES;
        [CalciteTheme riseIn:self.revealables];
    }
}

@end
