#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface AudioMessageView : UIView <AVAudioPlayerDelegate>

@property (nonatomic, strong) NSData *audioData;
@property (nonatomic, strong) NSNumber *duration; // from Matrix event info
@property (nonatomic, strong) NSString *mxcURL;   // for download
@property (nonatomic, strong) NSArray *samples;
@property (nonatomic, readonly, getter=isPlaying) BOOL playing;
@property (nonatomic, readonly, getter=isDownloaded) BOOL downloaded;
@property (nonatomic, assign) BOOL isOutgoing;
@property (nonatomic, copy) void (^onAudioDataDecoded)(NSData *decodedData, NSArray *samples);
@property (nonatomic, copy) void (^playbackFinishedBlock)(void);

- (void)startDownload;
- (void)playTapped;
- (void)stop;
- (void)cleanup;

@end
