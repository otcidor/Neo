#import <Foundation/Foundation.h>

@class MatrixRoom;

@interface NeoSyncProcessor : NSObject

@property (nonatomic, readonly) NSMutableDictionary *pendingEdits;

- (BOOL)applyEvents:(NSArray *)events
           messages:(NSMutableArray *)messages
  messagesByEventId:(NSMutableDictionary *)messagesByEventId
               room:(MatrixRoom *)room
           myUserId:(NSString *)myUserId
      roomNameChanged:(void (^)(NSString *newName))roomNameChanged;

@end
