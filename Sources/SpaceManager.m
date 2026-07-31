#import "SpaceManager.h"
#import "MatrixAPIClient.h"

static NSString *const kBridgeMapKey = @"neo_bridge_map";
static NSString *const kSpacesKey = @"neo_spaces";
static NSString *const kRoomSpaceMapKey = @"neo_room_space_map";

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
        [instance loadBridgeMap];
        [instance loadSpaceState];
    });
    return instance;
}

- (void)loadBridgeMap {
    NSDictionary *saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kBridgeMapKey];
    _bridgeMap = saved ? [NSMutableDictionary dictionaryWithDictionary:saved] : [NSMutableDictionary dictionary];
    NSLog(@"[Bridge] loaded %d mappings from NSUserDefaults", (int)[_bridgeMap count]);
}

- (void)saveBridgeMap {
    if (!_bridgeMap) return;
    [[NSUserDefaults standardUserDefaults] setObject:[_bridgeMap copy] forKey:kBridgeMapKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)saveSpaceState {
    NSMutableArray *arr = [NSMutableArray array];
    for (MatrixSpace *s in self.spaces) {
        [arr addObject:@{
            @"spaceId": s.spaceId ?: @"",
            @"name": s.name ?: @"",
            @"theme": @(s.theme),
            @"children": s.childRoomIds ?: @[]
        }];
    }
    [[NSUserDefaults standardUserDefaults] setObject:arr forKey:kSpacesKey];
    [[NSUserDefaults standardUserDefaults] setObject:self.roomSpaceMap forKey:kRoomSpaceMapKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)loadSpaceState {
    NSArray *savedSpaces = [[NSUserDefaults standardUserDefaults] arrayForKey:kSpacesKey];
    NSMutableArray *spaces = [NSMutableArray array];
    for (NSDictionary *d in savedSpaces) {
        if (![d isKindOfClass:[NSDictionary class]]) continue;
        MatrixSpace *s = [[MatrixSpace alloc] init];
        s.spaceId = d[@"spaceId"] ?: @"";
        s.name = d[@"name"] ?: @"";
        s.theme = [d[@"theme"] intValue];
        NSArray *children = d[@"children"];
        s.childRoomIds = [children isKindOfClass:[NSArray class]]
            ? [NSMutableArray arrayWithArray:children] : [NSMutableArray array];
        [spaces addObject:s];
    }
    self.spaces = spaces;
    NSDictionary *map = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kRoomSpaceMapKey];
    self.roomSpaceMap = map ? [NSMutableDictionary dictionaryWithDictionary:map]
                            : [NSMutableDictionary dictionary];
    if ([spaces count] > 0) self.hasData = YES;
    NSLog(@"[Bridge] loaded %d spaces, %d room mappings from defaults",
          (int)[spaces count], (int)[self.roomSpaceMap count]);
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

        // Bridge detection from summary heroes + room name fallback
        // (lazy_load_members omits m.room.member events, so setMembers: above won't trigger)
        [[SpaceManager sharedManager] setBridgeFromSummary:roomData[@"summary"] roomName:spaceName forRoomId:roomId];

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
    [self saveSpaceState];

    // Pre-fetch members for small rooms (<50 members) to populate disk cache
    static const NSInteger kMemberFetchThreshold = 50;
    [join enumerateKeysAndObjectsUsingBlock:^(NSString *roomId, NSDictionary *roomData, BOOL *stop) {
        NSDictionary *summary = roomData[@"summary"];
        NSInteger count = [summary[@"m.joined_member_count"] integerValue] ?: [summary[@"joined_member_count"] integerValue];
        if (count > 0 && count <= kMemberFetchThreshold) {
            NSInteger cachedCount = [[MatrixAPIClient sharedClient] cachedMemberCountForRoom:roomId];
            if (cachedCount != count) {
                [[MatrixAPIClient sharedClient] getMembersForRoom:roomId completion:^(NSDictionary *members, NSError *error) {
                    if (!members) return;
                    [self detectBridgesFromMembers:members forRoomId:roomId];
                }];
            }
        }
    }];
}

- (void)detectBridgesFromMembers:(NSDictionary *)members forRoomId:(NSString *)roomId {
    if ([_bridgeMap objectForKey:roomId]) return;
    for (NSString *userId in members) {
        NSString *lower = [userId lowercaseString];
        NSString *bridge = nil;
        if ([lower rangeOfString:@"whatsapp"].location != NSNotFound) bridge = @"whatsapp";
        else if ([lower rangeOfString:@"telegram"].location != NSNotFound) bridge = @"telegram";
        else if ([lower rangeOfString:@"discord"].location != NSNotFound) bridge = @"discord";
        else if ([lower rangeOfString:@"instagram"].location != NSNotFound) bridge = @"instagram";
        if (bridge) {
            [_bridgeMap setObject:bridge forKey:roomId];
            [self saveBridgeMap];
            NSLog(@"[Bridge] %@ → %@ (from /members)", roomId, bridge);
            return;
        }
    }
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
            [self saveBridgeMap];
            NSLog(@"[Bridge] %@ → %@", roomId, bridge);
            return;
        }
    }
}

- (NSString *)bridgeTypeForRoomId:(NSString *)roomId {
    return [_bridgeMap objectForKey:roomId];
}

- (void)setBridgeFromSummary:(NSDictionary *)summary roomName:(NSString *)roomName forRoomId:(NSString *)roomId {
    if ([_bridgeMap objectForKey:roomId]) return;
    if (![summary isKindOfClass:[NSDictionary class]] && [roomName length] == 0) return;

    // Try heroes from summary (always present with lazy_load_members)
    NSArray *heroes = summary[@"m.heroes"];
    if ([heroes isKindOfClass:[NSArray class]]) {
        for (NSString *userId in heroes) {
            if (![userId isKindOfClass:[NSString class]]) continue;
            NSString *lower = [userId lowercaseString];
            NSString *bridge = nil;
            if ([lower rangeOfString:@"whatsapp"].location != NSNotFound) bridge = @"whatsapp";
            else if ([lower rangeOfString:@"telegram"].location != NSNotFound) bridge = @"telegram";
            else if ([lower rangeOfString:@"discord"].location != NSNotFound) bridge = @"discord";
            else if ([lower rangeOfString:@"instagram"].location != NSNotFound) bridge = @"instagram";
            if (bridge) {
                [_bridgeMap setObject:bridge forKey:roomId];
                [self saveBridgeMap];
                NSLog(@"[Bridge] %@ → %@ (heroes)", roomId, bridge);
                return;
            }
        }
    }

    // Fallback: detect from room name
    if ([roomName length] > 0) {
        NSString *lower = [roomName lowercaseString];
        NSString *bridge = nil;
        if ([lower rangeOfString:@"whatsapp"].location != NSNotFound) bridge = @"whatsapp";
        else if ([lower rangeOfString:@"telegram"].location != NSNotFound) bridge = @"telegram";
        else if ([lower rangeOfString:@"discord"].location != NSNotFound) bridge = @"discord";
        else if ([lower rangeOfString:@"instagram"].location != NSNotFound) bridge = @"instagram";
        if (bridge) {
            [_bridgeMap setObject:bridge forKey:roomId];
            [self saveBridgeMap];
            NSLog(@"[Bridge] %@ → %@ (room name)", roomId, bridge);
        }
    }
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
