#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NSString *NeoReactionKey(NSString *emoji);
NSArray *NeoReactionItems(NSString *summary);
UIImage *NeoReactionPillImage(NSString *emoji, NSInteger count, BOOL selected);
