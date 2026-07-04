#import <Foundation/Foundation.h>
#import "MatrixModels.h"

@interface SpaceManager : NSObject

@property (nonatomic, strong) NSMutableDictionary *roomSpaceMap;
@property (nonatomic, strong) NSArray *spaces;
@property (nonatomic, assign) BOOL hasData;

+ (instancetype)sharedManager;

- (void)buildSpaceMapFromSyncResponse:(NSDictionary *)syncResponse;

- (SpaceTheme)themeForRoomId:(NSString *)roomId;

- (NSArray *)roomsForSpaceId:(NSString *)spaceId fromAllRooms:(NSArray *)allRooms;

- (NSArray *)roomIdsForSpaceNameFilter:(NSString *)nameFilter;

- (NSString *)bridgeTypeForRoomId:(NSString *)roomId;
- (void)setMembers:(NSArray *)memberEvents forRoomId:(NSString *)roomId;

@end
