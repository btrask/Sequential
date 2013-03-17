#import <Foundation/Foundation.h>


@interface CSJSONPrinter:NSObject
{
	int indentlevel;
	NSString *indentstring;
	BOOL asciimode;

	BOOL needseparator;
}

-(id)init;
-(void)dealloc;

-(void)setIndentString:(NSString *)string;
-(void)setASCIIMode:(BOOL)ascii;

-(void)printObject:(id)object;

-(void)printNull;
-(void)printNumber:(NSNumber *)number;
-(void)printString:(NSString *)string;
-(void)printData:(NSData *)data;
-(void)printValue:(NSValue *)value;
-(void)printArray:(NSArray *)array;
-(void)printDictionary:(NSDictionary *)dictionary;

-(void)startPrintingArray;
-(void)startPrintingArrayObject;
-(void)endPrintingArrayObject;
-(void)endPrintingArray;
-(void)printArrayObject:(id)object;
-(void)printArrayObjects:(NSArray *)array;

-(void)startPrintingDictionary;
-(void)printDictionaryKey:(id)key;
-(void)startPrintingDictionaryObject;
-(void)endPrintingDictionaryObject;
-(void)endPrintingDictionary;
-(void)printDictionaryObject:(id)object;
-(void)printDictionaryKeysAndObjects:(NSDictionary *)dictionary;

-(void)startNewLine;
-(void)printSeparatorIfNeeded;

-(NSString *)stringByEscapingString:(NSString *)string;
-(NSString *)stringByEncodingBytes:(const uint8_t *)bytes length:(int)length;

@end
