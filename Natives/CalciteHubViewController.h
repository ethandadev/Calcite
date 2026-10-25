#import <UIKit/UIKit.h>

// A screen of titled sections, each a grid of big tappable cards. Used for Discover and Tools.
@interface CalciteHubViewController : UIViewController
// sections: @[@{@"title":, @"cards":@[@{@"symbol":,@"title":,@"subtitle":,@"action":^(UIViewController *vc){}}]}]
- (instancetype)initWithTitle:(NSString *)title sections:(NSArray<NSDictionary *> *)sections;
@end
