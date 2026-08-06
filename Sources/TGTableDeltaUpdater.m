#import "TGTableDeltaUpdater.h"

@implementation TGTableAlignment
@end

@implementation TGTableDeltaUpdater

+ (NSInteger **)lcsTableForA:(NSArray<id<TGTableItem>> *)a b:(NSArray<id<TGTableItem>> *)b {
    NSInteger m = [a count];
    NSInteger n = [b count];
    NSInteger **t = (NSInteger **)malloc((m + 1) * sizeof(NSInteger *));
    for (NSInteger i = 0; i <= m; i++) {
        t[i] = (NSInteger *)calloc(n + 1, sizeof(NSInteger));
    }
    for (NSInteger i = 1; i <= m; i++) {
        for (NSInteger j = 1; j <= n; j++) {
            if ([[a[i - 1] uniqueIdentifier] isEqualToString:[b[j - 1] uniqueIdentifier]]) {
                t[i][j] = t[i - 1][j - 1] + 1;
            } else {
                t[i][j] = MAX(t[i - 1][j], t[i][j - 1]);
            }
        }
    }
    return t;
}

+ (void)freeLcsTable:(NSInteger **)t m:(NSInteger)m {
    for (NSInteger i = 0; i <= m; i++) free(t[i]);
    free(t);
}

+ (void)replaceItemsInTable:(NSArray<id<TGTableItem>> *)oldItems
               withNewItems:(NSArray<id<TGTableItem>> *)newItems
               applyDeletes:(void(^)(NSArray<TGTableAlignment *> *))applyDeletes
               applyInserts:(void(^)(NSArray<TGTableAlignment *> *))applyInserts {
    NSInteger m = [oldItems count];
    NSInteger n = [newItems count];

    NSInteger **t = [self lcsTableForA:oldItems b:newItems];

    // Backtrack LCS to mark kept items
    BOOL *keptOld = (BOOL *)calloc(m, sizeof(BOOL));
    BOOL *keptNew = (BOOL *)calloc(n, sizeof(BOOL));

    NSInteger i = m, j = n;
    while (i > 0 && j > 0) {
        if ([[oldItems[i - 1] uniqueIdentifier] isEqualToString:[newItems[j - 1] uniqueIdentifier]]) {
            keptOld[i - 1] = YES;
            keptNew[j - 1] = YES;
            i--; j--;
        } else if (t[i - 1][j] >= t[i][j - 1]) {
            i--;
        } else {
            j--;
        }
    }
    [self freeLcsTable:t m:m];

    // Build delete alignments (consecutive runs)
    NSMutableArray *deletes = [NSMutableArray array];
    for (NSInteger idx = 0; idx < m; ) {
        if (!keptOld[idx]) {
            NSInteger start = idx;
            while (idx < m && !keptOld[idx]) idx++;
            TGTableAlignment *al = [[TGTableAlignment alloc] init];
            al.pos = start;
            al.len = idx - start;
            [deletes addObject:al];
        } else {
            idx++;
        }
    }

    // Build insert alignments (consecutive runs)
    NSMutableArray *inserts = [NSMutableArray array];
    for (NSInteger idx = 0; idx < n; ) {
        if (!keptNew[idx]) {
            NSInteger start = idx;
            while (idx < n && !keptNew[idx]) idx++;
            TGTableAlignment *al = [[TGTableAlignment alloc] init];
            al.pos = start;
            al.len = idx - start;
            [inserts addObject:al];
        } else {
            idx++;
        }
    }

    free(keptOld);
    free(keptNew);

    if (applyDeletes) applyDeletes(deletes);
    if (applyInserts) applyInserts(inserts);
}

@end
