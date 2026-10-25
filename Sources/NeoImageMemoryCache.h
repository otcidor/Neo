#import <UIKit/UIKit.h>

@interface NeoImageMemoryCache : NSObject

@property (nonatomic, assign) NSUInteger softMemoryLimit;
@property (nonatomic, assign) NSUInteger hardMemoryLimit;
@property (nonatomic, readonly) NSUInteger currentMemoryUsage;

+ (instancetype)sharedCache;

- (instancetype)initWithSoftMemoryLimit:(NSUInteger)softLimit hardMemoryLimit:(NSUInteger)hardLimit;

- (void)setImage:(UIImage *)image forKey:(NSString *)key;
- (UIImage *)imageForKey:(NSString *)key;
- (void)removeImageForKey:(NSString *)key;
- (void)clearMemory;

- (void)setAverageColor:(uint32_t)color forKey:(NSString *)key;
- (BOOL)averageColorForKey:(NSString *)key color:(uint32_t *)color;

@end
