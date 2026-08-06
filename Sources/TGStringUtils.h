#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

int32_t murMurHash32(NSString *string);
int32_t murMurHashBytes32(void *bytes, int length);

bool TGIsRTL(void);
bool TGIsArabic(void);
bool TGIsKorean(void);
bool TGIsLocaleArabic(void);

#ifdef __cplusplus
}
#endif

@interface TGStringUtils : NSObject

+ (BOOL)stringContainsEmojiOnly:(NSString *)string length:(NSUInteger *)length;

+ (NSString *)stringWithLocalizedNumber:(NSInteger)number;
+ (NSString *)stringWithLocalizedNumberCharacters:(NSString *)string;

+ (NSString *)stringForFileSize:(NSUInteger)size precision:(NSInteger)precision;

+ (NSString *)initialsForFirstName:(NSString *)firstName lastName:(NSString *)lastName single:(BOOL)single;
+ (NSString *)initialForGroupName:(NSString *)groupName;

+ (NSString *)integerValueFormat:(NSString *)prefix value:(NSInteger)value;

+ (NSString *)md5WithString:(NSString *)string;

@end
