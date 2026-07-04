#import "SpaceManager.h"
#import "MatrixAPIClient.h"

static SpaceTheme themeForSpaceName(NSString *name) {
    NSString *lower = [name lowercaseString];
    if ([lower rangeOfString:@"whatsapp"].location != NSNotFound) return SpaceThemeWhatsApp;
    if ([lower rangeOfString:@"telegram"].location != NSNotFound) return SpaceThemeTelegram;
    if ([lower rangeOfString:@"discord"].location != NSNotFound) return SpaceThemeDiscord;
    if ([lower rangeOfString:@"instagram"].location != NSNotFound) return SpaceThemeInstagram;
    return SpaceThemeDefault;
}

@implementation SpaceManager {
    NSMutableDictionary *_bridgeMap;
}

+ (instancetype)sharedManager {
    static SpaceManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        instance.roomSpaceMap = [NSMutableDictionary dictionary];
        instance.spaces = [NSArray array];
    });
    return instance;
}

- (void)buildSpaceMapFromSyncResponse:(NSDictionary *)syncResponse {
    if (!syncResponse) return;

    [self.roomSpaceMap removeAllObjects];
    NSDictionary *join = syncResponse[@"rooms"][@"join"];
    if (![join isKindOfClass:[NSDictionary class]]) return;

    NSMutableArray *foundSpaces = [NSMutableArray array];

    [join enumerateKeysAndObjectsUsingBlock:^(NSString *roomId, NSDictionary *roomData, BOOL *stop) {
        BOOL isSpace = NO;
        NSString *spaceName = nil;

        NSArray *stateEvents = roomData[@"state"][@"events"];
        if ([stateEvents isKindOfClass:[NSArray class]]) {
            [[SpaceManager sharedManager] setMembers:stateEvents forRoomId:roomId];
        }
        if (![stateEvents isKindOfClass:[NSArray class]]) stateEvents = [NSArray array];

        for (NSDictionary *evt in stateEvents) {
            if (![evt isKindOfClass:[NSDictionary class]]) continue;
            NSString *type = evt[@"type"];
            NSDictionary *content = evt[@"content"];
            if ([type isEqualToString:@"m.room.type"] && [content[@"type"] isEqualToString:@"m.space"]) {
                isSpace = YES;
            }
            if ([type isEqualToString:@"m.room.name"]) {
                spaceName = content[@"name"];
            }
        }

        if (!isSpace) {
            NSArray *timelineEvents = roomData[@"timeline"][@"events"];
            if ([timelineEvents isKindOfClass:[NSArray class]]) {
                for (NSDictionary *evt in timelineEvents) {
                    if (![evt isKindOfClass:[NSDictionary class]]) continue;
                    NSString *type = evt[@"type"];
                    NSDictionary *content = evt[@"content"];
                    if ([type isEqualToString:@"m.room.type"] && [content[@"type"] isEqualToString:@"m.space"]) {
                        isSpace = YES;
                        break;
                    }
                }
            }
        }

        if (isSpace) {
            MatrixSpace *space = [[MatrixSpace alloc] init];
            space.spaceId = roomId;
            space.name = [spaceName length] > 0 ? spaceName : [self guessSpaceName:roomId];
            space.theme = themeForSpaceName(space.name);

            for (NSDictionary *evt in stateEvents) {
                if (![evt isKindOfClass:[NSDictionary class]]) continue;
                if ([evt[@"type"] isEqualToString:@"m.space.child"]) {
                    NSString *childId = evt[@"state_key"];
                    NSDictionary *content = evt[@"content"];
                    if ([childId length] > 0 && [content isKindOfClass:[NSDictionary class]]) {
                        [space.childRoomIds addObject:childId];
                        [self.roomSpaceMap setObject:roomId forKey:childId];
                    }
                }
            }

            NSLog(@"SpaceManager: space '%@' (%@) has %d children", space.name, roomId, (int)[space.childRoomIds count]);
            [foundSpaces addObject:space];
        }
    }];

    self.spaces = foundSpaces;
    self.hasData = YES;
    NSLog(@"SpaceManager: built map with %d spaces, %d room mappings", (int)[foundSpaces count], (int)[self.roomSpaceMap count]);
}

- (SpaceTheme)themeForRoomId:(NSString *)roomId {
    NSString *spaceId = [self.roomSpaceMap objectForKey:roomId];
    if (!spaceId) return SpaceThemeDefault;
    for (MatrixSpace *s in self.spaces) {
        if ([s.spaceId isEqualToString:spaceId]) return s.theme;
    }
    return SpaceThemeDefault;
}

- (NSArray *)roomsForSpaceId:(NSString *)spaceId fromAllRooms:(NSArray *)allRooms {
    NSMutableArray *filtered = [NSMutableArray array];
    for (MatrixRoom *room in allRooms) {
        NSString *parentSpace = [self.roomSpaceMap objectForKey:room.roomId];
        if ([parentSpace isEqualToString:spaceId]) {
            [filtered addObject:room];
        }
    }
    return filtered;
}

- (NSArray *)roomIdsForSpaceNameFilter:(NSString *)nameFilter {
    if ([nameFilter length] == 0) return nil;
    NSMutableSet *ids = [NSMutableSet set];
    for (MatrixSpace *space in self.spaces) {
        if ([space.name rangeOfString:nameFilter options:NSCaseInsensitiveSearch].location != NSNotFound) {
            [ids addObjectsFromArray:space.childRoomIds];
        }
    }
    return [ids allObjects];
}

- (void)setMembers:(NSArray *)memberEvents forRoomId:(NSString *)roomId {
    if (!_bridgeMap) _bridgeMap = [NSMutableDictionary dictionary];
    for (NSDictionary *evt in memberEvents) {
        NSString *userId = evt[@"state_key"];
        if (!userId) continue;
        NSString *lower = [userId lowercaseString];
        NSString *bridge = nil;
        if ([lower rangeOfString:@"whatsapp"].location != NSNotFound) bridge = @"whatsapp";
        else if ([lower rangeOfString:@"telegram"].location != NSNotFound) bridge = @"telegram";
        else if ([lower rangeOfString:@"discord"].location != NSNotFound) bridge = @"discord";
        else if ([lower rangeOfString:@"instagram"].location != NSNotFound) bridge = @"instagram";
        if (bridge) {
            [_bridgeMap setObject:bridge forKey:roomId];
            NSLog(@"[Bridge] %@ → %@", roomId, bridge);
            return;
        }
    }
}

- (NSString *)bridgeTypeForRoomId:(NSString *)roomId {
    return [_bridgeMap objectForKey:roomId];
}

- (NSString *)guessSpaceName:(NSString *)spaceId {
    NSString *decoded = [spaceId stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSRange colon = [decoded rangeOfString:@":"];
    NSString *localpart = (colon.location != NSNotFound) ? [decoded substringToIndex:colon.location] : decoded;
    localpart = [localpart stringByReplacingOccurrencesOfString:@"!" withString:@""];
    localpart = [localpart stringByReplacingOccurrencesOfString:@"_" withString:@" "];
    NSArray *parts = [localpart componentsSeparatedByString:@" "];
    NSMutableArray *titleParts = [NSMutableArray array];
    for (NSString *p in parts) {
        if ([p length] > 0) {
            [titleParts addObject:[p capitalizedString]];
        }
    }
    return [titleParts count] > 0 ? [titleParts componentsJoinedByString:@" "] : spaceId;
}

@end
