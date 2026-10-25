#import "MatrixModels.h"
#import "MatrixAPIClient.h"

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

- (NSString *)uniqueIdentifier {
    return _roomId ?: @"";
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

+ (BOOL)roomHasNameFromSyncData:(NSDictionary *)roomData {
    NSArray *stateEvents = roomData[@"state"][@"events"];
    for (NSDictionary *evt in stateEvents) {
        NSString *type = evt[@"type"];
        NSDictionary *content = evt[@"content"];
        if (![content isKindOfClass:[NSDictionary class]]) continue;
        if ([type isEqualToString:@"m.room.name"] && [content[@"name"] length] > 0) return YES;
        if ([type isEqualToString:@"m.room.canonical_alias"] && [content[@"alias"] length] > 0) return YES;
    }
    NSArray *timelineEvents = roomData[@"timeline"][@"events"];
    for (NSDictionary *evt in timelineEvents) {
        NSString *type = evt[@"type"];
        NSDictionary *content = evt[@"content"];
        if (![content isKindOfClass:[NSDictionary class]]) continue;
        if ([type isEqualToString:@"m.room.name"] && [content[@"name"] length] > 0) return YES;
        if ([type isEqualToString:@"m.room.canonical_alias"] && [content[@"alias"] length] > 0) return YES;
    }
    return NO;
}

+ (NSString *)displayNameForRoomId:(NSString *)roomId fromSyncData:(NSDictionary *)roomData {
    if (!roomId || [roomId length] == 0) return @"";

    // 1. Check user local custom rename override
    NSString *local = [MatrixAPIClient localNameForRoomId:roomId];
    if (local && [local length] > 0) return local;

    // 2. Check explicit m.room.name in state or timeline
    NSArray *stateEvents = roomData[@"state"][@"events"];
    if ([stateEvents isKindOfClass:[NSArray class]]) {
        for (NSDictionary *evt in stateEvents) {
            if (![evt isKindOfClass:[NSDictionary class]]) continue;
            NSString *type = evt[@"type"];
            NSDictionary *content = evt[@"content"];
            if (![content isKindOfClass:[NSDictionary class]]) continue;
            if ([type isEqualToString:@"m.room.name"]) {
                NSString *name = content[@"name"];
                if ([name isKindOfClass:[NSString class]] && [name length] > 0) {
                    [MatrixAPIClient cacheRoomName:name forRoomId:roomId];
                    return name;
                }
            }
        }
        for (NSDictionary *evt in stateEvents) {
            if (![evt isKindOfClass:[NSDictionary class]]) continue;
            NSString *type = evt[@"type"];
            NSDictionary *content = evt[@"content"];
            if (![content isKindOfClass:[NSDictionary class]]) continue;
            if ([type isEqualToString:@"m.room.canonical_alias"]) {
                NSString *alias = content[@"alias"];
                if ([alias isKindOfClass:[NSString class]] && [alias length] > 0) {
                    [MatrixAPIClient cacheRoomName:alias forRoomId:roomId];
                    return alias;
                }
            }
        }
    }

    NSArray *timelineEvents = roomData[@"timeline"][@"events"];
    if ([timelineEvents isKindOfClass:[NSArray class]]) {
        for (NSDictionary *evt in timelineEvents) {
            if (![evt isKindOfClass:[NSDictionary class]]) continue;
            NSString *type = evt[@"type"];
            NSDictionary *content = evt[@"content"];
            if (![content isKindOfClass:[NSDictionary class]]) continue;
            if ([type isEqualToString:@"m.room.name"]) {
                NSString *name = content[@"name"];
                if ([name isKindOfClass:[NSString class]] && [name length] > 0) {
                    [MatrixAPIClient cacheRoomName:name forRoomId:roomId];
                    return name;
                }
            }
            if ([type isEqualToString:@"m.room.canonical_alias"]) {
                NSString *alias = content[@"alias"];
                if ([alias isKindOfClass:[NSString class]] && [alias length] > 0) {
                    [MatrixAPIClient cacheRoomName:alias forRoomId:roomId];
                    return alias;
                }
            }
        }
    }

    // 3. Check memory & disk room name cache
    NSString *cached = [MatrixAPIClient nameForRoomId:roomId];
    if (cached && [cached length] > 0) {
        return cached;
    }

    // 4. Check heroes in summary
    NSDictionary *summary = roomData[@"summary"];
    if ([summary isKindOfClass:[NSDictionary class]]) {
        NSArray *heroes = summary[@"m.heroes"];
        if ([heroes isKindOfClass:[NSArray class]] && [heroes count] > 0) {
            NSInteger count = [summary[@"m.joined_member_count"] integerValue] ?: [summary[@"joined_member_count"] integerValue];
            if (count <= 4) {
                NSMutableArray *cleanHeroes = [NSMutableArray array];
                NSDictionary *roomMembers = [[MatrixAPIClient sharedClient] cachedMembersForRoom:roomId];
                for (NSString *h in heroes) {
                    if (![h isKindOfClass:[NSString class]] || [h length] == 0) continue;
                    id mEntry = roomMembers[h];
                    NSString *dn = nil;
                    if ([mEntry isKindOfClass:[NSDictionary class]]) {
                        dn = mEntry[@"displayname"];
                    } else if ([mEntry isKindOfClass:[NSString class]]) {
                        dn = mEntry;
                    }
                    if ([dn length] > 0) {
                        [cleanHeroes addObject:dn];
                    } else if ([h hasPrefix:@"@"]) {
                        NSRange colon = [h rangeOfString:@":"];
                        if (colon.location != NSNotFound) {
                            [cleanHeroes addObject:[h substringWithRange:NSMakeRange(1, colon.location - 1)]];
                        } else {
                            [cleanHeroes addObject:[h substringFromIndex:1]];
                        }
                    } else {
                        [cleanHeroes addObject:h];
                    }
                }
                if ([cleanHeroes count] > 0) {
                    NSString *heroTitle = [cleanHeroes componentsJoinedByString:@", "];
                    [MatrixAPIClient cacheRoomName:heroTitle forRoomId:roomId];
                    return heroTitle;
                }
            }
        }
    }

    // 5. Check state events for member display names (1:1 DMs)
    NSString *myId = [[MatrixAPIClient sharedClient] userId];
    if ([stateEvents isKindOfClass:[NSArray class]]) {
        for (NSDictionary *evt in stateEvents) {
            if (![evt isKindOfClass:[NSDictionary class]]) continue;
            if ([evt[@"type"] isEqualToString:@"m.room.member"]) {
                NSString *stateKey = evt[@"state_key"];
                if (stateKey && ![stateKey isEqualToString:myId]) {
                    NSDictionary *content = evt[@"content"];
                    NSString *dn = content[@"displayname"];
                    if ([dn isKindOfClass:[NSString class]] && [dn length] > 0) {
                        [MatrixAPIClient cacheRoomName:dn forRoomId:roomId];
                        return dn;
                    }
                    if ([stateKey hasPrefix:@"@"]) {
                        NSRange colon = [stateKey rangeOfString:@":"];
                        if (colon.location != NSNotFound) {
                            NSString *cleaned = [stateKey substringWithRange:NSMakeRange(1, colon.location - 1)];
                            [MatrixAPIClient cacheRoomName:cleaned forRoomId:roomId];
                            return cleaned;
                        }
                    }
                    [MatrixAPIClient cacheRoomName:stateKey forRoomId:roomId];
                    return stateKey;
                }
            }
        }
    }

    // 6. If roomId is an alias like #general:domain, return #general
    if ([roomId hasPrefix:@"#"]) {
        NSRange colonRange = [roomId rangeOfString:@":"];
        if (colonRange.location != NSNotFound) {
            return [roomId substringToIndex:colonRange.location];
        }
        return roomId;
    }

    // 7. Last resort fallback - NEVER return the domain!
    return NSLocalizedString(@"Chat", nil);
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
                _videoThumbnailURL = info[@"thumbnail_url"] ?: content[@"thumbnail_url"] ?: @"";
            } else {
                _imageWidth = 320;
                _imageHeight = 240;
                _videoWidth = 320;
                _videoHeight = 240;
                _videoThumbnailURL = content[@"thumbnail_url"] ?: @"";
            }

            if ([_msgType isEqualToString:@"m.file"]) {
                _fileURL = content[@"url"] ?: @"";
                _fileName = content[@"body"] ?: @"File";
                _fileMimeType = info[@"mimetype"] ?: @"application/octet-stream";
                _fileSize = info[@"size"] ?: @0;
            }

            if ([content[@"format"] isEqualToString:@"org.matrix.custom.html"] &&
                [content[@"formatted_body"] isKindOfClass:[NSString class]]) {
                _formattedBody = content[@"formatted_body"];
            }

            NSDictionary *mentions = content[@"m.mentions"];
            if ([mentions isKindOfClass:[NSDictionary class]]) {
                if ([mentions[@"user_ids"] isKindOfClass:[NSArray class]]) {
                    _mentionedUserIds = mentions[@"user_ids"];
                }
                _isRoomMention = [mentions[@"room"] boolValue];
            } else if (_formattedBody && [_formattedBody rangeOfString:@"matrix.to/#/@"].location != NSNotFound) {
                NSMutableArray *extracted = [NSMutableArray array];
                NSError *regexErr = nil;
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"https?://matrix\\.to/#/(@[a-zA-Z0-9_\\.\\/=\\+\\-]+:[a-zA-Z0-9_\\.\\-]+)" options:0 error:&regexErr];
                if (regex) {
                    NSArray *matches = [regex matchesInString:_formattedBody options:0 range:NSMakeRange(0, [_formattedBody length])];
                    for (NSTextCheckingResult *match in matches) {
                        if (match.numberOfRanges > 1) {
                            NSString *uid = [_formattedBody substringWithRange:[match rangeAtIndex:1]];
                            if (![extracted containsObject:uid]) [extracted addObject:uid];
                        }
                    }
                }
                _mentionedUserIds = [extracted copy];
            }
        } else {
            _body = @"";
            _msgType = @"m.text";
            _imageURL = @"";
        }

        NSString *eventType = dict[@"type"];
        if ([eventType isEqualToString:@"m.room.encrypted"]) {
            _body = NSLocalizedString(@"🔒 Encrypted message (unsupported)", nil);
            _msgType = @"m.text";
        } else if ([_msgType isEqualToString:@"m.emote"]) {
            _body = [NSString stringWithFormat:@"* %@", _body];
        }

        // Redacted
        if (dict[@"unsigned"][@"redacted_because"]) {
            self.isRedacted = YES;
            self.body = NSLocalizedString(@"Deleted message", nil);
            self.msgType = @"m.text";
        }

        // Reply — m.in_reply_to
        NSDictionary *relatesTo = content[@"m.relates_to"];
        if ([relatesTo isKindOfClass:[NSDictionary class]]) {
            NSDictionary *inReplyTo = relatesTo[@"m.in_reply_to"];
            if ([inReplyTo isKindOfClass:[NSDictionary class]]) {
                _replyToEventId = inReplyTo[@"event_id"];
                if ([_body hasPrefix:@"> "]) {
                    NSRange doubleNewline = [_body rangeOfString:@"\n\n"];
                    if (doubleNewline.location != NSNotFound && doubleNewline.location + 2 < [_body length]) {
                        _body = [_body substringFromIndex:doubleNewline.location + 2];
                    }
                }
            }
            // Edit detection (overrides reply reference)
            if ([relatesTo[@"rel_type"] isEqualToString:@"m.replace"]) {
                self.isEdit = YES;
                self.relatedEventId = relatesTo[@"event_id"];
                NSDictionary *newContent = content[@"m.new_content"];
                if (newContent[@"body"]) self.body = newContent[@"body"];
            }
        }

        self.reactions = [NSMutableDictionary dictionary];
        self.myReactions = [NSMutableDictionary dictionary];
        self.reactionEventIds = [NSMutableDictionary dictionary];
        self.myReactionEventIds = [NSMutableDictionary dictionary];
        _cachedRowHeight = 0;
        _cachedReactionsCount = -1;
        _cachedShowUser = NO;

        double ts = [dict[@"origin_server_ts"] doubleValue] / 1000.0;
        if (ts > 0) {
            _timestamp = [NSDate dateWithTimeIntervalSince1970:ts];
        } else {
            _timestamp = [NSDate date];
        }
    }
    return self;
}

- (NSString *)uniqueIdentifier {
    return _eventId ?: @"";
}

- (void)resolveReplyFromMessages:(NSArray *)messages {
    if (!_replyToEventId || [_replyToEventId length] == 0) return;
    for (MatrixMessage *m in messages) {
        if ([m.eventId isEqualToString:_replyToEventId]) {
            _replyToSender = m.sender;
            _replyToBody = m.body;
            return;
        }
    }
}

- (void)resolveReplyFromDict:(NSDictionary *)messagesByEventId {
    if (!_replyToEventId || [_replyToEventId length] == 0) return;
    MatrixMessage *m = [messagesByEventId objectForKey:_replyToEventId];
    if (m) {
        _replyToSender = m.sender;
        _replyToBody = m.body;
    }
}

- (BOOL)isMentioningUserId:(NSString *)userId {
    if (self.isRoomMention) return YES;
    if (!userId || [userId length] == 0) return NO;
    return [self.mentionedUserIds containsObject:userId];
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
