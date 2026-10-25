#import "CalciteKeyboardView.h"
#include "glfw_keycodes.h"

typedef NS_ENUM(NSInteger, CKKind) {
    CKKindChar, CKKindShift, CKKindBackspace, CKKindReturn, CKKindSpace, CKKindLayer, CKKindHide
};

@interface CKKey : NSObject
@property(nonatomic) NSString *title;
@property(nonatomic) CGFloat weight;
@property(nonatomic) CKKind kind;
+ (instancetype)key:(NSString *)title weight:(CGFloat)weight kind:(CKKind)kind;
@end
@implementation CKKey
+ (instancetype)key:(NSString *)title weight:(CGFloat)weight kind:(CKKind)kind {
    CKKey *k = [CKKey new];
    k.title = title; k.weight = weight; k.kind = kind;
    return k;
}
@end

static const CGFloat kKeyHeight = 34;
static const CGFloat kKeyGap = 4;
static const CGFloat kSidePad = 4;

@interface CalciteKeyboardView ()
@property(nonatomic) BOOL symbols;
@property(nonatomic) BOOL shift;
@property(nonatomic) BOOL capsLock;
@property(nonatomic) NSMutableArray<UIButton *> *buttons;
@property(nonatomic) NSMutableArray<CKKey *> *buttonKeys;
@property(nonatomic) NSArray<NSArray<CKKey *> *> *rows;
@property(nonatomic) NSTimer *repeatTimer;
@property(nonatomic) UIImpactFeedbackGenerator *haptic;
@end

@implementation CalciteKeyboardView

- (instancetype)initWithTarget:(TrackedTextField *)target {
    self = [super initWithFrame:CGRectMake(0, 0, 320, 160) inputViewStyle:UIInputViewStyleKeyboard];
    if (self) {
        self.target = target;
        self.allowsSelfSizing = YES;
        self.buttons = [NSMutableArray new];
        self.buttonKeys = [NSMutableArray new];
        self.haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [self rebuild];
    }
    return self;
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(UIViewNoIntrinsicMetric, kSidePad * 2 + kKeyHeight * 4 + kKeyGap * 3 + 2);
}

#pragma mark Layout

+ (NSArray<CKKey *> *)charRow:(NSString *)chars {
    NSMutableArray *row = [NSMutableArray new];
    for (NSUInteger i = 0; i < chars.length; i++) {
        [row addObject:[CKKey key:[chars substringWithRange:NSMakeRange(i, 1)] weight:1 kind:CKKindChar]];
    }
    return row;
}

- (void)rebuild {
    for (UIButton *b in self.buttons) [b removeFromSuperview];
    [self.buttons removeAllObjects];
    [self.buttonKeys removeAllObjects];

    NSArray *r1, *r2, *r3;
    NSString *layerTitle = self.symbols ? @"ABC" : @"123";
    if (self.symbols) {
        r1 = [CalciteKeyboardView charRow:@"1234567890"];
        r2 = [CalciteKeyboardView charRow:@"-/:;()$&@\""];
        NSMutableArray *row3 = [NSMutableArray new];
        [row3 addObject:[CKKey key:@"_" weight:1 kind:CKKindChar]];
        [row3 addObjectsFromArray:[CalciteKeyboardView charRow:@".,?!'"]];
        [row3 addObject:[CKKey key:@"#" weight:1 kind:CKKindChar]];
        [row3 addObject:[CKKey key:@"⌫" weight:1.5 kind:CKKindBackspace]];
        r3 = row3;
    } else {
        r1 = [CalciteKeyboardView charRow:@"qwertyuiop"];
        r2 = [CalciteKeyboardView charRow:@"asdfghjkl"];
        NSMutableArray *row3 = [NSMutableArray new];
        [row3 addObject:[CKKey key:(self.capsLock ? @"⇪" : @"⇧") weight:1.5 kind:CKKindShift]];
        [row3 addObjectsFromArray:[CalciteKeyboardView charRow:@"zxcvbnm"]];
        [row3 addObject:[CKKey key:@"⌫" weight:1.5 kind:CKKindBackspace]];
        r3 = row3;
    }
    NSArray *r4 = @[
        [CKKey key:layerTitle weight:1.5 kind:CKKindLayer],
        [CKKey key:@"space" weight:5 kind:CKKindSpace],
        [CKKey key:@"return" weight:2 kind:CKKindReturn],
        [CKKey key:@"⌄" weight:1 kind:CKKindHide],
    ];
    self.rows = @[r1, r2, r3, r4];

    for (NSArray<CKKey *> *row in self.rows) {
        for (CKKey *key in row) {
            UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
            NSString *title = key.title;
            if (key.kind == CKKindChar && !self.symbols && (self.shift || self.capsLock)) {
                title = title.uppercaseString;
            }
            [b setTitle:title forState:UIControlStateNormal];
            b.titleLabel.font = [UIFont systemFontOfSize:(key.kind == CKKindChar ? 18 : 14) weight:UIFontWeightMedium];
            [b setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
            BOOL special = key.kind != CKKindChar && key.kind != CKKindSpace;
            b.backgroundColor = special ? [UIColor colorWithWhite:0.5 alpha:0.35] : [UIColor colorWithWhite:0.75 alpha:0.35];
            if (key.kind == CKKindShift && (self.shift || self.capsLock)) {
                b.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.7];
                [b setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
            }
            b.layer.cornerRadius = 6;
            b.tag = self.buttons.count;
            [b addTarget:self action:@selector(keyDown:) forControlEvents:UIControlEventTouchDown];
            [b addTarget:self action:@selector(keyUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
            [self addSubview:b];
            [self.buttons addObject:b];
            [self.buttonKeys addObject:key];
        }
    }
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.bounds.size.width - kSidePad * 2;
    CGFloat y = kSidePad;
    NSUInteger index = 0;
    for (NSArray<CKKey *> *row in self.rows) {
        CGFloat totalWeight = 0;
        for (CKKey *k in row) totalWeight += k.weight;
        CGFloat unit = (width - kKeyGap * (row.count - 1)) / totalWeight;
        // Center short rows (e.g. the 9-key home row)
        CGFloat x = kSidePad;
        if (row.count == 9) x += unit * 0.5;
        for (CKKey *k in row) {
            CGFloat w = unit * k.weight;
            self.buttons[index].frame = CGRectMake(x, y, w, kKeyHeight);
            x += w + kKeyGap;
            index++;
        }
        y += kKeyHeight + kKeyGap;
    }
}

#pragma mark Input

- (void)sendKey:(int)key {
    if (!self.target.sendKey) return;
    self.target.sendKey(key, 0, 1, 0);
    self.target.sendKey(key, 0, 0, 0);
}

- (void)keyDown:(UIButton *)button {
    [self.haptic impactOccurred];
    CKKey *key = self.buttonKeys[button.tag];
    if (key.kind == CKKindBackspace) {
        [self sendKey:GLFW_KEY_BACKSPACE];
        [self.repeatTimer invalidate];
        self.repeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.4 repeats:NO block:^(NSTimer *t) {
            self.repeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.06 repeats:YES block:^(NSTimer *t2) {
                [self sendKey:GLFW_KEY_BACKSPACE];
            }];
        }];
    }
}

- (void)keyUp:(UIButton *)button {
    [self.repeatTimer invalidate];
    self.repeatTimer = nil;
    CKKey *key = self.buttonKeys[button.tag];
    switch (key.kind) {
        case CKKindChar: {
            NSString *text = key.title;
            if (!self.symbols && (self.shift || self.capsLock)) text = text.uppercaseString;
            [self.target sendText:text];
            if (self.shift && !self.capsLock) {
                self.shift = NO;
                [self rebuild];
            }
            break;
        }
        case CKKindSpace:
            [self.target sendText:@" "];
            break;
        case CKKindReturn:
            [self sendKey:GLFW_KEY_ENTER];
            break;
        case CKKindShift: {
            // tap = one capital, tap again = caps lock, tap again = off
            if (self.capsLock) { self.capsLock = NO; self.shift = NO; }
            else if (self.shift) { self.capsLock = YES; }
            else { self.shift = YES; }
            [self rebuild];
            break;
        }
        case CKKindLayer:
            self.symbols = !self.symbols;
            [self rebuild];
            break;
        case CKKindHide:
            [self.target resignFirstResponder];
            self.target.alpha = 1.0f;
            break;
        case CKKindBackspace:
            break; // handled on touch down so it can repeat
    }
}

@end
