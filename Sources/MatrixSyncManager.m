#import "MatrixSyncManager.h"
#import "MatrixAPIClient.h"
#import "MatrixModels.h"

NSString *const MatrixSyncNewMessageNotification = @"MatrixSyncNewMessageNotification";
NSString *const MatrixSyncUnreadUpdateNotification = @"MatrixSyncUnreadUpdateNotification";

@interface MatrixSyncManager ()
@property (nonatomic, readwrite, getter=isSyncing) BOOL syncing;
@property (nonatomic, strong) NSMutableDictionary *unreadCounts;
@property (nonatomic, readwrite) NSInteger totalUnread;
@end

@implementation MatrixSyncManager

+ (instancetype)sharedManager {
    static MatrixSyncManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (id)init {
    self = [super init];
    if (self) {
        _unreadCounts = [NSMutableDictionary dictionary];
        _totalUnread = 0;
    }
    return self;
}

- (void)startSync {
    if (self.syncing) return;
    self.syncing = YES;
    [self performSync];
}

- (void)stopSync {
    self.syncing = NO;
}

- (void)performSync {
    if (!self.syncing) return;

    MatrixAPIClient *client = [MatrixAPIClient sharedClient];
    if (!client.accessToken) {
        [self stopSync];
        return;
    }

    [client syncWithSince:client.nextBatchToken timeout:30000 completion:^(NSDictionary *response, NSError *error) {
        if (!self.syncing) return;

        if (error) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self performSync];
            });
            return;
        }

        NSString *nextBatch = response[@"next_batch"];
        if (nextBatch) client.nextBatchToken = nextBatch;

        UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
        BOOL isBackground = (appState == UIApplicationStateBackground);
        NSString *myId = client.userId;

        NSDictionary *join = response[@"rooms"][@"join"];
        __block BOOL anyRoomFullyRead = NO;

        [join enumerateKeysAndObjectsUsingBlock:^(NSString *roomId, NSDictionary *roomData, BOOL *stop) {

            // ---- Process read receipts (m.receipt) from ephemeral ----
            NSArray *ephemeralEvents = roomData[@"ephemeral"][@"events"];
            for (NSDictionary *ephEvt in ephemeralEvents) {
                if (![ephEvt[@"type"] isEqualToString:@"m.receipt"]) continue;
                NSDictionary *receiptContent = ephEvt[@"content"];
                for (NSString *eventId in receiptContent) {
                    NSDictionary *readDict = receiptContent[eventId][@"m.read"];
                    if (readDict[myId]) {
                        NSNumber *prevCount = self.unreadCounts[roomId];
                        if (prevCount && [prevCount intValue] > 0) {
                            self.totalUnread -= [prevCount intValue];
                            if (self.totalUnread < 0) self.totalUnread = 0;
                        }
                        [self.unreadCounts removeObjectForKey:roomId];
                        [self cancelNotificationsForRoom:roomId];
                        anyRoomFullyRead = YES;
                    }
                }
            }

            // ---- Process new messages ----
            NSArray *events = roomData[@"timeline"][@"events"];
            for (NSDictionary *evt in events) {
                NSString *type = evt[@"type"];
                if (![type isEqualToString:@"m.room.message"]) continue;

                NSDictionary *relatesTo = evt[@"content"][@"m.relates_to"];
                if ([relatesTo[@"rel_type"] isEqualToString:@"m.replace"]) continue;

                NSString *sender = evt[@"sender"];
                if ([sender isEqualToString:myId]) continue;

                NSNumber *count = self.unreadCounts[roomId] ?: @0;
                self.unreadCounts[roomId] = @([count intValue] + 1);
                self.totalUnread++;

                if (isBackground) {
                    NSString *body = evt[@"content"][@"body"] ?: @"";
                    NSString *roomName = [MatrixAPIClient localNameForRoomId:roomId];
                    if (!roomName) roomName = [MatrixRoom displayNameForRoomId:roomId fromSyncData:roomData];

                    UILocalNotification *note = [[UILocalNotification alloc] init];
                    note.fireDate = [NSDate dateWithTimeIntervalSinceNow:0];
                    note.alertBody = [NSString stringWithFormat:@"%@: %@", roomName ?: roomId, body];
                    note.soundName = UILocalNotificationDefaultSoundName;
                    note.userInfo = @{@"room_id": roomId ?: @"", @"event_id": evt[@"event_id"] ?: @""};
                    note.applicationIconBadgeNumber = self.totalUnread;
                    [[UIApplication sharedApplication] presentLocalNotificationNow:note];
                }

                NSDictionary *userInfo = @{@"room_id": roomId, @"event": evt};
                [[NSNotificationCenter defaultCenter] postNotificationName:MatrixSyncNewMessageNotification object:nil userInfo:userInfo];
            }
        }];

        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:self.totalUnread];

        if (self.totalUnread == 0 && anyRoomFullyRead) {
            [[UIApplication sharedApplication] cancelAllLocalNotifications];
        }

        [[NSNotificationCenter defaultCenter] postNotificationName:MatrixSyncUnreadUpdateNotification object:nil userInfo:@{
            @"total": @(self.totalUnread),
            @"counts": [self.unreadCounts copy]
        }];

        [self performSync];
    }];
}

- (NSString *)displayNameForUserId:(NSString *)userId inRoom:(NSString *)roomId fromSyncData:(NSDictionary *)roomData {
    NSArray *stateEvents = roomData[@"state"][@"events"];
    for (NSDictionary *evt in stateEvents) {
        if ([evt[@"type"] isEqualToString:@"m.room.member"] && [evt[@"state_key"] isEqualToString:userId]) {
            NSString *displayName = evt[@"content"][@"displayname"];
            if ([displayName length] > 0) return displayName;
        }
    }
    NSDictionary *members = [[MatrixAPIClient sharedClient] cachedMembersForRoom:roomId];
    NSString *cachedName = members[userId][@"displayname"];
    if ([cachedName length] > 0) return cachedName;
    if ([userId length] > 0) {
        NSRange colonRange = [userId rangeOfString:@":"];
        if (colonRange.location != NSNotFound) {
            return [userId substringToIndex:colonRange.location];
        }
    }
    return userId;
}

- (NSInteger)unreadCountForRoom:(NSString *)roomId {
    return [self.unreadCounts[roomId] intValue];
}

- (void)markRoomRead:(NSString *)roomId {
    [self markRoomRead:roomId lastEventId:nil];
}

- (void)markRoomRead:(NSString *)roomId lastEventId:(NSString *)eventId {
    NSNumber *count = self.unreadCounts[roomId];
    if (count) {
        self.totalUnread -= [count intValue];
        if (self.totalUnread < 0) self.totalUnread = 0;
        [self.unreadCounts removeObjectForKey:roomId];
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:self.totalUnread];
        [[NSNotificationCenter defaultCenter] postNotificationName:MatrixSyncUnreadUpdateNotification object:nil userInfo:@{
            @"total": @(self.totalUnread),
            @"counts": [self.unreadCounts copy]
        }];
    }

    if (eventId) {
        [[MatrixAPIClient sharedClient] sendReadReceipt:roomId
                                                 eventId:eventId
                                              completion:nil];
    }

    [self cancelNotificationsForRoom:roomId];

    if (self.totalUnread == 0) {
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
    }
}

- (void)cancelNotificationsForRoom:(NSString *)roomId {
    NSArray *scheduled = [[UIApplication sharedApplication] scheduledLocalNotifications];
    for (UILocalNotification *note in scheduled) {
        NSString *noteRoom = [note.userInfo objectForKey:@"room_id"];
        if ([noteRoom isEqualToString:roomId]) {
            [[UIApplication sharedApplication] cancelLocalNotification:note];
        }
    }
}

- (void)resetUnread {
    [self.unreadCounts removeAllObjects];
    self.totalUnread = 0;
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    [[NSNotificationCenter defaultCenter] postNotificationName:MatrixSyncUnreadUpdateNotification object:nil userInfo:@{
        @"total": @0,
        @"counts": @{}
    }];
}

@end
