#import "AudioMessageView.h"
#import "MatrixAPIClient.h"
#import "NeoOpusDecoder.h"
#import "NeoAudioWaveformView.h"
#import "ThemeManager.h"
#import <AudioToolbox/AudioServices.h>

@interface AudioMessageView ()
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) NeoAudioWaveformView *waveformView;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, strong) NSTimer *progressTimer;
@property (nonatomic, readwrite, getter=isPlaying) BOOL playing;
@property (nonatomic, readwrite, getter=isDownloaded) BOOL downloaded;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) BOOL autoPlayOnDownload;
@end

@implementation AudioMessageView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];

        self.playButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.playButton.frame = CGRectMake(4, 9, 32, 32);
        [self.playButton setImage:[UIImage imageNamed:@"Play"] forState:UIControlStateNormal];
        [self.playButton setImage:[UIImage imageNamed:@"PlayPressed"] forState:UIControlStateHighlighted];
        [self.playButton addTarget:self action:@selector(playTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.playButton];

        CGFloat waveX = 42;
        CGFloat waveW = frame.size.width - waveX - 8;
        if (waveW < 60) waveW = 140;

        self.waveformView = [[NeoAudioWaveformView alloc] initWithFrame:CGRectMake(waveX, 6, waveW, 24)];
        __weak typeof(self) weakSelf = self;
        self.waveformView.seekHandler = ^(CGFloat p) {
            [weakSelf seekToProgress:p];
        };
        [self addSubview:self.waveformView];

        self.timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(waveX, 31, waveW, 14)];
        self.timeLabel.font = [UIFont systemFontOfSize:11];
        self.timeLabel.backgroundColor = [UIColor clearColor];
        self.timeLabel.text = @"0:00";
        [self addSubview:self.timeLabel];

        self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        self.spinner.center = self.playButton.center;
        self.spinner.hidesWhenStopped = YES;
        [self addSubview:self.spinner];

        [self updateColors];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleOtherAudioDidStart:)
                                                     name:@"NeoAudioPlaybackDidStartNotification"
                                                   object:nil];
    }
    return self;
}

- (void)handleOtherAudioDidStart:(NSNotification *)note {
    if (note.object != self && self.playing) {
        [self stop];
    }
}

- (void)setIsOutgoing:(BOOL)isOutgoing {
    _isOutgoing = isOutgoing;
    [self updateColors];
}

- (void)updateColors {
    if (self.isOutgoing) {
        self.waveformView.unplayedColor = [UIColor colorWithWhite:1.0f alpha:0.40f];
        self.waveformView.playedColor = [UIColor whiteColor];
        self.timeLabel.textColor = [UIColor colorWithWhite:1.0f alpha:0.85f];
    } else {
        ThemeManager *tm = [ThemeManager sharedManager];
        UIColor *accent = [tm tintColor] ?: [UIColor colorWithRed:0.20f green:0.55f blue:0.95f alpha:1.0f];
        self.waveformView.unplayedColor = [UIColor colorWithWhite:0.75f alpha:1.0f];
        self.waveformView.playedColor = accent;
        self.timeLabel.textColor = [UIColor colorWithWhite:0.55f alpha:1.0f];
    }
}

- (void)setSamples:(NSArray *)samples {
    _samples = samples;
    self.waveformView.samples = samples;
}

- (void)setAudioData:(NSData *)audioData {
    _audioData = audioData;
    self.downloaded = YES;
    [self setupPlayer];
}

- (void)setupPlayer {
    if (!self.audioData) return;
    NSError *error = nil;
    self.audioPlayer = [[AVAudioPlayer alloc] initWithData:self.audioData error:&error];
    if (error) {
        NSData *wavData = [NeoOpusDecoder decodeOggOpusToWAV:self.audioData];
        if (wavData) {
            _audioData = wavData;
            self.audioPlayer = [[AVAudioPlayer alloc] initWithData:self.audioData error:&error];
            if (error) {
                return;
            }
        } else {
            return;
        }
    }

    if (!self.samples || [self.samples count] == 0) {
        NSArray *extracted = [NeoAudioWaveformView extractSamplesFromAudioData:self.audioData count:40];
        self.samples = extracted;
        self.waveformView.samples = self.samples;
        if (self.onAudioDataDecoded) {
            self.onAudioDataDecoded(self.audioData, self.samples);
        }
    } else {
        self.waveformView.samples = self.samples;
    }

    self.audioPlayer.delegate = self;
    [self.audioPlayer prepareToPlay];
    [self.playButton setImage:[UIImage imageNamed:@"Play"] forState:UIControlStateNormal];
    [self updateTimeDisplay];
}

- (void)startDownload {
    if (self.downloaded || !self.mxcURL) return;

    [self.spinner startAnimating];
    self.playButton.hidden = YES;

    __weak typeof(self) weakSelf = self;
    [[MatrixAPIClient sharedClient] downloadDataFromMXC:self.mxcURL completion:^(NSData *data, NSString *mimeType, NSError *error) {
        typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf.spinner stopAnimating];
        strongSelf.playButton.hidden = NO;
        if (data && !error) {
            strongSelf.audioData = data;
            if (strongSelf.autoPlayOnDownload) {
                strongSelf.autoPlayOnDownload = NO;
                [strongSelf playTapped];
            }
        }
    }];
}

- (void)proximityChanged {
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    if ([UIDevice currentDevice].proximityState) {
        UInt32 route = kAudioSessionOverrideAudioRoute_None;
        AudioSessionSetProperty(kAudioSessionProperty_OverrideAudioRoute,
                                sizeof(route), &route);
    } else {
        UInt32 route = kAudioSessionOverrideAudioRoute_Speaker;
        AudioSessionSetProperty(kAudioSessionProperty_OverrideAudioRoute,
                                sizeof(route), &route);
    }
}

- (void)playTapped {
    if (!self.downloaded) {
        self.autoPlayOnDownload = YES;
        [self startDownload];
        return;
    }
    if (!self.audioPlayer) {
        [self setupPlayer];
        if (!self.audioPlayer) return;
    }

    if (self.playing) {
        [self.audioPlayer pause];
        self.playing = NO;
        [self.playButton setImage:[UIImage imageNamed:@"Play"] forState:UIControlStateNormal];
        [self.progressTimer invalidate];
        self.progressTimer = nil;
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"NeoAudioPlaybackDidStartNotification" object:self];

        if (!self.audioPlayer.playing) {
            self.audioPlayer.currentTime = self.waveformView.progress * self.audioPlayer.duration;
            [self.audioPlayer prepareToPlay];
        }

        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
        [session setActive:YES error:nil];

        UInt32 route = kAudioSessionOverrideAudioRoute_Speaker;
        AudioSessionSetProperty(kAudioSessionProperty_OverrideAudioRoute,
                                sizeof(route), &route);

        [UIDevice currentDevice].proximityMonitoringEnabled = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(proximityChanged)
                                                     name:UIDeviceProximityStateDidChangeNotification
                                                   object:nil];

        [self.audioPlayer play];
        self.playing = YES;
        [self.playButton setImage:[UIImage imageNamed:@"Pause"] forState:UIControlStateNormal];
        self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(updateProgress) userInfo:nil repeats:YES];
    }
}

- (void)stop {
    [self.audioPlayer stop];
    self.playing = NO;
    if (self.audioPlayer) self.audioPlayer.currentTime = 0;
    [self.progressTimer invalidate];
    self.progressTimer = nil;
    [self.playButton setImage:[UIImage imageNamed:@"Play"] forState:UIControlStateNormal];
    self.waveformView.progress = 0;
    [self updateTimeDisplay];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDeviceProximityStateDidChangeNotification
                                                  object:nil];
    [UIDevice currentDevice].proximityMonitoringEnabled = NO;
}

- (void)seekToProgress:(CGFloat)p {
    if (self.audioPlayer) {
        self.audioPlayer.currentTime = p * self.audioPlayer.duration;
        [self updateTimeDisplay];
    }
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
    [super willMoveToWindow:newWindow];
    if (!newWindow && self.playing) {
        [self stop];
    }
}

- (void)cleanup {
    [self stop];
    self.audioPlayer.delegate = nil;
    self.audioPlayer = nil;
    self.audioData = nil;
}

- (void)dealloc {
    [self cleanup];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateProgress {
    if (self.audioPlayer && self.audioPlayer.playing) {
        CGFloat total = self.audioPlayer.duration;
        CGFloat current = self.audioPlayer.currentTime;
        self.waveformView.progress = (total > 0) ? (current / total) : 0.0f;
        [self updateTimeDisplay];
    }
}

- (void)updateTimeDisplay {
    CGFloat total = self.audioPlayer ? self.audioPlayer.duration : [self.duration floatValue] / 1000.0;
    if (total <= 0) total = 1;
    CGFloat current = self.audioPlayer ? self.audioPlayer.currentTime : (self.waveformView.progress * total);
    self.timeLabel.text = [NSString stringWithFormat:@"%d:%02d / %d:%02d",
                           (int)current / 60, (int)current % 60,
                           (int)total / 60, (int)total % 60];
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    [self stop];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"NeoAudioPlaybackDidFinishNotification"
                                                        object:self
                                                      userInfo:@{@"mxcURL": self.mxcURL ?: @""}];

    if (self.playbackFinishedBlock) {
        self.playbackFinishedBlock();
    }
}

@end
