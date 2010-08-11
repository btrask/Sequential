/* Copyright © 2010, The Sequential Project
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
@class PGResourceIdentifier;

@interface PGDataProvider : NSObject <NSCopying>

@property(readonly) PGResourceIdentifier *identifier;
@property(readonly) NSURLResponse *response;
// TODO: Add -fileName/-displayableName/-attributedString properties.

@property(readonly) NSData *data;
@property(readonly) NSDate *dateModified;
@property(readonly) NSDate *dateCreated;

@property(readonly) NSString *UTIType;
@property(readonly) NSString *MIMEType;
@property(readonly) OSType typeCode;
@property(readonly) NSString *extension;

@property(readonly) NSImage *icon;
@property(readonly) NSString *kindString;
@property(readonly) BOOL hasData;
@property(readonly) NSData *fourCCData;
@property(readonly) NSNumber *dataLength;

@end

@interface PGDataProvider(PGDataProviderCreation)

+ (id)providerWithResourceIdentifier:(PGResourceIdentifier *)ident displayableName:(NSString *)name;
+ (id)providerWithResourceIdentifier:(PGResourceIdentifier *)ident;
+ (id)providerWithURLResponse:(NSURLResponse *)response data:(NSData *)data;

@end

@protocol PGDataProviderCustomizing

@optional
+ (PGDataProvider *)customDataProviderWithResourceIdentifier:(PGResourceIdentifier *)ident displayableName:(NSString *)name;
+ (PGDataProvider *)customDataProviderWithURLResponse:(NSURLResponse *)response data:(NSData *)data;

@end
