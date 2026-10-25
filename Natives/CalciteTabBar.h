#import <UIKit/UIKit.h>

// Floating pill tab bar: blurred capsule with a spring-animated selection highlight.
@interface CalciteTabBar : UIView
@property(nonatomic, copy) void (^onSelect)(NSInteger index);
@property(nonatomic, readonly) NSInteger selectedIndex;
- (instancetype)initWithItems:(NSArray<NSDictionary *> *)items; // @{@"symbol":, @"title":}
- (void)selectIndex:(NSInteger)index animated:(BOOL)animated notify:(BOOL)notify;
- (void)setShown:(BOOL)shown animated:(BOOL)animated;
@end
