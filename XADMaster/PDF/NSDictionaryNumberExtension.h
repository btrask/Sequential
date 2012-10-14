#import <Foundation/Foundation.h>

@interface NSDictionary (NumberExtension)

-(int)intValueForKey:(NSString *)key default:(int)def;
-(unsigned int)unsignedIntValueForKey:(NSString *)key default:(unsigned int)def;
-(BOOL)boolValueForKey:(NSString *)key default:(BOOL)def;
-(float)floatValueForKey:(NSString *)key default:(float)def;
-(double)doubleValueForKey:(NSString *)key default:(double)def;

-(NSString *)stringForKey:(NSString *)key default:(NSString *)def;
-(NSArray *)arrayForKey:(NSString *)key;

@end
