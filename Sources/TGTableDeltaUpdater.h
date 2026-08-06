#import <Foundation/Foundation.h>

@protocol TGTableItem <NSObject>
- (NSString *)uniqueIdentifier;
@end

@interface TGTableAlignment : NSObject
@property (nonatomic, assign) NSInteger pos;
@property (nonatomic, assign) NSInteger len;
@end

@interface TGTableDeltaUpdater : NSObject

+ (void)replaceItemsInTable:(NSArray<id<TGTableItem>> *)oldItems
               withNewItems:(NSArray<id<TGTableItem>> *)newItems
               applyDeletes:(void(^)(NSArray<TGTableAlignment *> *))applyDeletes
               applyInserts:(void(^)(NSArray<TGTableAlignment *> *))applyInserts;

@end
