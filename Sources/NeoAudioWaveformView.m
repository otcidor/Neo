#import "NeoAudioWaveformView.h"

@interface NeoAudioWaveformContentView : UIView
@property (nonatomic, strong) NSArray *samples;
@property (nonatomic, strong) UIColor *color;
@end

@implementation NeoAudioWaveformContentView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.userInteractionEnabled = NO;
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)setSamples:(NSArray *)samples {
    _samples = samples;
    [self setNeedsDisplay];
}

- (void)setColor:(UIColor *)color {
    _color = color;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGFloat sampleWidth = 2.0f;
    CGFloat halfSampleWidth = 1.0f;
    CGFloat distance = 1.5f;

    CGSize size = self.bounds.size;
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) return;

    UIColor *drawColor = _color ?: [UIColor grayColor];
    CGContextSetFillColorWithColor(context, drawColor.CGColor);

    int numBars = (int)(size.width / (sampleWidth + distance));
    if (numBars <= 0) return;

    NSUInteger sampleCount = [_samples count];

    for (int i = 0; i < numBars; i++) {
        CGFloat offset = i * (sampleWidth + distance);
        CGFloat sampleNorm = 0.2f;

        if (sampleCount > 0) {
            NSUInteger sIdx = (NSUInteger)(i * sampleCount / numBars);
            if (sIdx < sampleCount) {
                sampleNorm = [_samples[sIdx] floatValue];
            }
        } else {
            // Default subtle resting wave pattern
            sampleNorm = 0.2f + 0.15f * sinf(i * 0.35f);
        }

        if (sampleNorm < 0.15f) sampleNorm = 0.15f;
        if (sampleNorm > 1.0f) sampleNorm = 1.0f;

        CGFloat barHeight = sampleNorm * (size.height - 2.0f);
        if (barHeight < sampleWidth) barHeight = sampleWidth;

        CGFloat y = (size.height - barHeight) / 2.0f;

        if (barHeight <= sampleWidth + 1.0f) {
            CGContextFillEllipseInRect(context, CGRectMake(offset, y, sampleWidth, sampleWidth));
        } else {
            CGRect barRect = CGRectMake(offset, y + halfSampleWidth, sampleWidth, barHeight - sampleWidth);
            CGContextFillRect(context, barRect);
            CGContextFillEllipseInRect(context, CGRectMake(offset, y, sampleWidth, sampleWidth));
            CGContextFillEllipseInRect(context, CGRectMake(offset, y + barHeight - sampleWidth, sampleWidth, sampleWidth));
        }
    }
}

@end

@interface NeoAudioWaveformView () {
    NeoAudioWaveformContentView *_bgContentView;
    UIView *_clippingView;
    NeoAudioWaveformContentView *_fgContentView;
    BOOL _isDragging;
}
@end

@implementation NeoAudioWaveformView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = YES;

        _unplayedColor = [UIColor colorWithWhite:0.65f alpha:1.0f];
        _playedColor = [UIColor colorWithRed:0.20f green:0.55f blue:0.95f alpha:1.0f];

        _bgContentView = [[NeoAudioWaveformContentView alloc] initWithFrame:self.bounds];
        _bgContentView.color = _unplayedColor;
        _bgContentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_bgContentView];

        _clippingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, self.bounds.size.height)];
        _clippingView.clipsToBounds = YES;
        _clippingView.backgroundColor = [UIColor clearColor];
        _clippingView.userInteractionEnabled = NO;

        _fgContentView = [[NeoAudioWaveformContentView alloc] initWithFrame:self.bounds];
        _fgContentView.color = _playedColor;
        _fgContentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [_clippingView addSubview:_fgContentView];

        [self addSubview:_clippingView];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        [self addGestureRecognizer:tap];

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _bgContentView.frame = self.bounds;
    _fgContentView.frame = self.bounds;
    [self updateClippingFrame];
}

- (void)setUnplayedColor:(UIColor *)unplayedColor {
    _unplayedColor = unplayedColor;
    _bgContentView.color = unplayedColor;
}

- (void)setPlayedColor:(UIColor *)playedColor {
    _playedColor = playedColor;
    _fgContentView.color = playedColor;
}

- (void)setSamples:(NSArray *)samples {
    [self setSamples:samples animated:NO];
}

- (void)setSamples:(NSArray *)samples animated:(BOOL)animated {
    _samples = [samples copy];
    _bgContentView.samples = _samples;
    _fgContentView.samples = _samples;
}

- (void)setProgress:(CGFloat)progress {
    CGFloat clamped = fminf(fmaxf(progress, 0.0f), 1.0f);
    if (fabsf(_progress - clamped) < 0.001f) return;
    _progress = clamped;
    [self updateClippingFrame];
}

- (void)updateClippingFrame {
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    _clippingView.frame = CGRectMake(0, 0, _progress * w, h);
}

#pragma mark - Gestures & Seeking

- (void)handleTap:(UITapGestureRecognizer *)tap {
    CGPoint loc = [tap locationInView:self];
    CGFloat w = self.bounds.size.width;
    if (w <= 0) return;
    CGFloat p = fminf(fmaxf(loc.x / w, 0.0f), 1.0f);
    self.progress = p;
    if (self.seekHandler) {
        self.seekHandler(p);
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint loc = [pan locationInView:self];
    CGFloat w = self.bounds.size.width;
    if (w <= 0) return;
    CGFloat p = fminf(fmaxf(loc.x / w, 0.0f), 1.0f);
    self.progress = p;
    if (self.seekHandler) {
        self.seekHandler(p);
    }
}

#pragma mark - Waveform Extraction

+ (NSArray *)extractSamplesFromAudioData:(NSData *)data count:(NSUInteger)count {
    if (count == 0) count = 40;
    if (!data || [data length] < 44) {
        NSMutableArray *def = [NSMutableArray arrayWithCapacity:count];
        for (NSUInteger i = 0; i < count; i++) {
            float val = 0.25f + 0.2f * sinf(i * 0.4f);
            [def addObject:@(val)];
        }
        return def;
    }

    const uint8_t *bytes = (const uint8_t *)[data bytes];
    NSUInteger length = [data length];

    // Check for RIFF WAV
    if (bytes[0] == 'R' && bytes[1] == 'I' && bytes[2] == 'F' && bytes[3] == 'F' &&
        bytes[8] == 'W' && bytes[9] == 'A' && bytes[10] == 'V' && bytes[11] == 'E') {
        // Read 16-bit linear PCM
        NSUInteger dataStart = 44;
        if (length > dataStart + 2) {
            const int16_t *pcm = (const int16_t *)(bytes + dataStart);
            NSUInteger numPcmSamples = (length - dataStart) / sizeof(int16_t);
            if (numPcmSamples > count) {
                NSMutableArray *peaks = [NSMutableArray arrayWithCapacity:count];
                NSUInteger bucketSize = numPcmSamples / count;
                int16_t maxOverall = 1;

                for (NSUInteger b = 0; b < count; b++) {
                    NSUInteger start = b * bucketSize;
                    NSUInteger end = (b == count - 1) ? numPcmSamples : start + bucketSize;
                    int16_t maxInBucket = 0;
                    for (NSUInteger s = start; s < end; s += 2) { // step by 2 for speed
                        int16_t v = abs(pcm[s]);
                        if (v > maxInBucket) maxInBucket = v;
                    }
                    if (maxInBucket > maxOverall) maxOverall = maxInBucket;
                    [peaks addObject:@(maxInBucket)];
                }

                NSMutableArray *normalized = [NSMutableArray arrayWithCapacity:count];
                float maxF = (float)maxOverall;
                if (maxF < 1.0f) maxF = 1.0f;
                for (NSNumber *num in peaks) {
                    float norm = [num floatValue] / maxF;
                    norm = fminf(fmaxf(norm, 0.15f), 1.0f);
                    [normalized addObject:@(norm)];
                }
                return normalized;
            }
        }
    }

    // Generic fallback for AAC/MP3/Opus: compute byte variation energy envelope
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
    NSUInteger chunkSize = length / count;
    if (chunkSize == 0) chunkSize = 1;

    float maxEnergy = 1.0f;
    NSMutableArray *rawEnergies = [NSMutableArray arrayWithCapacity:count];

    for (NSUInteger b = 0; b < count; b++) {
        NSUInteger start = b * chunkSize;
        NSUInteger end = (b == count - 1) ? length : start + chunkSize;
        uint32_t diffSum = 0;
        for (NSUInteger s = start + 1; s < end; s += 4) {
            int diff = abs((int)bytes[s] - (int)bytes[s - 1]);
            diffSum += diff;
        }
        float energy = (float)diffSum / (float)(MAX(1, (end - start) / 4));
        if (energy > maxEnergy) maxEnergy = energy;
        [rawEnergies addObject:@(energy)];
    }

    for (NSNumber *e in rawEnergies) {
        float norm = [e floatValue] / maxEnergy;
        norm = fminf(fmaxf(norm, 0.18f), 1.0f);
        [result addObject:@(norm)];
    }
    return result;
}

@end
