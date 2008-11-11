/* Copyright © 2007-2008, The Sequential Project
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

THIS SOFTWARE IS PROVIDED BY THE Sequential Project ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE Sequential Project BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "NSObjectAdditions.h"

BOOL PGIsLeopardOrLater(void)
{
	return floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4;
}
BOOL PGIsTigerOrLater(void)
{
	return floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_3;
}

@implementation NSObject (AEAdditions)

#pragma mark Instance Methods

- (void)AE_postNotificationName:(NSString *)aName
{
	[self AE_postNotificationName:aName userInfo:nil];
}
- (void)AE_postNotificationName:(NSString *)aName
        userInfo:(NSDictionary *)aDict
{
	[[NSNotificationCenter defaultCenter] postNotificationName:aName object:self userInfo:aDict];
}

#pragma mark -

- (void)AE_addObserver:(id)observer
        selector:(SEL)aSelector
        name:(NSString *)aName
{
	[[NSNotificationCenter defaultCenter] addObserver:observer selector:aSelector name:aName object:self];
}
- (void)AE_removeObserver
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}
- (void)AE_removeObserver:(id)observer
        name:(NSString *)aName
{
	[[NSNotificationCenter defaultCenter] removeObserver:observer name:aName object:self];
}

#pragma mark -

- (NSArray *)AE_asArray
{
	return [NSArray arrayWithObject:self];
}

#pragma mark NSMenuValidation Protocol

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	return [self respondsToSelector:[anItem action]];
}

@end

@implementation NSArray (AEArrayCreation)

- (NSArray *)AE_asArray
{
	return self;
}

@end
