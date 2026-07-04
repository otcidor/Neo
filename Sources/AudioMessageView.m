#import "AudioMessageView.h"
#import "MatrixAPIClient.h"

@interface AudioMessageView ()
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UISlider *progressSlider;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UIImageView *micIcon;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, strong) NSTimer *progressTimer;
@property (nonatomic, readwrite, getter=isPlaying) BOOL playing;
@property (nonatomic, readwrite, getter=isDownloaded) BOOL downloaded;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation AudioMessageView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];

        self.micIcon = [[UIImageView alloc] initWithFrame:CGRectMake(6, 10, 28, 28)];
        self.micIcon.image = [UIImage imageNamed:@"filetype_icon_audio"];
        self.micIcon.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:self.micIcon];

        self.playButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.playButton.frame = CGRectMake(38, 8, 30, 30);
        [self.playButton setImage:[UIImage imageNamed:@"Play"] forState:UIControlStateNormal];
        [self.playButton setImage:[UIImage imageNamed:@"PlayPressed"] forState:UIControlStateHighlighted];
        [self.playButton addTarget:self action:@selector(playTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.playButton];

        self.progressSlider = [[UISlider alloc] initWithFrame:CGRectMake(74, 4, frame.size.width - 80, 20)];
        self.progressSlider.minimumValue = 0.0;
        self.progressSlider.maximumValue = 1.0;
        self.progressSlider.value = 0.0;
        self.progressSlider.continuous = YES;
        [self.progressSlider setThumbImage:[UIImage imageNamed:@"Scrubber"] forState:UIControlStateNormal];
        [self.progressSlider setMinimumTrackImage:[UIImage imageNamed:@"ScrubberTrackProgressInc"] forState:UIControlStateNormal];
        [self.progressSlider setMaximumTrackImage:[UIImage imageNamed:@"ScrubberBar"] forState:UIControlStateNormal];
        [self.progressSlider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
        [self.progressSlider addTarget:self action:@selector(sliderTouchUp:) forControlEvents:UIControlEventTouchUpInside];
        [self.progressSlider addTarget:self action:@selector(sliderTouchUp:) forControlEvents:UIControlEventTouchUpOutside];
        [self addSubview:self.progressSlider];

        self.timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(74, 24, frame.size.width - 80, 16)];
        self.timeLabel.font = [UIFont systemFontOfSize:11];
        self.timeLabel.textColor = [UIColor grayColor];
        self.timeLabel.backgroundColor = [UIColor clearColor];
        self.timeLabel.text = @"0:00";
        [self addSubview:self.timeLabel];

        self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        self.spinner.center = self.playButton.center;
        self.spinner.hidesWhenStopped = YES;
        [self addSubview:self.spinner];
    }
    return self;
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
        NSLog(@"AudioPlayer init error: %@", error);
        return;
    }
    self.audioPlayer.delegate = self;
    [self.audioPlayer prepareToPlay];
    self.progressSlider.maximumValue = self.audioPlayer.duration;
    [self.playButton setImage:[UIImage imageNamed:@"Play"] forState:UIControlStateNormal];
    [self updateTimeDisplay];
}

- (void)startDownload {
    if (self.downloaded || !self.mxcURL) return;

    [self.spinner startAnimating];
    self.playButton.hidden = YES;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        MatrixAPIClient *client = [MatrixAPIClient sharedClient];
        NSString *httpURLStr = [client mxcURLToHTTP:self.mxcURL];
        if (!httpURLStr) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.spinner stopAnimating];
                self.playButton.hidden = NO;
            });
            return;
        }

        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:httpURLStr]];
        if (client.accessToken) {
            [req setValue:[NSString stringWithFormat:@"Bearer %@", client.accessToken] forHTTPHeaderField:@"Authorization"];
        }
        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:&error];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            self.playButton.hidden = NO;
            if (data && !error) {
                self.audioData = data;
            }
        });
    });
}

- (void)playTapped {
    if (!self.downloaded) {
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
        if (!self.audioPlayer.playing) {
            self.audioPlayer.currentTime = self.progressSlider.value;
            [self.audioPlayer prepareToPlay];
        }
        [self.audioPlayer play];
        self.playing = YES;
        [self.playButton setImage:[UIImage imageNamed:@"Pause"] forState:UIControlStateNormal];
        self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateProgress) userInfo:nil repeats:YES];
    }
}

- (void)stop {
    [self.audioPlayer stop];
    self.playing = NO;
    self.audioPlayer.currentTime = 0;
    [self.progressTimer invalidate];
    self.progressTimer = nil;
    [self.playButton setImage:[UIImage imageNamed:@"Play"] forState:UIControlStateNormal];
    self.progressSlider.value = 0;
    [self updateTimeDisplay];
}

- (void)cleanup {
    [self stop];
    self.audioPlayer = nil;
    self.audioData = nil;
}

- (void)updateProgress {
    if (self.audioPlayer && self.audioPlayer.playing) {
        self.progressSlider.value = self.audioPlayer.currentTime;
        [self updateTimeDisplay];
    }
}

- (void)updateTimeDisplay {
    CGFloat current = self.progressSlider.value;
    CGFloat total = self.audioPlayer ? self.audioPlayer.duration : [self.duration floatValue] / 1000.0;
    if (total <= 0) total = 1;
    self.timeLabel.text = [NSString stringWithFormat:@"%d:%02d / %d:%02d",
                           (int)current / 60, (int)current % 60,
                           (int)total / 60, (int)total % 60];
}

- (void)sliderChanged:(UISlider *)slider {
    [self updateTimeDisplay];
}

- (void)sliderTouchUp:(UISlider *)slider {
    if (self.audioPlayer) {
        self.audioPlayer.currentTime = slider.value;
    }
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    self.playing = NO;
    [self.progressTimer invalidate];
    self.progressTimer = nil;
    [self.playButton setImage:[UIImage imageNamed:@"Play"] forState:UIControlStateNormal];
    self.progressSlider.value = 0;
    [self updateTimeDisplay];
}

@end
