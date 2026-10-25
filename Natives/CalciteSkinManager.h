#import <UIKit/UIKit.h>

/// Upload a skin PNG (classic or slim) to the signed-in Microsoft account, or reset it.
@interface CalciteSkinManager : NSObject <UIDocumentPickerDelegate>
+ (void)presentFrom:(UIViewController *)presenter;
@end
