#import <Foundation/Foundation.h>

@interface ArchiveManager : NSObject

+ (instancetype)sharedManager;

- (void)archiveRoomId:(NSString *)roomId;
- (void)unarchiveRoomId:(NSString *)roomId;
- (BOOL)isArchivedRoomId:(NSString *)roomId;
- (NSArray *)archivedRoomIds;

@end
