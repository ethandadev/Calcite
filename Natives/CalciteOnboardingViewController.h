#import <UIKit/UIKit.h>

// First-launch welcome tour: aurora background, parallax pages, staggered spring reveals.
@interface CalciteOnboardingViewController : UIViewController
+ (BOOL)shouldPresent;
+ (void)presentFrom:(UIViewController *)presenter force:(BOOL)force;
@end
