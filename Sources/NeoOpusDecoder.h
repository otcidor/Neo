#import <Foundation/Foundation.h>

@interface NeoOpusDecoder : NSObject
+ (NSData *)decodeOggOpusToWAV:(NSData *)oggData;
@end
