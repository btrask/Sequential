/* Copyright © 2007-2009, The Sequential Project
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the the Sequential Project nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE SEQUENTIAL PROJECT ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE SEQUENTIAL PROJECT BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import <Foundation/Foundation.h>

// Other Sources
#import "PGGeometryTypes.h"

NS_INLINE BOOL PGEqualObjects(id<NSObject> a, id<NSObject> b)
{
	if(a == b) return YES;
	if(!a || !b) return NO;
	return [a isEqual:b];
}
#ifndef NSAppKitVersionNumber10_5
#define NSAppKitVersionNumber10_5 949
#endif
NS_INLINE BOOL PGIsSnowLeopardOrLater(void)
{
       return floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_5;
}

extern NSString *PGOSTypeToStringQuoted(OSType, BOOL);
extern OSType PGOSTypeFromString(NSString *);

@interface NSAffineTransform(PGFoundationAdditions)

+ (id)PG_transformWithRect:(inout NSRectPointer)rectPtr orientation:(PGOrientation)orientation;
+ (id)PG_counterflipWithRect:(inout NSRectPointer)rectPtr;

@end

@interface NSArray(PGFoundationAdditions)

+ (id)PG_arrayWithContentsOfArrays:(NSArray *)first, ... NS_REQUIRES_NIL_TERMINATION;

- (NSArray *)PG_arrayWithUniqueObjects;
- (void)PG_addObjectObserver:(id)observer selector:(SEL)aSelector name:(NSString *)aName;
- (void)PG_removeObjectObserver:(id)observer name:(NSString *)aName;

@end

@interface NSDate(PGFoundationAdditions)

- (BOOL)PG_isAfter:(NSDate *)date;
- (NSString *)PG_localizedStringWithDateStyle:(CFDateFormatterStyle)dateStyle timeStyle:(CFDateFormatterStyle)timeStyle;

@end

@interface NSError(PGFoundationAdditions)

+ (id)PG_errorWithDomain:(NSString *)domain code:(NSInteger)code localizedDescription:(NSString *)desc userInfo:(NSDictionary *)dict;

@end

@interface NSMutableDictionary(PGFoundationAdditions)

- (void)PG_setObject:(id)obj forKey:(id)key;

@end

@interface NSNumber(PGFoundationAdditions)

- (NSString *)PG_localizedStringAsBytes;

@end

@interface NSObject(PGFoundationAdditions)

- (void)PG_postNotificationName:(NSString *)aName;
- (void)PG_postNotificationName:(NSString *)aName userInfo:(NSDictionary *)aDict;

- (void)PG_addObserver:(id)observer selector:(SEL)aSelector name:(NSString *)aName;
- (void)PG_removeObserver;
- (void)PG_removeObserver:(id)observer name:(NSString *)aName;

- (NSArray *)PG_asArray;

+ (void *)PG_useInstance:(BOOL)instance implementationFromClass:(Class)class forSelector:(SEL)aSel;

@end

@interface NSProcessInfo(PGFoundationAdditions)

- (void)PG_enableSuddenTermination;
- (void)PG_disableSuddenTermination;

@end

@interface NSScanner(PGFoundationAdditions)

- (BOOL)PG_scanFromString:(NSString *)start toString:(NSString *)end intoString:(out NSString **)outString;

@end

@interface NSString(PGFoundationAdditions)

- (NSComparisonResult)PG_localizedCaseInsensitiveNumericCompare:(NSString *)aString;
- (NSString *)PG_stringByReplacingOccurrencesOfCharactersInSet:(NSCharacterSet *)set withString:(NSString *)replacement;

- (NSString *)PG_firstPathComponent;
- (NSURL *)PG_fileURL;
- (NSString *)PG_displayName;

- (NSArray *)PG_searchTerms;
- (BOOL)PG_matchesSearchTerms:(NSArray *)terms;

@end

@interface NSURL(PGFoundationAdditions)

+ (NSURL *)PG_URLWithString:(NSString *)aString;

- (NSImage *)PG_icon; // Returns the URL image for non-file URLs.

@end

@interface NSUserDefaults(PGFoundationAdditions)

- (id)PG_decodedObjectForKey:(NSString *)defaultName;
- (void)PG_encodeObject:(id)value forKey:(NSString *)defaultName;

@end
