#import <UIKit/UIKit.h>

/// Reads the previous session's log and, if it spots a known problem, explains it in plain English.
@interface CalciteCrashExplainer : NSObject

/// Returns a short human explanation for a Minecraft/Java log, or nil if nothing recognisable was found.
+ (NSString *)explanationForLog:(NSString *)log;

/// Shows an alert on `viewController` once per new previous-session log. Safe to call on every appearance.
+ (void)presentIfNeededFrom:(UIViewController *)viewController;

@end
