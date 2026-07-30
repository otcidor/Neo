#import "MatrixSyncManager.h"
#import "MatrixAPIClient.h"
#import "MatrixModels.h"

NSString *const MatrixSyncNewMessageNotification = @"MatrixSyncNewMessageNotification";
NSString *const MatrixSyncUnreadUpdateNotification = @"MatrixSyncUnreadUpdateNotification";

static NSString *const kUnreadCountsKey = @"neo_unread_counts";
static NSString *const kTotalUnreadKey = @"neo_total_unread";

static const NSTimeInterval kNotifCutoff = 16 * 3600; // 16 hours
static const NSInteger kMaxNotifPerRoom = 3;

@interface MatrixSyncManager ()
@property (nonatomic, readwrite, getter=isSyncing) BOOL syncing;
@property (nonatomic, strong) NSMutableDictionary *unreadCounts;
@property (nonatomic, strong) NSMutableDictionary *pendingNotifCounts;
@property (nonatomic, strong) NSMutableSet *processedEventIds;
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
        _processedEventIds = [NSMutableSet set];
        _pendingNotifCounts = [NSMutableDictionary dictionary];

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *savedCounts = [defaults dictionaryForKey:kUnreadCountsKey];
        if (savedCounts) {
            _unreadCounts = [NSMutableDictionary dictionaryWithDictionary:savedCounts];
        } else {
            _unreadCounts = [NSMutableDictionary dictionary];
        }
        _totalUnread = [defaults integerForKey:kTotalUnreadKey];
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
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

            for (NSDictionary *evt in events) {
                NSString *type = evt[@"type"];
                if (![type isEqualToString:@"m.room.message"]) continue;

                // Skip edits
                NSDictionary *relatesTo = evt[@"content"][@"m.relates_to"];
                if ([relatesTo[@"rel_type"] isEqualToString:@"m.replace"]) continue;

                // Skip own messages
                NSString *sender = evt[@"sender"];
                if ([sender isEqualToString:myId]) continue;

                // ---- 16h cutoff: skip messages older than 16 hours ----
                NSNumber *ts = evt[@"origin_server_ts"];
                if ([ts isKindOfClass:[NSNumber class]]) {
                    double eventTime = [ts doubleValue] / 1000.0;
                    if (now - eventTime > kNotifCutoff) continue;
                }

                // ---- Dedup: skip already-processed event_ids ----
                NSString *eventId = evt[@"event_id"];
                if ([eventId isKindOfClass:[NSString class]] && [eventId length] > 0) {
                    if ([self.processedEventIds containsObject:eventId]) continue;
                    [self.processedEventIds addObject:eventId];
                    if ([self.processedEventIds count] > 1000) {
                        [self.processedEventIds removeAllObjects];
                    }
                }

                NSNumber *count = self.unreadCounts[roomId] ?: @0;
                self.unreadCounts[roomId] = @([count intValue] + 1);
                self.totalUnread++;

                if (isBackground) {
        NSString *body = evt[@"content"][@"body"] ?: @"";
        NSString *roomName = [MatrixAPIClient localNameForRoomId:roomId];
        if (!roomName) roomName = [MatrixRoom displayNameForRoomId:roomId fromSyncData:roomData];

        // Cancel existing pending notification for this room (coalesce)
        NSNumber *existingCount = self.pendingNotifCounts[roomId];
        if (existingCount) {
            for (UILocalNotification *note in [[UIApplication sharedApplication] scheduledLocalNotifications]) {
                if ([[note.userInfo objectForKey:@"room_id"] isEqualToString:roomId]) {
                    [[UIApplication sharedApplication] cancelLocalNotification:note];
                    break;
                }
            }
        }

        int notifCount = [existingCount intValue] + 1;
        self.pendingNotifCounts[roomId] = @(notifCount);

        // Cap: stop scheduling new notifications at kMaxNotifPerRoom
        if (notifCount <= kMaxNotifPerRoom) {
            UILocalNotification *note = [[UILocalNotification alloc] init];
            note.fireDate = [NSDate dateWithTimeIntervalSinceNow:3.0];
            if (notifCount == 1) {
                note.alertBody = [NSString stringWithFormat:@"%@: %@", roomName ?: roomId, body];
            } else if (notifCount == kMaxNotifPerRoom) {
                note.alertBody = [NSString stringWithFormat:NSLocalizedString(@"%@ (%d+ new)", nil), roomName ?: roomId, notifCount];
            } else {
                note.alertBody = [NSString stringWithFormat:NSLocalizedString(@"%@ (%d new)", nil), roomName ?: roomId, notifCount];
            }
            note.soundName = UILocalNotificationDefaultSoundName;
            note.userInfo = @{@"room_id": roomId ?: @"", @"event_id": eventId ?: @""};
            note.applicationIconBadgeNumber = self.totalUnread;
            [[UIApplication sharedApplication] scheduleLocalNotification:note];
        }
                }

                NSDictionary *userInfo = @{@"room_id": roomId, @"event": evt};
                [[NSNotificationCenter defaultCenter] postNotificationName:MatrixSyncNewMessageNotification object:nil userInfo:userInfo];
            }

            // Persist unread counts
            [[NSUserDefaults standardUserDefaults] setObject:self.unreadCounts forKey:kUnreadCountsKey];
            [[NSUserDefaults standardUserDefaults] setInteger:self.totalUnread forKey:kTotalUnreadKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }];

        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:self.totalUnread];

        if (self.totalUnread == 0 && anyRoomFullyRead) {
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
        [self.pendingNotifCounts removeAllObjects];
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

        // Persist
        [[NSUserDefaults standardUserDefaults] setObject:self.unreadCounts forKey:kUnreadCountsKey];
        [[NSUserDefaults standardUserDefaults] setInteger:self.totalUnread forKey:kTotalUnreadKey];
        [[NSUserDefaults standardUserDefaults] synchronize];

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
        [self.pendingNotifCounts removeAllObjects];
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
    [self.pendingNotifCounts removeObjectForKey:roomId];
}

- (void)cancelAllPendingNotifications {
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    [self.pendingNotifCounts removeAllObjects];
}

- (void)resetUnread {
    [self.unreadCounts removeAllObjects];
    [self.pendingNotifCounts removeAllObjects];
    [self.processedEventIds removeAllObjects];
    self.totalUnread = 0;
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    [[UIApplication sharedApplication] cancelAllLocalNotifications];

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kUnreadCountsKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kTotalUnreadKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [[NSNotificationCenter defaultCenter] postNotificationName:MatrixSyncUnreadUpdateNotification object:nil userInfo:@{
        @"total": @0,
        @"counts": @{}
    }];
}

@end
