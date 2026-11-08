#import "NeoTypingBubbleView.h"
#import "ThemeManager.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

#define NEO_TYPING_BUBBLE_WIDTH  52.0f
#define NEO_TYPING_BUBBLE_HEIGHT 30.0f
#define NEO_TYPING_DOT_COUNT     3
#define NEO_TYPING_DOT_RADIUS    3.0f
#define NEO_TYPING_DOT_STEP      10.0f
#define NEO_TYPING_DOT_RISE      3.5f
#define NEO_TYPING_BEAT_PERIOD   1.0
#define NEO_TYPING_BEAT_STAGGER  0.16
#define NEO_TYPING_BEAT_SAMPLES  24
#define NEO_TYPING_REST_ALPHA    0.45f

@interface NeoTypingBubbleView () {
    NSMutableArray *_dots;
    BOOL _isAnimating;
}
@end

@implementation NeoTypingBubbleView

+ (CGSize)bubbleSize {
    return CGSizeMake(NEO_TYPING_BUBBLE_WIDTH, NEO_TYPING_BUBBLE_HEIGHT);
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:CGRectMake(frame.origin.x, frame.origin.y, NEO_TYPING_BUBBLE_WIDTH, NEO_TYPING_BUBBLE_HEIGHT)];
    if (!self) return nil;
    
    self.userInteractionEnabled = NO;
    self.layer.cornerRadius = 14.0f;
    
    _dots = [[NSMutableArray alloc] initWithCapacity:NEO_TYPING_DOT_COUNT];
    
    CGFloat totalRowWidth = (NEO_TYPING_DOT_COUNT - 1) * NEO_TYPING_DOT_STEP + NEO_TYPING_DOT_RADIUS * 2.0f;
    CGFloat firstX = (NEO_TYPING_BUBBLE_WIDTH - totalRowWidth) / 2.0f + NEO_TYPING_DOT_RADIUS;
    
    for (int i = 0; i < NEO_TYPING_DOT_COUNT; i++) {
        CALayer *dot = [CALayer layer];
        dot.bounds = CGRectMake(0, 0, NEO_TYPING_DOT_RADIUS * 2.0f, NEO_TYPING_DOT_RADIUS * 2.0f);
        dot.position = CGPointMake(firstX + (CGFloat)i * NEO_TYPING_DOT_STEP, NEO_TYPING_BUBBLE_HEIGHT / 2.0f);
        dot.cornerRadius = NEO_TYPING_DOT_RADIUS;
        dot.opacity = NEO_TYPING_REST_ALPHA;
        
        // Suppress implicit animations on property changes
        dot.actions = [NSDictionary dictionaryWithObjectsAndKeys:
                       [NSNull null], @"position",
                       [NSNull null], @"bounds",
                       [NSNull null], @"opacity", nil];
        
        [self.layer addSublayer:dot];
        [_dots addObject:dot];
    }
    
    [self applyTheme];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:self.layer.cornerRadius].CGPath;
}

- (void)applyTheme {
    BOOL isDark = [ThemeManager sharedManager].isDarkMode;
    
    if (isDark) {
        self.backgroundColor = [UIColor colorWithRed:0.18f green:0.20f blue:0.24f alpha:1.0f];
        self.layer.borderColor = [UIColor colorWithWhite:1.0f alpha:0.12f].CGColor;
        self.layer.borderWidth = 0.5f;
        for (CALayer *dot in _dots) {
            dot.backgroundColor = [UIColor colorWithWhite:0.80f alpha:1.0f].CGColor;
        }
    } else {
        self.backgroundColor = [UIColor colorWithRed:0.92f green:0.92f blue:0.93f alpha:1.0f];
        self.layer.borderColor = [UIColor colorWithWhite:0.75f alpha:1.0f].CGColor;
        self.layer.borderWidth = 0.5f;
        for (CALayer *dot in _dots) {
            dot.backgroundColor = [UIColor colorWithWhite:0.42f alpha:1.0f].CGColor;
        }
    }
    
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.20f;
    self.layer.shadowRadius = 2.0f;
    self.layer.shadowOffset = CGSizeMake(0, 1.0f);
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:self.layer.cornerRadius].CGPath;
}

- (void)startAnimating {
    if (_isAnimating) return;
    _isAnimating = YES;
    
    NSMutableArray *lightValues = [NSMutableArray arrayWithCapacity:NEO_TYPING_BEAT_SAMPLES + 1];
    NSMutableArray *liftValues  = [NSMutableArray arrayWithCapacity:NEO_TYPING_BEAT_SAMPLES + 1];
    NSMutableArray *timeValues  = [NSMutableArray arrayWithCapacity:NEO_TYPING_BEAT_SAMPLES + 1];
    
    for (int k = 0; k <= NEO_TYPING_BEAT_SAMPLES; k++) {
        double phase = (double)k / NEO_TYPING_BEAT_SAMPLES;
        double wave = (1.0 - cos(2.0 * M_PI * phase)) / 2.0;
        
        [lightValues addObject:[NSNumber numberWithFloat:(float)(NEO_TYPING_REST_ALPHA + (1.0 - NEO_TYPING_REST_ALPHA) * wave)]];
        [liftValues addObject:[NSNumber numberWithFloat:(float)(-NEO_TYPING_DOT_RISE * wave)]];
        [timeValues addObject:[NSNumber numberWithFloat:(float)phase]];
    }
    
    CFTimeInterval baseTime = CACurrentMediaTime();
    
    for (NSUInteger i = 0; i < _dots.count; i++) {
        CALayer *dot = [_dots objectAtIndex:i];
        
        CAKeyframeAnimation *glow = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
        glow.values = lightValues;
        glow.keyTimes = timeValues;
        
        CAKeyframeAnimation *rise = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.y"];
        rise.values = liftValues;
        rise.keyTimes = timeValues;
        
        CAAnimationGroup *beat = [CAAnimationGroup animation];
        beat.animations = [NSArray arrayWithObjects:glow, rise, nil];
        beat.duration = NEO_TYPING_BEAT_PERIOD;
        beat.repeatCount = HUGE_VALF;
        beat.beginTime = baseTime + (double)i * NEO_TYPING_BEAT_STAGGER;
        beat.removedOnCompletion = NO;
        
        [dot addAnimation:beat forKey:@"neo.typing.beat"];
    }
}

- (void)stopAnimating {
    _isAnimating = NO;
    for (CALayer *dot in _dots) {
        [dot removeAnimationForKey:@"neo.typing.beat"];
        dot.opacity = NEO_TYPING_REST_ALPHA;
        dot.transform = CATransform3DIdentity;
    }
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window && _isAnimating) {
        // CoreAnimation drops layer animations when views detach; resume beat
        _isAnimating = NO;
        [self startAnimating];
    }
}

@end
