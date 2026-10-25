#import <UIKit/UIKit.h>

@interface NeoAudioWaveformView : UIView

@property (nonatomic, strong) NSArray *samples; // NSNumber floats [0.0 ... 1.0]
@property (nonatomic, assign) CGFloat progress; // [0.0 ... 1.0]
@property (nonatomic, strong) UIColor *unplayedColor;
@property (nonatomic, strong) UIColor *playedColor;
@property (nonatomic, copy) void (^seekHandler)(CGFloat progress);

- (void)setSamples:(NSArray *)samples animated:(BOOL)animated;
+ (NSArray *)extractSamplesFromAudioData:(NSData *)data count:(NSUInteger)count;

@end
