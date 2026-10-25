#import "NeoDatabase.h"
#import "FMDatabase.h"
#import "MatrixModels.h"

@interface NeoDatabase () {
    FMDatabase *_db;
    dispatch_queue_t _dbQueue;
}
@end

@implementation NeoDatabase

+ (instancetype)sharedDatabase {
    static NeoDatabase *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NeoDatabase alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _dbQueue = dispatch_queue_create("win.otcidor.neo.database", DISPATCH_QUEUE_SERIAL);
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *dbPath = [paths[0] stringByAppendingPathComponent:@"neo_storage.sqlite3"];

        _db = [FMDatabase databaseWithPath:dbPath];
        if ([_db open]) {
            [_db executeUpdate:@"PRAGMA synchronous = NORMAL;"];
            [_db executeUpdate:@"CREATE TABLE IF NOT EXISTS messages ("
                               "event_id TEXT PRIMARY KEY, "
                               "room_id TEXT, "
                               "sender TEXT, "
                               "body TEXT, "
                               "msg_type TEXT, "
                               "timestamp REAL, "
                               "raw_json TEXT);"];
            [_db executeUpdate:@"CREATE INDEX IF NOT EXISTS idx_messages_room_ts ON messages(room_id, timestamp);"];
        } else {
            NSLog(@"[NeoDatabase] Failed to open SQLite database at %@", dbPath);
        }
    }
    return self;
}

- (void)saveMessage:(MatrixMessage *)message rawDict:(NSDictionary *)rawDict inRoom:(NSString *)roomId {
    if (!message || !message.eventId || !roomId) return;
    dispatch_async(_dbQueue, ^{
        NSString *rawJson = @"";
        if (rawDict) {
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:rawDict options:0 error:nil];
            if (jsonData) {
                rawJson = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            }
        }
        double ts = [message.timestamp timeIntervalSince1970];
        [self->_db executeUpdate:@"INSERT OR REPLACE INTO messages (event_id, room_id, sender, body, msg_type, timestamp, raw_json) VALUES (?, ?, ?, ?, ?, ?, ?)",
                                 message.eventId,
                                 roomId,
                                 message.sender ?: @"",
                                 message.body ?: @"",
                                 message.msgType ?: @"m.text",
                                 @(ts),
                                 rawJson ?: @""];
    });
}

- (void)saveMessagesBatch:(NSArray *)eventDicts inRoom:(NSString *)roomId {
    if ([eventDicts count] == 0 || !roomId) return;
    dispatch_async(_dbQueue, ^{
        [self->_db beginTransaction];
        for (NSDictionary *dict in eventDicts) {
            if (![dict isKindOfClass:[NSDictionary class]]) continue;
            NSString *eventId = dict[@"event_id"];
            if (!eventId) continue;
            NSString *sender = dict[@"sender"] ?: @"";
            NSDictionary *content = dict[@"content"];
            NSString *body = @"";
            NSString *msgType = @"m.text";
            if ([content isKindOfClass:[NSDictionary class]]) {
                body = content[@"body"] ?: @"";
                msgType = content[@"msgtype"] ?: @"m.text";
            }
            double ts = [dict[@"origin_server_ts"] doubleValue] / 1000.0;
            if (ts <= 0) ts = [[NSDate date] timeIntervalSince1970];

            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
            NSString *rawJson = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"";

            [self->_db executeUpdate:@"INSERT OR REPLACE INTO messages (event_id, room_id, sender, body, msg_type, timestamp, raw_json) VALUES (?, ?, ?, ?, ?, ?, ?)",
                                     eventId,
                                     roomId,
                                     sender,
                                     body,
                                     msgType,
                                     @(ts),
                                     rawJson ?: @""];
        }
        [self->_db commit];
    });
}

- (NSArray *)loadMessagesForRoom:(NSString *)roomId limit:(NSInteger)limit {
    if (!roomId) return @[];
    __block NSMutableArray *result = [NSMutableArray array];
    dispatch_sync(_dbQueue, ^{
        NSInteger maxLimit = (limit > 0) ? limit : 50;
        FMResultSet *rs = [self->_db executeQuery:@"SELECT raw_json FROM messages WHERE room_id = ? ORDER BY timestamp DESC LIMIT ?", roomId, @(maxLimit)];
        NSMutableArray *batch = [NSMutableArray array];
        while ([rs next]) {
            NSString *jsonStr = [rs stringForColumn:@"raw_json"];
            if ([jsonStr length] > 0) {
                NSData *data = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
                if (data) {
                    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    if ([dict isKindOfClass:[NSDictionary class]]) {
                        MatrixMessage *msg = [[MatrixMessage alloc] initWithDictionary:dict roomId:roomId];
                        if (msg) {
                            [batch addObject:msg];
                        }
                    }
                }
            }
        }
        [rs close];
        for (NSInteger i = (NSInteger)[batch count] - 1; i >= 0; i--) {
            [result addObject:batch[i]];
        }
    });
    return result;
}

- (void)deleteMessagesForRoom:(NSString *)roomId {
    if (!roomId) return;
    dispatch_async(_dbQueue, ^{
        [self->_db executeUpdate:@"DELETE FROM messages WHERE room_id = ?", roomId];
    });
}

- (void)clearAll {
    dispatch_async(_dbQueue, ^{
        [self->_db executeUpdate:@"DELETE FROM messages"];
    });
}

@end
