#import "NeoReactionParser.h"

NSString *NeoReactionKey(NSString *emoji)
{
    return [[emoji stringByReplacingOccurrencesOfString:@"\uFE0F" withString:@""] stringByReplacingOccurrencesOfString:@"\uFE0E" withString:@""];
}

NSArray *NeoReactionItems(NSString *summary)
{
    if (summary.length == 0) return @[];

    NSMutableArray *orderedKeys = [[NSMutableArray alloc] init];
    NSMutableDictionary *emojiByKey = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *countByKey = [[NSMutableDictionary alloc] init];

    for (NSString *part in [summary componentsSeparatedByString:@"  "])
    {
        NSRange separator = [part rangeOfString:@" " options:NSBackwardsSearch];
        NSString *emoji = separator.location == NSNotFound ? part : [part substringToIndex:separator.location];
        NSInteger count = separator.location == NSNotFound ? 1 : MAX(1, [[part substringFromIndex:separator.location + 1] integerValue]);
        NSString *key = NeoReactionKey(emoji);
        if (key.length == 0) continue;

        if ([countByKey objectForKey:key] == nil)
        {
            [orderedKeys addObject:key];
            [emojiByKey setObject:emoji forKey:key];
            [countByKey setObject:[NSNumber numberWithInteger:count] forKey:key];
        }
        else
        {
            [countByKey setObject:[NSNumber numberWithInteger:MAX([[countByKey objectForKey:key] integerValue], count)] forKey:key];
        }
    }

    NSMutableArray *items = [[NSMutableArray alloc] init];
    for (NSString *key in orderedKeys)
    {
        [items addObject:@{
            @"emoji": [emojiByKey objectForKey:key],
            @"count": [countByKey objectForKey:key]
        }];
    }
    return items;
}

UIImage *NeoReactionPillImage(NSString *emoji, NSInteger count, BOOL selected)
{
    if (emoji.length == 0) return nil;

    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 128;
    });

    NSString *countText = count <= 1 ? nil : (count >= 1000 ? [NSString stringWithFormat:@"%dK", (int)MAX(1, count / 1000)] : [NSString stringWithFormat:@"%d", (int)count]);
    NSString *displayText = countText.length == 0 ? emoji : [NSString stringWithFormat:@"%@ %@", emoji, countText];
    NSString *cacheKey = [NSString stringWithFormat:@"%@/%d", displayText, selected ? 1 : 0];
    UIImage *image = [cache objectForKey:cacheKey];
    if (image != nil) return image;

    UIFont *font = [UIFont systemFontOfSize:12.0f];
    CGSize textSize = [displayText sizeWithFont:font];
    CGSize size = CGSizeMake(MAX(30.0f, MIN(160.0f, ceilf(textSize.width) + 14.0f)), 22.0f);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();

    UIColor *bgColor = selected ? [UIColor colorWithRed:0.0f green:0.48f blue:0.92f alpha:0.34f] : [UIColor colorWithWhite:0.0f alpha:0.10f];
    CGContextSetFillColorWithColor(context, bgColor.CGColor);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0.0f, 0.0f, size.width, size.height) cornerRadius:11.0f];
    CGContextAddPath(context, path.CGPath);
    CGContextFillPath(context);

    [[UIColor colorWithWhite:0.55f alpha:1.0f] set];
    if (countText.length == 0)
    {
        CGRect emojiRect = CGRectMake(7.0f, roundf((size.height - textSize.height) / 2.0f) + 1.0f, size.width - 14.0f, textSize.height);
        [emoji drawInRect:emojiRect withFont:font lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentCenter];
    }
    else
    {
        CGSize emojiSize = [emoji sizeWithFont:font];
        CGSize countSize = [countText sizeWithFont:font];
        CGFloat contentWidth = ceilf(emojiSize.width) + 3.0f + ceilf(countSize.width);
        CGFloat contentX = roundf((size.width - contentWidth) / 2.0f);
        [emoji drawInRect:CGRectMake(contentX, roundf((size.height - emojiSize.height) / 2.0f) + 1.0f, ceilf(emojiSize.width), emojiSize.height) withFont:font lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentLeft];
        [countText drawInRect:CGRectMake(contentX + ceilf(emojiSize.width) + 3.0f, roundf((size.height - countSize.height) / 2.0f), ceilf(countSize.width), countSize.height) withFont:font lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentLeft];
    }

    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [cache setObject:image forKey:cacheKey];
    return image;
}
