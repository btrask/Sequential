/* Copyright © 2007-2008 The Sequential Project. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal with the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:
1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimers.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimers in the
   documentation and/or other materials provided with the distribution.
3. Neither the name of The Sequential Project nor the names of its
   contributors may be used to endorse or promote products derived from
   this Software without specific prior written permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS WITH THE SOFTWARE. */
#import <Cocoa/Cocoa.h>

#define PGCommonRunLoopsMode (NSString *)kCFRunLoopCommonModes

extern BOOL PGIsLeopardOrLater(void);
extern BOOL PGIsTigerOrLater(void);

@interface NSObject (AEAdditions)

- (void)AE_postNotificationName:(NSString *)aName;
- (void)AE_postNotificationName:(NSString *)aName userInfo:(NSDictionary *)aDict;

- (void)AE_addObserver:(id)observer selector:(SEL)aSelector name:(NSString *)aName;
- (void)AE_removeObserver;
- (void)AE_removeObserver:(id)observer name:(NSString *)aName;

@end

#if defined(NS_BLOCK_ASSERTIONS)
	#define PGAssertNotReached(desc)
	#define PGCAssertNotReached(desc)
#else
	#define PGAssertNotReached(desc) [[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self file:[NSString stringWithUTF8String:__FILE__] lineNumber:__LINE__ description:(desc)]
	#define PGCAssertNotReached(desc) [[NSAssertionHandler currentHandler] handleFailureInFunction:[NSString stringWithUTF8String:__PRETTY_FUNCTION__] file:[NSString stringWithUTF8String:__FILE__] lineNumber:__LINE__ description:(desc)]
#endif
