#import <Foundation/Foundation.h>

extern NSString *const MatrixSyncNewMessageNotification;
extern NSString *const MatrixSyncUnreadUpdateNotification;

@class MatrixRoom;

@interface MatrixSyncManager : NSObject

@property (nonatomic, readonly, getter=isSyncing) BOOL syncing;
@property (nonatomic, readonly) NSInteger totalUnread;

+ (instancetype)sharedManager;

- (void)startSync;
- (void)stopSync;

- (NSInteger)unreadCountForRoom:(NSString *)roomId;

- (void)markRoomRead:(NSString *)roomId;
- (void)markRoomRead:(NSString *)roomId lastEventId:(NSString *)eventId;

- (void)resetUnread;

@end
