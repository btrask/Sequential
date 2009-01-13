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
/*
 Author: MCF

 Copyright: © Copyright 2002 Apple Computer, Inc. All rights reserved.

 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc.
 ("Apple") in consideration of your agreement to the following terms, and your
 use, installation, modification or redistribution of this Apple software
 constitutes acceptance of these terms.  If you do not agree with these terms, 
 please do not use, install, modify or redistribute this Apple software.

 In consideration of your agreement to abide by the following terms, and subject
 to these terms, Apple grants you a personal, non-exclusive license, under Apple’s
 copyrights in this original Apple software (the "Apple Software"), to use, 
 reproduce, modify and redistribute the Apple Software, with or without
 modifications, in source and/or binary forms; provided that if you redistribute
 the Apple Software in its entirety and without modifications, you must retain
 this notice and the following text and disclaimers in all such redistributions of
 the Apple Software.  Neither the name, trademarks, service marks or logos of
 Apple Computer, Inc. may be used to endorse or promote products derived from the
 Apple Software without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or implied, 
 are granted by Apple herein, including but not limited to any patent rights that
 may be infringed by your derivative works or by other works in which the Apple
 Software may be incorporated.

 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
 WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
 WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
 COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
 OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT
 (INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
#import "NSScreenAdditions.h"

@implementation NSScreen (AEAdditions)

+ (NSScreen *)AE_mainScreen
{
	NSArray *const screens = [self screens];
	return [screens count] ? [screens objectAtIndex:0] : nil;
}
- (BOOL)AE_setDesktopPicturePath:(NSString *)path
{
	NSAssert([NSScreen AE_mainScreen] == self, @"The desktop picture cannot be set for other screens.");

	FSRef ref;
	if(FSPathMakeRef((UInt8 const *)[path fileSystemRepresentation], &ref, NULL) != noErr) return NO;
	AliasHandle aliasHandle = NULL;
	if(FSNewAliasMinimal(&ref, &aliasHandle) != noErr || !aliasHandle) return NO;

	// Now we create an AEDesc containing the alias to the image.
	SInt8 const handleState = HGetState((Handle)aliasHandle);
	HLock((Handle)aliasHandle);
	AEDesc descriptor = {typeNull, NULL};
	OSErr const descErr = AECreateDesc(typeAlias, *aliasHandle, GetHandleSize((Handle)aliasHandle), &descriptor);
	HSetState((Handle)aliasHandle, handleState);
	DisposeHandle((Handle)aliasHandle);
	if(noErr != descErr) return NO;

	OSType const sig = 'MACS'; // The app signature for the Finder.
	AppleEvent event;
	if(AEBuildAppleEvent(kAECoreSuite, kAESetData, typeApplSignature, &sig, sizeof(OSType), kAutoGenerateReturnID, kAnyTransactionID, &event, NULL, "'----':'obj '{want:type(prop), form:prop, seld:type('dpic'), from:'null'()}, data:(@)", &descriptor) != noErr) return NO;

	// Finally we can go ahead and send the Apple Event using AESend.
	AppleEvent reply = {typeNull, NULL};
	OSErr const sendErr = AESend(&event, &reply, kAENoReply, kAENormalPriority, kAEDefaultTimeout, NULL, NULL);
	AEDisposeDesc(&event);
	return noErr == sendErr;
}

@end
