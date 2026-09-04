#import <Foundation/Foundation.h>

@interface NeoCurlTransport : NSObject

+ (void)uploadFile:(NSString *)filePath
             toURL:(NSString *)urlString
           headers:(NSDictionary *)headers
          progress:(void(^)(float progress))progress
        completion:(void(^)(NSData *responseData, NSInteger statusCode, NSError *error))completion;

+ (void)uploadData:(NSData *)data
             toURL:(NSString *)urlString
           headers:(NSDictionary *)headers
        completion:(void(^)(NSData *responseData, NSInteger statusCode, NSError *error))completion;

+ (void)fetchData:(NSString *)urlString
          headers:(NSDictionary *)headers
          timeout:(NSInteger)timeout
       completion:(void(^)(NSData *responseData, NSInteger statusCode, NSError *error))completion;

@end
