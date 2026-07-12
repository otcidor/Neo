#import "MatrixModels.h"

@implementation MatrixRoom
- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self) {
        _roomId = dict[@"room_id"] ?: @"";
        _name = _roomId;
        _memberCount = 0;
        _theme = SpaceThemeDefault;
    }
    return self;
}

- (void)updateNameFromStateEvents:(NSArray *)stateEvents timelineEvents:(NSArray *)timelineEvents {
    for (NSDictionary *evt in stateEvents) {
        NSString *type = evt[@"type"];
        NSDictionary *content = evt[@"content"];
        if (![content isKindOfClass:[NSDictionary class]]) continue;

        if ([type isEqualToString:@"m.room.name"]) {
            NSString *roomName = content[@"name"];
            if ([roomName length] > 0) {
                self.name = roomName;
                return;
            }
        }
        if ([type isEqualToString:@"m.room.canonical_alias"]) {
            NSString *alias = content[@"alias"];
            if ([alias length] > 0) {
                self.name = alias;
            }
        }
    }
    for (NSDictionary *evt in timelineEvents) {
        NSString *type = evt[@"type"];
        NSDictionary *content = evt[@"content"];
        if (![content isKindOfClass:[NSDictionary class]]) continue;
        if ([type isEqualToString:@"m.room.name"]) {
            NSString *roomName = content[@"name"];
            if ([roomName length] > 0) {
                self.name = roomName;
                return;
            }
        }
        if ([type isEqualToString:@"m.room.canonical_alias"]) {
            NSString *alias = content[@"alias"];
            if ([alias length] > 0) {
                self.name = alias;
            }
        }
    }
}

+ (NSString *)displayNameForRoomId:(NSString *)roomId fromSyncData:(NSDictionary *)roomData {
    NSArray *stateEvents = roomData[@"state"][@"events"];
    for (NSDictionary *evt in stateEvents) {
        NSString *type = evt[@"type"];
        NSDictionary *content = evt[@"content"];
        if (![content isKindOfClass:[NSDictionary class]]) continue;
        if ([type isEqualToString:@"m.room.name"]) {
            NSString *name = content[@"name"];
            if ([name length] > 0) return name;
        }
    }
    for (NSDictionary *evt in stateEvents) {
        NSString *type = evt[@"type"];
        NSDictionary *content = evt[@"content"];
        if (![content isKindOfClass:[NSDictionary class]]) continue;
        if ([type isEqualToString:@"m.room.canonical_alias"]) {
            NSString *alias = content[@"alias"];
            if ([alias length] > 0) return alias;
        }
    }
    NSArray *timelineEvents = roomData[@"timeline"][@"events"];
    for (NSDictionary *evt in timelineEvents) {
        NSString *type = evt[@"type"];
        if ([type isEqualToString:@"m.room.name"]) {
            NSDictionary *content = evt[@"content"];
            NSString *name = content[@"name"];
            if ([name length] > 0) return name;
        }
        if ([type isEqualToString:@"m.room.canonical_alias"]) {
            NSDictionary *content = evt[@"content"];
            NSString *alias = content[@"alias"];
            if ([alias length] > 0) return alias;
        }
    }
    NSDictionary *summary = roomData[@"summary"];
    NSArray *heroes = summary[@"m.heroes"];
    if ([heroes count] > 0) {
        NSInteger count = [summary[@"m.joined_member_count"] integerValue] ?: [summary[@"joined_member_count"] integerValue];
        if (count <= 2) {
            return [heroes componentsJoinedByString:@", "];
        }
    }
    NSString *roomIdSuffix = roomId;
    NSRange colonRange = [roomId rangeOfString:@":"];
    if (colonRange.location != NSNotFound) {
        roomIdSuffix = [roomId substringFromIndex:colonRange.location + 1];
    }
    return roomIdSuffix;
}
@end

@implementation MatrixMessage
- (instancetype)initWithDictionary:(NSDictionary *)dict roomId:(NSString *)roomId {
    self = [super init];
    if (self) {
        _eventId = dict[@"event_id"] ?: @"";
        _sender = dict[@"sender"] ?: @"";
        _roomId = roomId ?: @"";
        NSDictionary *content = dict[@"content"];
        if ([content isKindOfClass:[NSDictionary class]]) {
            _body = content[@"body"] ?: @"";
            _msgType = content[@"msgtype"] ?: @"m.text";
            _imageURL = content[@"url"] ?: @"";
            _audioURL = content[@"url"] ?: @"";
            _videoURL = content[@"url"] ?: @"";
            NSDictionary *info = content[@"info"];
            if ([info isKindOfClass:[NSDictionary class]]) {
                _imageWidth = [info[@"w"] floatValue] ?: 320;
                _imageHeight = [info[@"h"] floatValue] ?: 240;
                _videoWidth = [info[@"w"] floatValue] ?: 320;
                _videoHeight = [info[@"h"] floatValue] ?: 240;
                if (info[@"duration"]) {
                    _audioDuration = info[@"duration"];
                    _videoDuration = info[@"duration"];
                }
                _videoThumbnailURL = info[@"thumbnail_url"] ?: @"";
            } else {
                _imageWidth = 320;
                _imageHeight = 240;
                _videoWidth = 320;
                _videoHeight = 240;
            }
        } else {
            _body = @"";
            _msgType = @"m.text";
            _imageURL = @"";
        }
        // Redacted
        if (dict[@"unsigned"][@"redacted_because"]) {
            self.isRedacted = YES;
            self.body = NSLocalizedString(@"Deleted message", nil);
            self.msgType = @"m.text";
        }

        // Edit — if m.new_content exists, use that body
        NSDictionary *relatesto = content[@"m.relates_to"];
        if (relatesto && [relatesto[@"rel_type"] isEqualToString:@"m.replace"]) {
            self.isEdit = YES;
            self.relatedEventId = relatesto[@"event_id"];
            NSDictionary *newContent = content[@"m.new_content"];
            if (newContent[@"body"]) self.body = newContent[@"body"];
        }

        self.reactions = [NSMutableDictionary dictionary];

        double ts = [dict[@"origin_server_ts"] doubleValue] / 1000.0;
        _timestamp = [NSDate dateWithTimeIntervalSince1970:ts];
    }
    return self;
}
@end

@implementation MatrixUser
- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self) {
        _userId = dict[@"user_id"] ?: @"";
        _displayName = dict[@"displayname"] ?: _userId;
        _avatarUrl = dict[@"avatar_url"] ?: @"";
    }
    return self;
}
@end

@implementation DateSeparator
- (instancetype)initWithDate:(NSDate *)date {
    self = [super init];
    if (self) {
        _date = date;
    }
    return self;
}
@end

@implementation MatrixSpace
- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self) {
        _spaceId = dict[@"room_id"] ?: @"";
        _name = dict[@"name"] ?: _spaceId;
        _childRoomIds = [NSMutableArray array];
        _theme = SpaceThemeDefault;
    }
    return self;
}
@end
