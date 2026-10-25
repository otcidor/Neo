#import "NeoBackgroundKeeper.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

static NSString *const kBackgroundKeepAliveKey = @"neo_background_keepalive";

@interface NeoBackgroundKeeper ()
@property (nonatomic, strong) AVAudioPlayer *silentPlayer;
@property (nonatomic, readwrite) BOOL isRunning;
@end

@implementation NeoBackgroundKeeper

+ (instancetype)sharedKeeper {
    static NeoBackgroundKeeper *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isRunning = NO;
    }
    return self;
}

- (BOOL)isEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kBackgroundKeepAliveKey];
}

- (void)setIsEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kBackgroundKeepAliveKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    if (!enabled && self.isRunning) {
        [self stopKeepAlive];
    }
}

static NSData *NeoGenerateSilentWAVData(void) {
    // 1-second 8000 Hz, 16-bit Mono PCM (8000 samples * 2 bytes = 16000 bytes)
    const uint32_t sampleRate = 8000;
    const uint16_t channels = 1;
    const uint16_t bitsPerSample = 16;
    const uint32_t dataSize = sampleRate * channels * (bitsPerSample / 8);
    const uint32_t totalSize = 36 + dataSize;

    NSMutableData *data = [NSMutableData dataWithCapacity:44 + dataSize];

    // RIFF Header
    [data appendBytes:"RIFF" length:4];
    uint32_t chunkSize = CFSwapInt32HostToLittle(totalSize);
    [data appendBytes:&chunkSize length:4];
    [data appendBytes:"WAVE" length:4];

    // fmt chunk
    [data appendBytes:"fmt " length:4];
    uint32_t subchunk1Size = CFSwapInt32HostToLittle(16);
    [data appendBytes:&subchunk1Size length:4];
    uint16_t audioFormat = CFSwapInt16HostToLittle(1); // PCM
    [data appendBytes:&audioFormat length:2];
    uint16_t numChannels = CFSwapInt16HostToLittle(channels);
    [data appendBytes:&numChannels length:2];
    uint32_t sRate = CFSwapInt32HostToLittle(sampleRate);
    [data appendBytes:&sRate length:4];
    uint32_t byteRate = CFSwapInt32HostToLittle(sampleRate * channels * (bitsPerSample / 8));
    [data appendBytes:&byteRate length:4];
    uint16_t blockAlign = CFSwapInt16HostToLittle(channels * (bitsPerSample / 8));
    [data appendBytes:&blockAlign length:2];
    uint16_t bPerSample = CFSwapInt16HostToLittle(bitsPerSample);
    [data appendBytes:&bPerSample length:2];

    // data chunk
    [data appendBytes:"data" length:4];
    uint32_t sDataSize = CFSwapInt32HostToLittle(dataSize);
    [data appendBytes:&sDataSize length:4];

    // 16000 zeroed bytes for absolute silence
    void *silence = calloc(1, dataSize);
    if (silence) {
        [data appendBytes:silence length:dataSize];
        free(silence);
    }

    return data;
}

- (void)startKeepAlive {
    if (!self.isEnabled) return;
    if (self.isRunning) return;

    NSError *err = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];

    // Configure audio session to play silently without interrupting other apps (iOS 5 to 9 compatible)
    if ([session respondsToSelector:@selector(setCategory:withOptions:error:)]) {
        [session setCategory:AVAudioSessionCategoryPlayback
                 withOptions:AVAudioSessionCategoryOptionMixWithOthers
                       error:&err];
    } else {
        [session setCategory:AVAudioSessionCategoryPlayback error:&err];
        UInt32 mix = 1;
        AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryMixWithOthers, sizeof(mix), &mix);
    }
    [session setActive:YES error:nil];

    if (!self.silentPlayer) {
        NSData *silentWav = NeoGenerateSilentWAVData();
        self.silentPlayer = [[AVAudioPlayer alloc] initWithData:silentWav error:&err];
        self.silentPlayer.numberOfLoops = -1; // Infinite loop
        self.silentPlayer.volume = 0.0f;       // Completely silent
        [self.silentPlayer prepareToPlay];
    }

    BOOL started = [self.silentPlayer play];
    if (started) {
        self.isRunning = YES;
        NSLog(@"[NeoBackgroundKeeper] Silent keep-alive audio started successfully (24/7 background active)");
    } else {
        NSLog(@"[NeoBackgroundKeeper] Failed to start silent keep-alive audio: %@", err);
    }
}

- (void)stopKeepAlive {
    if (!self.isRunning && !self.silentPlayer) return;

    if (self.silentPlayer) {
        [self.silentPlayer stop];
        self.silentPlayer = nil;
    }
    self.isRunning = NO;

    AVAudioSession *session = [AVAudioSession sharedInstance];
    if ([session respondsToSelector:@selector(setActive:withOptions:error:)]) {
        [session setActive:NO
               withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                     error:nil];
    } else {
        [session setActive:NO error:nil];
    }

    NSLog(@"[NeoBackgroundKeeper] Silent keep-alive audio stopped");
}

@end
