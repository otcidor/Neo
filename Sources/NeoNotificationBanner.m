#import "NeoNotificationBanner.h"
#import "AppDelegate.h"
#import <QuartzCore/QuartzCore.h>

@interface NeoNotificationBannerView : UIView {
    UIImageView *_avatarView;
    UILabel *_titleLabel;
    UILabel *_bodyLabel;
    UILabel *_timeLabel;
    NSString *_roomId;
    UIPanGestureRecognizer *_panGesture;
    UITapGestureRecognizer *_tapGesture;
}
@end

@implementation NeoNotificationBannerView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0.12 green:0.14 blue:0.18 alpha:0.96];
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOffset = CGSizeMake(0, 3);
        self.layer.shadowOpacity = 0.5f;
        self.layer.shadowRadius = 4.0f;

        UIView *bottomSep = [[UIView alloc] initWithFrame:CGRectMake(0, frame.size.height - 0.5f, frame.size.width, 0.5f)];
        bottomSep.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];
        bottomSep.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        [self addSubview:bottomSep];

        CGFloat topY = (frame.size.height > 64.0f) ? 20.0f : 14.0f;

        _avatarView = [[UIImageView alloc] initWithFrame:CGRectMake(12, topY, 36, 36)];
        _avatarView.layer.cornerRadius = 18.0f;
        _avatarView.layer.masksToBounds = YES;
        _avatarView.backgroundColor = [UIColor colorWithRed:0.20 green:0.52 blue:0.98 alpha:1.0];
        [self addSubview:_avatarView];

        CGFloat contentX = 56.0f;
        CGFloat contentW = frame.size.width - contentX - 50.0f;

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(contentX, topY, contentW, 18)];
        _titleLabel.font = [UIFont boldSystemFontOfSize:14];
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:_titleLabel];

        _timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(frame.size.width - 48, topY + 2, 40, 14)];
        _timeLabel.font = [UIFont systemFontOfSize:11];
        _timeLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
        _timeLabel.backgroundColor = [UIColor clearColor];
        _timeLabel.textAlignment = NSTextAlignmentRight;
        _timeLabel.text = @"now";
        [self addSubview:_timeLabel];

        _bodyLabel = [[UILabel alloc] initWithFrame:CGRectMake(contentX, topY + 18, frame.size.width - contentX - 12, 18)];
        _bodyLabel.font = [UIFont systemFontOfSize:13];
        _bodyLabel.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
        _bodyLabel.backgroundColor = [UIColor clearColor];
        _bodyLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_bodyLabel];

        _tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
        [self addGestureRecognizer:_tapGesture];

        _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:_panGesture];
    }
    return self;
}

- (void)updateWithMessage:(NSString *)message sender:(NSString *)sender roomName:(NSString *)roomName roomId:(NSString *)roomId {
    _roomId = [roomId copy];
    _titleLabel.text = roomName ?: sender ?: @"Neo";
    _bodyLabel.text = message ?: @"";

    NSString *initLetter = [roomName length] > 0 ? [[roomName substringToIndex:1] uppercaseString] : @"#";
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(36, 36), NO, 0.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    NSUInteger hash = [roomName hash];
    CGFloat r = ((hash >> 16) & 0xFF) / 255.0;
    CGFloat g = ((hash >> 8) & 0xFF) / 255.0;
    CGFloat b = (hash & 0xFF) / 255.0;
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:r * 0.7 + 0.3 green:g * 0.7 + 0.3 blue:b * 0.7 + 0.3 alpha:1.0].CGColor);
    CGContextFillEllipseInRect(ctx, CGRectMake(0, 0, 36, 36));

    UIFont *font = [UIFont boldSystemFontOfSize:18];
    CGSize txtSize = [initLetter sizeWithFont:font];
    [[UIColor whiteColor] setFill];
    [initLetter drawInRect:CGRectMake((36 - txtSize.width) / 2, (36 - txtSize.height) / 2, txtSize.width, txtSize.height) withFont:font];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    _avatarView.image = img;
}

- (void)handleTap {
    NSString *rid = _roomId;
    [[NeoNotificationBanner sharedBanner] dismissAnimated:YES];
    if ([rid length] > 0) {
        AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
        if ([appDelegate respondsToSelector:@selector(handleNotificationUserInfo:)]) {
            [appDelegate handleNotificationUserInfo:@{@"room_id": rid}];
        }
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self];
    if (pan.state == UIGestureRecognizerStateChanged) {
        if (translation.y < 0) {
            self.transform = CGAffineTransformMakeTranslation(0, translation.y);
        }
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        CGPoint velocity = [pan velocityInView:self];
        if (translation.y < -15 || velocity.y < -200) {
            [[NeoNotificationBanner sharedBanner] dismissAnimated:YES];
        } else {
            [UIView animateWithDuration:0.2 animations:^{
                self.transform = CGAffineTransformIdentity;
            }];
        }
    }
}

@end

@interface NeoNotificationBanner () {
    UIWindow *_bannerWindow;
    NeoNotificationBannerView *_bannerView;
    NSTimer *_dismissTimer;
}
@end

@implementation NeoNotificationBanner

+ (instancetype)sharedBanner {
    static NeoNotificationBanner *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NeoNotificationBanner alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
        CGFloat bannerH = 64.0f;
        CGRect frame = CGRectMake(0, 0, screenW, bannerH);

        _bannerWindow = [[UIWindow alloc] initWithFrame:frame];
        _bannerWindow.windowLevel = UIWindowLevelStatusBar + 1.0f;
        _bannerWindow.backgroundColor = [UIColor clearColor];
        _bannerWindow.hidden = YES;

        _bannerView = [[NeoNotificationBannerView alloc] initWithFrame:frame];
        [_bannerWindow addSubview:_bannerView];
    }
    return self;
}

+ (void)showMessage:(NSString *)message sender:(NSString *)sender roomName:(NSString *)roomName roomId:(NSString *)roomId {
    [[self sharedBanner] showMessage:message sender:sender roomName:roomName roomId:roomId];
}

- (void)showMessage:(NSString *)message sender:(NSString *)sender roomName:(NSString *)roomName roomId:(NSString *)roomId {
    [_dismissTimer invalidate];

    [_bannerView updateWithMessage:message sender:sender roomName:roomName roomId:roomId];

    CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
    CGFloat bannerH = 64.0f;
    _bannerWindow.frame = CGRectMake(0, 0, screenW, bannerH);
    _bannerView.frame = CGRectMake(0, 0, screenW, bannerH);
    _bannerView.transform = CGAffineTransformMakeTranslation(0, -bannerH);

    _bannerWindow.hidden = NO;

    if ([UIView respondsToSelector:@selector(animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:)]) {
        [UIView animateWithDuration:0.35
                              delay:0
             usingSpringWithDamping:0.85
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self->_bannerView.transform = CGAffineTransformIdentity;
        } completion:nil];
    } else {
        [UIView animateWithDuration:0.3 animations:^{
            self->_bannerView.transform = CGAffineTransformIdentity;
        }];
    }

    _dismissTimer = [NSTimer scheduledTimerWithTimeInterval:3.5
                                                     target:self
                                                   selector:@selector(timerDismiss)
                                                   userInfo:nil
                                                    repeats:NO];
}

- (void)timerDismiss {
    [self dismissAnimated:YES];
}

- (void)dismissAnimated:(BOOL)animated {
    [_dismissTimer invalidate];
    _dismissTimer = nil;

    if (!animated) {
        _bannerWindow.hidden = YES;
        _bannerView.transform = CGAffineTransformIdentity;
        return;
    }

    CGFloat bannerH = _bannerView.bounds.size.height;
    [UIView animateWithDuration:0.25 animations:^{
        self->_bannerView.transform = CGAffineTransformMakeTranslation(0, -bannerH);
    } completion:^(BOOL finished) {
        if (finished) {
            self->_bannerWindow.hidden = YES;
            self->_bannerView.transform = CGAffineTransformIdentity;
        }
    }];
}

@end
