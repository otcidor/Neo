#import <Foundation/Foundation.h>

typedef void (^MatrixCompletion)(NSDictionary *response, NSError *error);

@interface MatrixAPIClient : NSObject

@property (nonatomic, copy) NSString *homeserver;
@property (nonatomic, copy) NSString *accessToken;
@property (nonatomic, copy) NSString *deviceId;
@property (nonatomic, copy) NSString *userId;

+ (instancetype)sharedClient;

- (void)loginWithUser:(NSString *)user
             password:(NSString *)password
           completion:(MatrixCompletion)completion;

- (void)getJoinedRoomsWithCompletion:(MatrixCompletion)completion;

- (void)syncWithSince:(NSString *)since
              timeout:(NSInteger)timeout
           completion:(MatrixCompletion)completion;

- (void)sendMessage:(NSString *)body
             roomId:(NSString *)roomId
         completion:(MatrixCompletion)completion;

- (void)editMessage:(NSString *)newBody
             roomId:(NSString *)roomId
            eventId:(NSString *)eventId
         completion:(MatrixCompletion)completion;

- (void)sendReaction:(NSString *)emoji
              roomId:(NSString *)roomId
             eventId:(NSString *)eventId
          completion:(MatrixCompletion)completion;

- (void)redactMessage:(NSString *)roomId
              eventId:(NSString *)eventId
           completion:(MatrixCompletion)completion;

- (void)sendReadReceipt:(NSString *)roomId
                 eventId:(NSString *)eventId
              completion:(MatrixCompletion)completion;

- (void)sendVideoMessage:(NSString *)videoURL
                  roomId:(NSString *)roomId
                thumbnail:(NSString *)thumbnailURL
                duration:(NSInteger)duration
                   width:(CGFloat)width
                  height:(CGFloat)height
                    size:(NSInteger)size
              completion:(MatrixCompletion)completion;

- (void)uploadData:(NSData *)data
          mimeType:(NSString *)mimeType
           filename:(NSString *)filename
        completion:(void(^)(NSString *contentURI, NSError *error))completion;

- (void)sendImageMessage:(NSString *)imageURL
                   roomId:(NSString *)roomId
                  caption:(NSString *)caption
               completion:(MatrixCompletion)completion;

- (void)registerPusherWithPushKey:(NSString *)pushKey
                        completion:(MatrixCompletion)completion;

- (void)getRoomMessages:(NSString *)roomId
             completion:(MatrixCompletion)completion;

- (void)getMembersForRoom:(NSString *)roomId
               completion:(void(^)(NSDictionary *members, NSError *error))completion;

- (NSMutableURLRequest *)requestWithPath:(NSString *)path method:(NSString *)method;
- (void)saveCredentials;
- (void)clearCredentials;

@property (nonatomic, strong) NSCache *messageCache;
@property (nonatomic, strong) NSCache *memberCache;
@property (nonatomic, strong) NSCache *avatarCache;
@property (nonatomic, copy) NSString *nextBatchToken;

- (NSArray *)cachedMessagesForRoom:(NSString *)roomId;
- (void)cacheMessages:(NSArray *)messages forRoom:(NSString *)roomId;
- (NSDictionary *)cachedMembersForRoom:(NSString *)roomId;
- (void)cacheMembers:(NSDictionary *)members forRoom:(NSString *)roomId;

- (NSString *)mxcURLToHTTP:(NSString *)mxcURL;
- (void)downloadImageFromMXC:(NSString *)mxcURL
                   completion:(void(^)(UIImage *image, NSError *error))completion;

- (void)uploadImage:(UIImage *)image
         completion:(void(^)(NSString *contentURI, NSError *error))completion;

// Local room name overrides (cached in NSUserDefaults)
+ (NSString *)localNameForRoomId:(NSString *)roomId;
+ (void)setLocalName:(NSString *)name forRoomId:(NSString *)roomId;

@end
