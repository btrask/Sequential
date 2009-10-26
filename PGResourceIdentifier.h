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
// Models
@class PGDisplayableIdentifier;
@class PGSubscription;

extern NSString *const PGDisplayableIdentifierIconDidChangeNotification;
extern NSString *const PGDisplayableIdentifierDisplayNameDidChangeNotification;

enum {
	PGLabelNone   = 0,
	PGLabelRed    = 6,
	PGLabelOrange = 7,
	PGLabelYellow = 5,
	PGLabelGreen  = 2,
	PGLabelBlue   = 4,
	PGLabelPurple = 3,
	PGLabelGray   = 1
};
typedef UInt8 PGLabelColor;

@interface PGResourceIdentifier : NSObject <NSCoding>

+ (id)resourceIdentifierWithURL:(NSURL *)URL;
+ (id)resourceIdentifierWithAliasData:(const uint8_t *)data length:(NSUInteger)length; // For backward compatability.

@property(readonly) PGResourceIdentifier *identifier;
@property(readonly) PGDisplayableIdentifier *displayableIdentifier;
@property(readonly) PGResourceIdentifier *superidentifier;
@property(readonly) PGResourceIdentifier *rootIdentifier;
@property(readonly) NSURL *URL; // Equivalent to -URLByFollowingAliases:NO.
@property(readonly) NSInteger index;
@property(readonly) BOOL hasTarget;
@property(readonly) BOOL isFileIdentifier;

- (PGResourceIdentifier *)subidentifierWithIndex:(NSInteger)index;

- (NSURL *)superURLByFollowingAliases:(BOOL)flag; // Our URL, or our superidentifier's otherwise.
- (NSURL *)URLByFollowingAliases:(BOOL)flag;
- (BOOL)getRef:(out FSRef *)outRef byFollowingAliases:(BOOL)flag;

- (PGSubscription *)subscriptionWithDescendents:(BOOL)flag;

@end

@interface PGDisplayableIdentifier : PGResourceIdentifier <NSCoding>
{
	@private
	PGResourceIdentifier *_identifier;
	BOOL _postsNotifications;
	NSImage *_icon;
	NSString *_naturalDisplayName;
	NSString *_customDisplayName;
}

@property(assign) BOOL postsNotifications;
@property(retain) NSImage *icon;
@property(readonly) NSString *displayName;
@property(copy) NSString *customDisplayName;
@property(copy) NSString *naturalDisplayName; // The name from the filesystem or raw address of the URL.
@property(readonly) PGLabelColor labelColor;

- (NSAttributedString *)attributedStringWithAncestory:(BOOL)flag;
- (void)noteNaturalDisplayNameDidChange;

@end

@interface NSURL(PGResourceIdentifierCreation)

@property(readonly) PGResourceIdentifier *PG_resourceIdentifier;
@property(readonly) PGDisplayableIdentifier *PG_displayableIdentifier;

@end
