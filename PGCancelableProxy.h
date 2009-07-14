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
#import <Cocoa/Cocoa.h>

@interface PGCancelableProxy : NSObject // Only objects support NSThreadPerformAdditions.
{
	@private
	id _target;
	Class _class;
	id _storage;
	BOOL _allowOnce;
}

+ (id)storage;

- (id)initWithTarget:(id)target class:(Class)class allowOnce:(BOOL)flag storage:(id)storage;

@end

@interface NSObject (PGCancelable) // These methods guarantee that either the entire method will be performed before anything can cancel it, or the method won't be performed at all. If the method doesn't get invoked, 0 (cast as whatever the return type is) is returned.

+ (id)PG_performOn:(id)target allowOnce:(BOOL)flag withStorage:(id)storage; // Send this to the class that defines the message you intend to invoke.
- (void)PG_allowPerformsWithStorage:(id)storage;
- (void)PG_cancelPerformsWithStorage:(id)storage;

@end
