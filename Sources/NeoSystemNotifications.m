#import "NeoSystemNotifications.h"
#import <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define INTERNAL_TAG @"SBInternalAppTag"
#define TAGS_KEY @"SBAppTags"
#define SHOW_INTERNAL_KEY @"SBShowInternalApps"
#define SPRINGBOARD_PREFS @"/var/mobile/Library/Preferences/com.apple.springboard.plist"
#define SWITCH_MARKER @"/var/mobile/Library/Preferences/.neo-show-internal-apps"
#define FIRST_UNSUPPORTED_CF 847.20 // iOS 7.0

static void NeoSysNotifyLog(NSString *msg, NSString *detail) {
    NSLog(@"[NeoSystemNotifications] %@: %@", msg, detail);
}

static BOOL NeoSysNotifyEdit(NSString *path, BOOL (^mutate)(NSMutableDictionary *dictionary)) {
    struct stat info;
    if (stat(path.fileSystemRepresentation, &info) != 0) {
        NeoSysNotifyLog(@"Cannot stat file", path);
        return NO;
    }
    
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data.length) {
        NeoSysNotifyLog(@"Cannot read data from", path);
        return NO;
    }
    
    CFPropertyListFormat format = 0;
    CFErrorRef error = NULL;
    CFMutableDictionaryRef parsed = (CFMutableDictionaryRef)CFPropertyListCreateWithData(
        kCFAllocatorDefault,
        (__bridge CFDataRef)data,
        kCFPropertyListMutableContainers,
        &format,
        &error
    );
    
    if (!parsed) {
        if (error) CFRelease(error);
        NeoSysNotifyLog(@"Failed to parse plist at", path);
        return NO;
    }
    
    NSMutableDictionary *dictionary = (__bridge_transfer NSMutableDictionary *)parsed;
    if (!mutate(dictionary)) {
        return YES; // No changes needed
    }
    
    CFErrorRef writeError = NULL;
    CFDataRef outData = CFPropertyListCreateData(
        kCFAllocatorDefault,
        (__bridge CFPropertyListRef)dictionary,
        format,
        0,
        &writeError
    );
    
    if (!outData) {
        if (writeError) CFRelease(writeError);
        NeoSysNotifyLog(@"Failed to serialize plist for", path);
        return NO;
    }
    
    NSData *serialized = (__bridge_transfer NSData *)outData;
    NSString *temporary = [path stringByAppendingString:@".neo-new"];
    if (![serialized writeToFile:temporary atomically:NO]) {
        NeoSysNotifyLog(@"Failed to write temp plist at", temporary);
        return NO;
    }
    
    if (chown(temporary.fileSystemRepresentation, info.st_uid, info.st_gid) != 0 ||
        chmod(temporary.fileSystemRepresentation, info.st_mode & 07777) != 0 ||
        rename(temporary.fileSystemRepresentation, path.fileSystemRepresentation) != 0) {
        unlink(temporary.fileSystemRepresentation);
        NeoSysNotifyLog(@"Failed to replace plist at", path);
        return NO;
    }
    
    return YES;
}

static BOOL NeoSysNotifyTagBundle(NSString *infoPath) {
    return NeoSysNotifyEdit(infoPath, ^BOOL(NSMutableDictionary *info) {
        id tags = [info objectForKey:TAGS_KEY];
        if ([tags isKindOfClass:[NSArray class]]) {
            if ([tags containsObject:INTERNAL_TAG]) return NO;
            [info setObject:[tags arrayByAddingObject:INTERNAL_TAG] forKey:TAGS_KEY];
        } else {
            [info setObject:[NSArray arrayWithObject:INTERNAL_TAG] forKey:TAGS_KEY];
        }
        return YES;
    });
}

static BOOL NeoSysNotifySetSwitch(NSString *prefs, NSString *marker) {
    __block BOOL changed = NO;
    BOOL ok = NeoSysNotifyEdit(prefs, ^BOOL(NSMutableDictionary *dictionary) {
        id current = [dictionary objectForKey:SHOW_INTERNAL_KEY];
        if ([current respondsToSelector:@selector(boolValue)] && [current boolValue]) return NO;
        [dictionary setObject:[NSNumber numberWithBool:YES] forKey:SHOW_INTERNAL_KEY];
        changed = YES;
        return YES;
    });
    
    if (ok && changed && ![[NSData data] writeToFile:marker atomically:NO]) {
        NeoSysNotifyLog(@"Failed to touch marker", marker);
        return NO;
    }
    return ok;
}

static BOOL NeoSysNotifyClearSwitch(NSString *prefs, NSString *marker) {
    if (access(marker.fileSystemRepresentation, F_OK) != 0) return YES;
    BOOL ok = NeoSysNotifyEdit(prefs, ^BOOL(NSMutableDictionary *dictionary) {
        if (![dictionary objectForKey:SHOW_INTERNAL_KEY]) return NO;
        [dictionary removeObjectForKey:SHOW_INTERNAL_KEY];
        return YES;
    });
    if (ok && unlink(marker.fileSystemRepresentation) != 0) {
        NeoSysNotifyLog(@"Failed to unlink marker", marker);
        return NO;
    }
    return ok;
}

int NeoSystemNotificationsRun(const char *command) {
    @autoreleasepool {
        if (kCFCoreFoundationVersionNumber >= FIRST_UNSUPPORTED_CF) {
            fprintf(stderr, "neo: system notification setup is only needed on iOS 5 and 6, nothing to do on iOS 7+\n");
            return 0;
        }
        
        NSString *info = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Info.plist"];
        NSString *prefs = SPRINGBOARD_PREFS;
        NSString *marker = SWITCH_MARKER;
        
        if (command && !strcmp(command, "on")) {
            BOOL ok = NeoSysNotifyTagBundle(info) && NeoSysNotifySetSwitch(prefs, marker);
            return ok ? 0 : 1;
        } else if (command && !strcmp(command, "off")) {
            BOOL ok = NeoSysNotifyClearSwitch(prefs, marker);
            return ok ? 0 : 1;
        } else {
            fprintf(stderr, "usage: Neo --system-notifications on|off\n");
            return 2;
        }
    }
}

@implementation NeoSystemNotifications

+ (void)setupSystemNotificationsIfNeeded {
    if (kCFCoreFoundationVersionNumber >= FIRST_UNSUPPORTED_CF) {
        return; // iOS 7+ handles notification settings natively
    }
    
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    if (![bundlePath hasPrefix:@"/Applications"]) {
        return; // User-installed apps (/var/mobile/Applications) do not suffer from the SpringBoard system bug
    }
    
    id tags = [[NSBundle mainBundle] objectForInfoDictionaryKey:TAGS_KEY];
    BOOL hasTag = [tags isKindOfClass:[NSArray class]] && [tags containsObject:INTERNAL_TAG];
    BOOL hasMarker = (access(SWITCH_MARKER.fileSystemRepresentation, F_OK) == 0);
    
    if (hasTag && hasMarker) {
        return; // Already configured
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        int res = NeoSystemNotificationsRun("on");
        if (res == 0) {
            NSLog(@"[NeoSystemNotifications] Successfully configured SpringBoard notification integration for iOS 5/6 system app.");
        }
    });
}

@end
