#import "NeoSyncProcessor.h"
#import "MatrixModels.h"

@implementation NeoSyncProcessor

- (instancetype)init {
    self = [super init];
    if (self) {
        _pendingEdits = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL)applyEvents:(NSArray *)events
           messages:(NSMutableArray *)messages
  messagesByEventId:(NSMutableDictionary *)messagesByEventId
               room:(MatrixRoom *)room
           myUserId:(NSString *)myUserId
      roomNameChanged:(void (^)(NSString *newName))roomNameChanged {
    if ([events count] == 0) return NO;

    BOOL changed = NO;

    for (NSDictionary *evt in events) {
        if (![evt isKindOfClass:[NSDictionary class]]) continue;
        NSString *type = evt[@"type"];
        if (![type isKindOfClass:[NSString class]]) continue;

        if ([type isEqualToString:@"m.room.message"] || [type isEqualToString:@"m.room.encrypted"]) {
            NSDictionary *content = evt[@"content"];
            if (![content isKindOfClass:[NSDictionary class]]) continue;
            NSDictionary *relatesto = content[@"m.relates_to"];

            if ([relatesto isKindOfClass:[NSDictionary class]] &&
                [relatesto[@"rel_type"] isEqualToString:@"m.replace"]) {
                NSString *targetId = relatesto[@"event_id"];
                NSString *newBody = content[@"m.new_content"][@"body"];
                if ([targetId isKindOfClass:[NSString class]] && [newBody isKindOfClass:[NSString class]]) {
                    MatrixMessage *target = [messagesByEventId objectForKey:targetId];
                    if (target) {
                        target.body = newBody;
                        [_pendingEdits removeObjectForKey:targetId];
                        changed = YES;
                    } else {
                        [_pendingEdits setObject:newBody forKey:targetId];
                    }
                }
                continue;
            }

            NSString *eventId = evt[@"event_id"];
            if (![eventId isKindOfClass:[NSString class]]) continue;

            MatrixMessage *existing = [messagesByEventId objectForKey:eventId];
            if (existing) {
                double ts = [evt[@"origin_server_ts"] doubleValue] / 1000.0;
                if (ts > 0) {
                    existing.timestamp = [NSDate dateWithTimeIntervalSince1970:ts];
                    changed = YES;
                }
                continue;
            }

            MatrixMessage *msg = [[MatrixMessage alloc] initWithDictionary:evt roomId:room.roomId];
            NSString *pendingBody = [_pendingEdits objectForKey:eventId];
            if (pendingBody) {
                msg.body = pendingBody;
                [_pendingEdits removeObjectForKey:eventId];
            }
            [messages addObject:msg];
            [messagesByEventId setObject:msg forKey:eventId];
            changed = YES;
            continue;
        }

        if ([type isEqualToString:@"m.room.name"]) {
            NSString *name = evt[@"content"][@"name"];
            if ([name isKindOfClass:[NSString class]] && [name length] > 0) {
                room.name = name;
                if (roomNameChanged) roomNameChanged(name);
            }
            continue;
        }

        if ([type isEqualToString:@"m.room.canonical_alias"]) {
            NSString *alias = evt[@"content"][@"alias"];
            if ([alias isKindOfClass:[NSString class]] && [alias length] > 0) {
                room.name = alias;
                if (roomNameChanged) roomNameChanged(alias);
            }
            continue;
        }

        if ([type isEqualToString:@"m.room.redaction"]) {
            NSString *redactedId = evt[@"redacts"];
            if (![redactedId isKindOfClass:[NSString class]] && [evt[@"content"] isKindOfClass:[NSDictionary class]]) {
                redactedId = evt[@"content"][@"redacts"];
            }
            if (![redactedId isKindOfClass:[NSString class]]) continue;
            MatrixMessage *target = [messagesByEventId objectForKey:redactedId];
            if (target) {
                target.isRedacted = YES;
                target.body = NSLocalizedString(@"Deleted message", nil);
                changed = YES;
            }
            continue;
        }

        if ([type isEqualToString:@"m.reaction"]) {
            NSDictionary *relatesto = evt[@"content"][@"m.relates_to"];
            if (![relatesto isKindOfClass:[NSDictionary class]]) continue;
            NSString *targetId = relatesto[@"event_id"];
            NSString *emoji = relatesto[@"key"];
            if (![targetId isKindOfClass:[NSString class]] || ![emoji isKindOfClass:[NSString class]]) continue;
            MatrixMessage *target = [messagesByEventId objectForKey:targetId];
            if (!target) continue;
            if (!target.reactions) target.reactions = [NSMutableDictionary dictionary];
            NSNumber *count = target.reactions[emoji] ?: @0;
            target.reactions[emoji] = @([count intValue] + 1);
            NSString *sender = evt[@"sender"];
            if (myUserId && [sender isKindOfClass:[NSString class]] && [sender isEqualToString:myUserId]) {
                if (!target.myReactions) target.myReactions = [NSMutableDictionary dictionary];
                target.myReactions[emoji] = @YES;
            }
            changed = YES;
            continue;
        }
    }

    return changed;
}

@end
