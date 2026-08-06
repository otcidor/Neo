#import <Foundation/Foundation.h>

@interface TGFileCache : NSObject

@property (nonatomic, strong) NSString *defaultFileExtension;

- (instancetype)initWithName:(NSString *)name useMemoryCache:(BOOL)useMemoryCache;

- (void)fetchDataForKey:(NSString *)key synchronous:(BOOL)synchronous unserializeBlock:(id (^)(NSData *))unserializeBlock completion:(void (^)(id))completion;
- (void)fetchDataForKey:(NSString *)key memoryOnly:(BOOL)memoryOnly synchronous:(BOOL)synchronous unserializeBlock:(id (^)(NSData *))unserializeBlock completion:(void (^)(id))completion;
- (void)cacheData:(NSData *)data key:(NSString *)key synchronous:(BOOL)synchronous completion:(void (^)(NSURL *))completion;
- (void)cacheData:(NSObject<NSCoding> *)data key:(NSString *)key synchronous:(BOOL)synchronous serializeBlock:(NSData *(^)(NSObject<NSCoding> *))serializeBlock completion:(void (^)(NSURL *))completion;
- (void)cacheFileAtURL:(NSURL *)url key:(NSString *)key synchronous:(BOOL)synchronous completion:(void (^)(NSURL *))completion;
- (void)cacheFileAtURL:(NSURL *)url key:(NSString *)key synchronous:(BOOL)synchronous unserializeBlock:(id (^)(NSData *))unserializeBlock completion:(void (^)(NSURL *))completion;
- (void)cacheData:(NSData *)data key:(NSString *)key synchronous:(BOOL)synchronous unserializeBlock:(id (^)(NSData *))unserializeBlock completion:(void (^)(NSURL *))completion;
- (void)clearCacheSynchronous:(BOOL)synchronous;

- (BOOL)hasDataForKey:(NSString *)key;
- (NSURL *)urlForKey:(NSString *)key;

@end
