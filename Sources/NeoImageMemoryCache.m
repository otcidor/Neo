#import "NeoImageMemoryCache.h"

@interface NeoImageMemoryCacheItem : NSObject
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, assign) NSUInteger size;
@property (nonatomic, assign) CFAbsoluteTime timestamp;
@end

@implementation NeoImageMemoryCacheItem
@end

@interface NeoImageMemoryCache () {
    dispatch_queue_t _queue;
    NSMutableDictionary *_cache;
    NSMutableDictionary *_averageColors;
    NSUInteger _cacheSize;
}
@end

@implementation NeoImageMemoryCache

+ (instancetype)sharedCache {
    static NeoImageMemoryCache *sInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 12 MB soft limit, 18 MB hard limit optimized for 512 MB devices
        sInstance = [[NeoImageMemoryCache alloc] initWithSoftMemoryLimit:12 * 1024 * 1024
                                                         hardMemoryLimit:18 * 1024 * 1024];
    });
    return sInstance;
}

- (instancetype)initWithSoftMemoryLimit:(NSUInteger)softLimit hardMemoryLimit:(NSUInteger)hardLimit {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("win.otcidor.neo.imagememorycache", DISPATCH_QUEUE_SERIAL);
        _softMemoryLimit = softLimit;
        _hardMemoryLimit = MAX(hardLimit, softLimit);
        _cache = [[NSMutableDictionary alloc] init];
        _averageColors = [[NSMutableDictionary alloc] init];
        _cacheSize = 0;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleMemoryWarning)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleMemoryWarning {
    [self clearMemory];
}

- (NSUInteger)currentMemoryUsage {
    __block NSUInteger size = 0;
    dispatch_sync(_queue, ^{
        size = _cacheSize;
    });
    return size;
}

- (void)_pruneIfNeededForIncomingSize:(NSUInteger)incomingSize {
    if (_cacheSize + incomingSize > _hardMemoryLimit) {
        __block NSInteger requiredMemory = (NSInteger)(_cacheSize + incomingSize - _softMemoryLimit);

        NSArray *sortedKeys = [_cache keysSortedByValueUsingComparator:^NSComparisonResult(NeoImageMemoryCacheItem *item1, NeoImageMemoryCacheItem *item2) {
            if (item1.timestamp < item2.timestamp) return NSOrderedAscending;
            if (item1.timestamp > item2.timestamp) return NSOrderedDescending;
            return NSOrderedSame;
        }];

        for (id key in sortedKeys) {
            NeoImageMemoryCacheItem *item = _cache[key];
            requiredMemory -= item.size;
            [_cache removeObjectForKey:key];
            if (requiredMemory <= 0) break;
        }

        NSUInteger recomputed = 0;
        for (NeoImageMemoryCacheItem *item in [_cache allValues]) {
            recomputed += item.size;
        }
        _cacheSize = recomputed;
    }
    _cacheSize += incomingSize;
}

- (UIImage *)imageForKey:(NSString *)key {
    if (!key) return nil;
    __block UIImage *result = nil;
    dispatch_sync(_queue, ^{
        NeoImageMemoryCacheItem *item = _cache[key];
        if (item) {
            item.timestamp = CFAbsoluteTimeGetCurrent();
            result = item.image;
        }
    });
    return result;
}

- (void)setImage:(UIImage *)image forKey:(NSString *)key {
    if (!key) return;
    dispatch_async(_queue, ^{
        NeoImageMemoryCacheItem *existing = _cache[key];
        if (existing) {
            if (existing.size > _cacheSize) _cacheSize = 0;
            else _cacheSize -= existing.size;
            [_cache removeObjectForKey:key];
        }

        if (image && [image isKindOfClass:[UIImage class]]) {
            CGSize dimensions = image.size;
            CGFloat scale = image.scale > 0 ? image.scale : 1.0f;
            NSUInteger size = (NSUInteger)((dimensions.width * scale * dimensions.height * scale) * 4);
            if (size == 0) size = 1024;

            [self _pruneIfNeededForIncomingSize:size];

            NeoImageMemoryCacheItem *newItem = [[NeoImageMemoryCacheItem alloc] init];
            newItem.image = image;
            newItem.size = size;
            newItem.timestamp = CFAbsoluteTimeGetCurrent();
            _cache[key] = newItem;
        }
    });
}

- (void)removeImageForKey:(NSString *)key {
    if (!key) return;
    dispatch_async(_queue, ^{
        NeoImageMemoryCacheItem *item = _cache[key];
        if (item) {
            if (item.size > _cacheSize) _cacheSize = 0;
            else _cacheSize -= item.size;
            [_cache removeObjectForKey:key];
        }
    });
}

- (void)clearMemory {
    dispatch_async(_queue, ^{
        [_cache removeAllObjects];
        _cacheSize = 0;
        [_averageColors removeAllObjects];
    });
}

- (void)setAverageColor:(uint32_t)color forKey:(NSString *)key {
    if (!key) return;
    dispatch_async(_queue, ^{
        _averageColors[key] = @(color);
    });
}

- (BOOL)averageColorForKey:(NSString *)key color:(uint32_t *)color {
    if (!key) return NO;
    __block BOOL found = NO;
    __block uint32_t c = 0;
    dispatch_sync(_queue, ^{
        NSNumber *val = _averageColors[key];
        if (val) {
            found = YES;
            c = [val unsignedIntValue];
        }
    });
    if (color && found) *color = c;
    return found;
}

@end
