#import "NeoCurlTransport.h"
#import "curl_bridge.h"

static dispatch_once_t sInitOnce;
static dispatch_queue_t sUploadQueue;
static dispatch_queue_t sRequestQueue;
static NSString *sCABundlePath;

@implementation NeoCurlTransport

+ (void)initialize {
    if (self == [NeoCurlTransport class]) {
        dispatch_once(&sInitOnce, ^{
            curl_bridge_global_init();
            sUploadQueue = dispatch_queue_create("com.neo.curl.upload", DISPATCH_QUEUE_SERIAL);
            sRequestQueue = dispatch_queue_create("com.neo.curl.request", DISPATCH_QUEUE_CONCURRENT);
            sCABundlePath = [[NSBundle mainBundle] pathForResource:@"cacert" ofType:@"pem"];
            if (!sCABundlePath) {
                // Check if in bundle resources or Documents
                NSArray *searchPaths = @[
                    [[NSBundle mainBundle] bundlePath],
                    NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0]
                ];
                for (NSString *dir in searchPaths) {
                    NSString *cand = [dir stringByAppendingPathComponent:@"cacert.pem"];
                    if ([[NSFileManager defaultManager] fileExistsAtPath:cand]) {
                        sCABundlePath = cand;
                        break;
                    }
                }
            }
            NSLog(@"[NeoCurlTransport] Initialized with CA bundle: %@", sCABundlePath);
        });
    }
}

static void NeoApplyTLS(CurlHandle h) {
    curl_bridge_set_ssl_verify(h);
    if (sCABundlePath && [sCABundlePath length] > 0) {
        curl_bridge_set_ca_bundle(h, [sCABundlePath UTF8String]);
    }
}

static void *NeoBuildHeaders(NSDictionary *headers) {
    void *list = NULL;
    for (NSString *key in headers) {
        NSString *val = headers[key];
        NSString *line = [NSString stringWithFormat:@"%@: %@", key, val];
        list = curl_bridge_headers_append(list, [line UTF8String]);
    }
    return list;
}

static size_t NeoWriteCallback(const void *ptr, size_t size, size_t nmemb, void *userdata) {
    size_t bytes = size * nmemb;
    NSMutableData *buf = (__bridge NSMutableData *)userdata;
    [buf appendBytes:ptr length:bytes];
    return bytes;
}

static int NeoUploadProgressCallback(void *clientp,
                                    long long dltotal, long long dlnow,
                                    long long ultotal, long long ulnow) {
    if (ultotal > 0 && clientp) {
        void (^progBlock)(float) = (__bridge void(^)(float))clientp;
        if (progBlock) {
            float fraction = (float)ulnow / (float)ultotal;
            dispatch_async(dispatch_get_main_queue(), ^{
                progBlock(fraction);
            });
        }
    }
    return 0;
}

+ (void)uploadFile:(NSString *)filePath
             toURL:(NSString *)urlString
           headers:(NSDictionary *)headers
          progress:(void(^)(float progress))progress
        completion:(void(^)(NSData *responseData, NSInteger statusCode, NSError *error))completion {
    [self initialize];
    dispatch_async(sUploadQueue, ^{
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
        long long length = [attrs fileSize];
        if (length <= 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    NSError *err = [NSError errorWithDomain:@"NeoCurlTransport"
                                                       code:-1
                                                   userInfo:@{NSLocalizedDescriptionKey: @"File empty or unreadable"}];
                    completion(nil, 0, err);
                }
            });
            return;
        }

        void *file = curl_bridge_upload_open([filePath UTF8String]);
        if (!file) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    NSError *err = [NSError errorWithDomain:@"NeoCurlTransport"
                                                       code:-1
                                                   userInfo:@{NSLocalizedDescriptionKey: @"Failed to open file for upload"}];
                    completion(nil, 0, err);
                }
            });
            return;
        }

        CurlHandle h = curl_bridge_init();
        NSMutableData *respBuf = [NSMutableData data];

        curl_bridge_set_url(h, [urlString UTF8String]);
        NeoApplyTLS(h);
        curl_bridge_set_timeout(h, 0); // no hard timeout for media uploads
        curl_bridge_set_low_speed_abort(h, 1, 30); // abort only if stalled below 1 byte/s for 30s
        curl_bridge_set_write_fn(h, NeoWriteCallback, (__bridge void *)respBuf);

        void (^progCopy)(float) = [progress copy];
        if (progCopy) {
            curl_bridge_set_progress_fn(h, NeoUploadProgressCallback, (__bridge void *)progCopy);
        }

        void *headerList = NeoBuildHeaders(headers);
        if (headerList) {
            curl_bridge_set_headers(h, headerList);
        }

        curl_bridge_set_post_stream(h, file, length);

        NSLog(@"[NeoCurlTransport] Starting streaming upload of %lld bytes to %@", length, urlString);
        int rc = curl_bridge_perform(h);
        long statusCode = curl_bridge_response_code(h);

        curl_bridge_upload_close(file);
        if (headerList) {
            curl_bridge_headers_free(headerList);
        }
        curl_bridge_cleanup(h);

        dispatch_async(dispatch_get_main_queue(), ^{
            if (rc != 0) {
                const char *errStr = curl_bridge_strerror(rc);
                NSString *desc = errStr ? [NSString stringWithUTF8String:errStr] : [NSString stringWithFormat:@"curl error %d", rc];
                NSLog(@"[NeoCurlTransport] Upload failed with curl rc %d: %@ (HTTP %ld)", rc, desc, statusCode);
                NSError *err = [NSError errorWithDomain:@"NeoCurlTransport"
                                                   code:rc
                                               userInfo:@{NSLocalizedDescriptionKey: desc}];
                if (completion) completion(respBuf, statusCode, err);
            } else {
                NSLog(@"[NeoCurlTransport] Upload finished with HTTP %ld, received %lu bytes", statusCode, (unsigned long)[respBuf length]);
                if (completion) completion(respBuf, statusCode, nil);
            }
        });
    });
}

+ (void)uploadData:(NSData *)data
             toURL:(NSString *)urlString
           headers:(NSDictionary *)headers
        completion:(void(^)(NSData *responseData, NSInteger statusCode, NSError *error))completion {
    [self initialize];
    dispatch_async(sUploadQueue, ^{
        if (!data || [data length] == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    NSError *err = [NSError errorWithDomain:@"NeoCurlTransport"
                                                       code:-1
                                                   userInfo:@{NSLocalizedDescriptionKey: @"Data empty"}];
                    completion(nil, 0, err);
                }
            });
            return;
        }

        CurlHandle h = curl_bridge_init();
        NSMutableData *respBuf = [NSMutableData data];

        curl_bridge_set_url(h, [urlString UTF8String]);
        NeoApplyTLS(h);
        curl_bridge_set_timeout(h, 120);
        curl_bridge_set_low_speed_abort(h, 1, 30);
        curl_bridge_set_write_fn(h, NeoWriteCallback, (__bridge void *)respBuf);

        void *headerList = NeoBuildHeaders(headers);
        if (headerList) {
            curl_bridge_set_headers(h, headerList);
        }

        curl_bridge_set_post_body(h, [data bytes], (long)[data length]);

        int rc = curl_bridge_perform(h);
        long statusCode = curl_bridge_response_code(h);

        if (headerList) {
            curl_bridge_headers_free(headerList);
        }
        curl_bridge_cleanup(h);

        dispatch_async(dispatch_get_main_queue(), ^{
            if (rc != 0) {
                const char *errStr = curl_bridge_strerror(rc);
                NSString *desc = errStr ? [NSString stringWithUTF8String:errStr] : [NSString stringWithFormat:@"curl error %d", rc];
                NSLog(@"[NeoCurlTransport] postData failed with curl rc %d: %@ (HTTP %ld)", rc, desc, statusCode);
                NSError *err = [NSError errorWithDomain:@"NeoCurlTransport"
                                                   code:rc
                                               userInfo:@{NSLocalizedDescriptionKey: desc}];
                if (completion) completion(respBuf, statusCode, err);
            } else {
                if (completion) completion(respBuf, statusCode, nil);
            }
        });
    });
}

+ (void)fetchData:(NSString *)urlString
          headers:(NSDictionary *)headers
          timeout:(NSInteger)timeout
       completion:(void(^)(NSData *responseData, NSInteger statusCode, NSError *error))completion {
    [self initialize];
    dispatch_async(sRequestQueue, ^{
        CurlHandle h = curl_bridge_init();
        NSMutableData *respBuf = [NSMutableData data];

        curl_bridge_set_url(h, [urlString UTF8String]);
        NeoApplyTLS(h);
        curl_bridge_set_follow_redirects(h);
        curl_bridge_set_timeout(h, timeout > 0 ? timeout : 30);
        curl_bridge_set_write_fn(h, NeoWriteCallback, (__bridge void *)respBuf);

        void *headerList = NeoBuildHeaders(headers);
        if (headerList) {
            curl_bridge_set_headers(h, headerList);
        }

        int rc = curl_bridge_perform(h);
        long statusCode = curl_bridge_response_code(h);

        if (headerList) {
            curl_bridge_headers_free(headerList);
        }
        curl_bridge_cleanup(h);

        dispatch_async(dispatch_get_main_queue(), ^{
            if (rc != 0) {
                const char *errStr = curl_bridge_strerror(rc);
                NSString *desc = errStr ? [NSString stringWithUTF8String:errStr] : [NSString stringWithFormat:@"curl error %d", rc];
                NSError *err = [NSError errorWithDomain:@"NeoCurlTransport"
                                                   code:rc
                                               userInfo:@{NSLocalizedDescriptionKey: desc}];
                if (completion) completion(respBuf, statusCode, err);
            } else {
                if (completion) completion(respBuf, statusCode, nil);
            }
        });
    });
}

@end
