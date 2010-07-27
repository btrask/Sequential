#import <Foundation/Foundation.h>

@interface NSString (Printing)

+(int)terminalWidth;

-(void)print;
-(void)printToFile:(FILE *)fh;

-(NSString *)stringByEscapingControlCharacters;

-(NSArray *)linesWrappedToWidth:(int)width;

@end
