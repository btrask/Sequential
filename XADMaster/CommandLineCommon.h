#import <Foundation/Foundation.h>

#import "XADArchiveParser.h"

BOOL IsListRequest(NSString *encoding);
void PrintEncodingList();

NSString *ShortInfoLineForEntryWithDictionary(NSDictionary *dict);
NSString *MediumInfoLineForEntryWithDictionary(NSDictionary *dict);
NSString *LongInfoLineForEntryWithDictionary(NSDictionary *dict,XADArchiveParser *parser);
NSString *CompressionNameExplanationForLongInfo();

BOOL IsInteractive();
int GetPromptCharacter();
NSString *AskForPassword(NSString *prompt);
