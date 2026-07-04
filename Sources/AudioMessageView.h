#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface AudioMessageView : UIView <AVAudioPlayerDelegate>

@property (nonatomic, strong) NSData *audioData;
@property (nonatomic, strong) NSNumber *duration; // from Matrix event info
@property (nonatomic, strong) NSString *mxcURL;   // for download
@property (nonatomic, readonly, getter=isPlaying) BOOL playing;
@property (nonatomic, readonly, getter=isDownloaded) BOOL downloaded;

- (void)startDownload;
- (void)stop;
- (void)cleanup;

@end
