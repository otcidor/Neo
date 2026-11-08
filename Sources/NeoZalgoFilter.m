#import "NeoZalgoFilter.h"
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static inline int is_combining_mark(uint32_t cp) {
    return (cp >= 0x0300u && cp <= 0x036Fu) ||
           (cp >= 0x1AB0u && cp <= 0x1AFFu) ||
           (cp >= 0x1DC0u && cp <= 0x1DFFu) ||
           (cp >= 0x20D0u && cp <= 0x20FFu) ||
           (cp >= 0xFE20u && cp <= 0xFE2Fu);
}

static size_t decode_utf8(const unsigned char *s, size_t left, uint32_t *cp) {
    if (left >= 1 && s[0] < 0x80u) {
        *cp = s[0];
        return 1;
    }
    if (left >= 2 && (s[0] & 0xE0u) == 0xC0u && (s[1] & 0xC0u) == 0x80u) {
        *cp = ((uint32_t)(s[0] & 0x1Fu) << 6) | (s[1] & 0x3Fu);
        return *cp >= 0x80u ? 2 : 0;
    }
    if (left >= 3 && (s[0] & 0xF0u) == 0xE0u && (s[1] & 0xC0u) == 0x80u && (s[2] & 0xC0u) == 0x80u) {
        *cp = ((uint32_t)(s[0] & 0x0Fu) << 12) | ((uint32_t)(s[1] & 0x3Fu) << 6) | (s[2] & 0x3Fu);
        return *cp >= 0x800u && (*cp < 0xD800u || *cp > 0xDFFFu) ? 3 : 0;
    }
    if (left >= 4 && (s[0] & 0xF8u) == 0xF0u && (s[1] & 0xC0u) == 0x80u && (s[2] & 0xC0u) == 0x80u && (s[3] & 0xC0u) == 0x80u) {
        *cp = ((uint32_t)(s[0] & 0x07u) << 18) | ((uint32_t)(s[1] & 0x3Fu) << 12) | ((uint32_t)(s[2] & 0x3Fu) << 6) | (s[3] & 0x3Fu);
        return *cp >= 0x10000u && *cp <= 0x10FFFFu ? 4 : 0;
    }
    return 0;
}

size_t NeoZalgoFilterCString(const char *in, char *out, size_t cap) {
    const unsigned char *s = (const unsigned char *)in;
    size_t len, at = 0, used = 0;
    int marks = 0;
    
    if (out && cap) out[0] = 0;
    if (!in || !out || !cap) return (size_t)-1;
    
    len = strlen(in);
    if (cap < len + 1) return (size_t)-1;
    
    while (at < len) {
        uint32_t cp = 0;
        size_t n = decode_utf8(s + at, len - at, &cp);
        if (!n) {
            out[used++] = (char)s[at++];
            marks = 0;
            continue;
        }
        if (is_combining_mark(cp)) {
            if (marks >= NEO_ZALGO_MARKS_MAX) {
                at += n;
                continue;
            }
            ++marks;
        } else {
            marks = 0;
        }
        memcpy(out + used, s + at, n);
        used += n;
        at += n;
    }
    out[used] = 0;
    return used;
}

NSString *NeoSanitizeZalgoText(NSString *input) {
    if (!input || input.length <= 1) return input;
    
    // Fast path: pure ASCII cannot contain Unicode combining diacritics
    if ([input canBeConvertedToEncoding:NSASCIIStringEncoding]) {
        return input;
    }
    
    const char *utf8 = [input UTF8String];
    if (!utf8) return input;
    
    size_t len = strlen(utf8);
    char stackBuf[1024];
    char *buf = (len < sizeof(stackBuf)) ? stackBuf : (char *)malloc(len + 1);
    if (!buf) return input;
    
    size_t used = NeoZalgoFilterCString(utf8, buf, len + 1);
    NSString *result = input;
    if (used != (size_t)-1 && used < len) {
        NSString *sanitized = [NSString stringWithUTF8String:buf];
        if (sanitized) {
            result = sanitized;
        }
    }
    
    if (buf != stackBuf) {
        free(buf);
    }
    return result;
}
