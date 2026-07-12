#import <Foundation/Foundation.h>

typedef enum {
    SpaceThemeDefault = 0,
    SpaceThemeWhatsApp,
    SpaceThemeTelegram,
    SpaceThemeDiscord,
    SpaceThemeInstagram
} SpaceTheme;

@interface MatrixRoom : NSObject
@property (nonatomic, copy) NSString *roomId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSInteger memberCount;
@property (nonatomic, copy) NSString *lastMessage;
@property (nonatomic, strong) NSDate *lastMessageDate;
@property (nonatomic, assign) SpaceTheme theme;
@property (nonatomic, assign) NSInteger unreadCount;
@property (nonatomic, copy) NSString *lastMessageSender;
- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (void)updateNameFromStateEvents:(NSArray *)stateEvents timelineEvents:(NSArray *)timelineEvents;
+ (NSString *)displayNameForRoomId:(NSString *)roomId fromSyncData:(NSDictionary *)roomData;
@end

@interface MatrixMessage : NSObject
@property (nonatomic, copy) NSString *eventId;
@property (nonatomic, copy) NSString *sender;
@property (nonatomic, copy) NSString *body;
@property (nonatomic, copy) NSString *msgType;
@property (nonatomic, copy) NSString *imageURL;
@property (nonatomic, assign) CGFloat imageWidth;
@property (nonatomic, assign) CGFloat imageHeight;
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, strong) UIImage *cachedImage;
@property (nonatomic, copy) NSString *roomId;
@property (nonatomic, assign) BOOL isRedacted;
@property (nonatomic, strong) NSMutableDictionary *reactions;
@property (nonatomic, copy) NSString *relatedEventId;
@property (nonatomic, assign) BOOL isEdit;
@property (nonatomic, copy) NSString *audioURL;
@property (nonatomic, strong) NSNumber *audioDuration;
@property (nonatomic, copy) NSString *videoURL;
@property (nonatomic, copy) NSString *videoThumbnailURL;
@property (nonatomic, strong) NSNumber *videoDuration;
@property (nonatomic, assign) CGFloat videoWidth;
@property (nonatomic, assign) CGFloat videoHeight;
@property (nonatomic, strong) UIImage *cachedVideoThumbnail;
- (instancetype)initWithDictionary:(NSDictionary *)dict roomId:(NSString *)roomId;
@end

@interface MatrixUser : NSObject
@property (nonatomic, copy) NSString *userId;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *avatarUrl;
- (instancetype)initWithDictionary:(NSDictionary *)dict;
@end

@interface DateSeparator : NSObject
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, copy) NSString *label;
- (instancetype)initWithDate:(NSDate *)date;
@end

@interface MatrixSpace : NSObject
@property (nonatomic, copy) NSString *spaceId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) SpaceTheme theme;
@property (nonatomic, strong) NSMutableArray *childRoomIds;
- (instancetype)initWithDictionary:(NSDictionary *)dict;
@end
