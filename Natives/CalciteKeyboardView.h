#import <UIKit/UIKit.h>
#import "TrackedTextField.h"

/// Compact on-screen keyboard used instead of the full iOS keyboard while playing.
/// It is only ~160pt tall (the system keyboard covers about half of a landscape screen).
@interface CalciteKeyboardView : UIInputView

@property(nonatomic, weak) TrackedTextField *target;

- (instancetype)initWithTarget:(TrackedTextField *)target;

@end
