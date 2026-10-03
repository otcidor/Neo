#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static id Neo_objectAtIndexedSubscript(id self, SEL _cmd, NSUInteger idx) {
    return [self objectAtIndex:idx];
}

static void Neo_setObjectAtIndexedSubscript(id self, SEL _cmd, id obj, NSUInteger idx) {
    [self replaceObjectAtIndex:idx withObject:obj];
}

static id Neo_objectForKeyedSubscript(id self, SEL _cmd, id key) {
    return [self objectForKey:key];
}

static void Neo_setObjectForKeyedSubscript(id self, SEL _cmd, id obj, id<NSCopying> key) {
    if (obj) {
        [self setObject:obj forKey:key];
    } else {
        [self removeObjectForKey:key];
    }
}

// Category fallback on root classes
@implementation NSArray (NeoSubscriptingCompat)
- (id)objectAtIndexedSubscript:(NSUInteger)idx {
    return [self objectAtIndex:idx];
}
@end

@implementation NSMutableArray (NeoSubscriptingCompat)
- (void)setObject:(id)obj atIndexedSubscript:(NSUInteger)idx {
    [self replaceObjectAtIndex:idx withObject:obj];
}
@end

@implementation NSDictionary (NeoSubscriptingCompat)
- (id)objectForKeyedSubscript:(id)key {
    return [self objectForKey:key];
}
@end

@implementation NSMutableDictionary (NeoSubscriptingCompat)
- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key {
    if (obj) {
        [self setObject:obj forKey:key];
    } else {
        [self removeObjectForKey:key];
    }
}
@end

#pragma clang diagnostic pop

// Runtime dynamic injection into all concrete Apple class clusters at load time
@interface NeoSubscriptingLoader : NSObject
@end

@implementation NeoSubscriptingLoader

+ (void)load {
    SEL selIndexGet = sel_registerName("objectAtIndexedSubscript:");
    SEL selIndexSet = sel_registerName("setObject:atIndexedSubscript:");
    SEL selKeyGet = sel_registerName("objectForKeyedSubscript:");
    SEL selKeySet = sel_registerName("setObject:forKeyedSubscript:");

    const char *arrayClasses[] = {
        "NSArray", "NSMutableArray",
        "__NSArrayI", "__NSArrayM",
        "__NSCFArray",
        NULL
    };
    for (int i = 0; arrayClasses[i] != NULL; i++) {
        Class cls = objc_getClass(arrayClasses[i]);
        if (cls && !class_getInstanceMethod(cls, selIndexGet)) {
            class_addMethod(cls, selIndexGet, (IMP)Neo_objectAtIndexedSubscript, "@@:I");
        }
    }

    const char *mutArrayClasses[] = {
        "NSMutableArray",
        "__NSArrayM",
        "__NSCFArray",
        NULL
    };
    for (int i = 0; mutArrayClasses[i] != NULL; i++) {
        Class cls = objc_getClass(mutArrayClasses[i]);
        if (cls && !class_getInstanceMethod(cls, selIndexSet)) {
            class_addMethod(cls, selIndexSet, (IMP)Neo_setObjectAtIndexedSubscript, "v@:@I");
        }
    }

    const char *dictClasses[] = {
        "NSDictionary", "NSMutableDictionary",
        "__NSDictionaryI", "__NSDictionaryM",
        "__NSCFDictionary",
        NULL
    };
    for (int i = 0; dictClasses[i] != NULL; i++) {
        Class cls = objc_getClass(dictClasses[i]);
        if (cls && !class_getInstanceMethod(cls, selKeyGet)) {
            class_addMethod(cls, selKeyGet, (IMP)Neo_objectForKeyedSubscript, "@@:@");
        }
    }

    const char *mutDictClasses[] = {
        "NSMutableDictionary",
        "__NSDictionaryM",
        "__NSCFDictionary",
        NULL
    };
    for (int i = 0; mutDictClasses[i] != NULL; i++) {
        Class cls = objc_getClass(mutDictClasses[i]);
        if (cls && !class_getInstanceMethod(cls, selKeySet)) {
            class_addMethod(cls, selKeySet, (IMP)Neo_setObjectForKeyedSubscript, "v@:@@");
        }
    }
}

@end
