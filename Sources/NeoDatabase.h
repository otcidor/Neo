#import <Foundation/Foundation.h>

@class MatrixMessage;

@interface NeoDatabase : NSObject

+ (instancetype)sharedDatabase;

- (void)saveMessage:(MatrixMessage *)message rawDict:(NSDictionary *)rawDict inRoom:(NSString *)roomId;
- (void)saveMessagesBatch:(NSArray *)eventDicts inRoom:(NSString *)roomId;

- (NSArray *)loadMessagesForRoom:(NSString *)roomId limit:(NSInteger)limit;
- (void)deleteMessagesForRoom:(NSString *)roomId;
- (void)clearAll;

@end
