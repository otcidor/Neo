#import "ArchiveManager.h"

static NSString *const kArchivedRoomsKey = @"neo_archived_rooms";

@implementation ArchiveManager {
    NSMutableSet *_archivedIds;
}

+ (instancetype)sharedManager {
    static ArchiveManager *instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSArray *saved = [[NSUserDefaults standardUserDefaults]
            arrayForKey:kArchivedRoomsKey];
        _archivedIds = saved ? [NSMutableSet setWithArray:saved]
                             : [NSMutableSet set];
    }
    return self;
}

- (void)save {
    [[NSUserDefaults standardUserDefaults]
        setObject:[_archivedIds allObjects]
           forKey:kArchivedRoomsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)archiveRoomId:(NSString *)roomId {
    if (!roomId) return;
    [_archivedIds addObject:roomId];
    [self save];
}

- (void)unarchiveRoomId:(NSString *)roomId {
    if (!roomId) return;
    [_archivedIds removeObject:roomId];
    [self save];
}

- (BOOL)isArchivedRoomId:(NSString *)roomId {
    return [_archivedIds containsObject:roomId];
}

- (NSArray *)archivedRoomIds {
    return [_archivedIds allObjects];
}

@end
