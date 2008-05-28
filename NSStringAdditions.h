#import <Cocoa/Cocoa.h>

@interface NSString (AEAdditions)

- (NSComparisonResult)AE_localizedCaseInsensitiveNumericCompare:(NSString *)aString;
- (int)AE_fileDescriptor; // Currently always uses O_EVTONLY.
- (NSString *)AE_firstPathComponent;
- (NSURL *)AE_fileURL;
- (NSString *)AE_displayName;
- (NSArray *)AE_searchTerms;
- (BOOL)AE_matchesSearchTerms:(NSArray *)terms;

@end
