#import <Foundation/Foundation.h>

#define NEO_ZALGO_MARKS_MAX 2

#ifdef __cplusplus
extern "C" {
#endif

size_t NeoZalgoFilterCString(const char *in, char *out, size_t cap);

#ifdef __cplusplus
}
#endif

NSString *NeoSanitizeZalgoText(NSString *input);
