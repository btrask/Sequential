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
#import "PGInspectorPanelController.h"

// Models
#import "PGNode.h"
#import "PGResourceAdapter.h"

// Controllers
#import "PGDocumentController.h"
#import "PGDisplayController.h"

// Other Sources
#import "PGFoundationAdditions.h"

@interface NSObject(PGAdditions)

- (id)PG_replacementUsingObject:(id)replacement preserveUnknown:(BOOL)preserve getTopLevelKey:(out id *)outKey;

@end

@interface NSDictionary(PGAdditions)

- (NSDictionary *)PG_flattenedDictionary;

@end

@implementation PGInspectorPanelController

#pragma mark -PGInspectorPanelController

- (IBAction)changeSearch:(id)sender
{
	NSMutableDictionary *const matchingProperties = [NSMutableDictionary dictionary];
	NSArray *const terms = [[searchField stringValue] PG_searchTerms];
	for(NSString *const label in _imageProperties) {
		if(![label PG_matchesSearchTerms:terms]) continue;
		NSString *const value = [_imageProperties objectForKey:label];
		if([[value description] PG_matchesSearchTerms:terms]) [matchingProperties setObject:value forKey:label];
	}
	[_matchingProperties release];
	_matchingProperties = [matchingProperties copy];
	[_matchingLabels release];
	_matchingLabels = [[[matchingProperties allKeys] sortedArrayUsingSelector:@selector(compare:)] copy];
	[propertiesTable reloadData];
}
- (IBAction)copy:(id)sender
{
	NSMutableString *const string = [NSMutableString string];
	NSIndexSet *const indexes = [propertiesTable selectedRowIndexes];
	NSUInteger i = [indexes firstIndex];
	for(; NSNotFound != i; i = [indexes indexGreaterThanIndex:i]) {
		NSString *const label = [_matchingLabels objectAtIndex:i];
		[string appendFormat:@"%@: %@\n", label, [_matchingProperties objectForKey:label]];
	}
	NSPasteboard *const pboard = [NSPasteboard generalPasteboard];
	[pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
	[pboard setString:string forType:NSStringPboardType];
}

#pragma mark -

- (void)displayControllerActiveNodeWasRead:(NSNotification *)aNotif
{
	// TODO: Create special formatters for certain properties.
	// TODO: Automatically resize the first column to fit.
	/*
		kCGImagePropertyOrientation
		kCGImagePropertyDepth
		kCGImagePropertyDPIWidth, kCGImagePropertyDPIHeight
		kCGImagePropertyPixelWidth, kCGImagePropertyPixelHeight
		kCGImagePropertyPNGGamma (?)
		kCGImagePropertyExifFNumber (?)
		kCGImagePropertyExifExposureProgram (?)
		kCGImagePropertyExifISOSpeedRatings (?)
		kCGImagePropertyPNGInterlaceType Y/N
		kCGImagePropertyHasAlpha Y/N
		kCGImagePropertyTIFFDateTime/kCGImagePropertyExifSubsecTime
		kCGImagePropertyExifDateTimeOriginal/kCGImagePropertyExifSubsecTimeOrginal
		kCGImagePropertyExifDateTimeDigitized/kCGImagePropertyExifSubsecTimeDigitized

		Check other properties as well.
	*/
	NSDictionary *const keyLabels = [NSDictionary dictionaryWithObjectsAndKeys:
		@"File Size", (NSString *)kCGImagePropertyFileSize,
		@"Pixel Height", (NSString *)kCGImagePropertyPixelHeight,
		@"Pixel Width", (NSString *)kCGImagePropertyPixelWidth,
		@"DPI Height", (NSString *)kCGImagePropertyDPIHeight,
		@"DPI Width", (NSString *)kCGImagePropertyDPIWidth,
		@"Depth", (NSString *)kCGImagePropertyDepth,
		@"Orientation", (NSString *)kCGImagePropertyOrientation,
		@"Alpha", (NSString *)kCGImagePropertyHasAlpha,
		@"Color Model", (NSString *)kCGImagePropertyColorModel,
		@"Profile Name", (NSString *)kCGImagePropertyProfileName,
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"TIFF Info", @".",
			@"Compression", (NSString *)kCGImagePropertyTIFFCompression,
			@"Photometric Interpretation", (NSString *)kCGImagePropertyTIFFPhotometricInterpretation,
			@"Document Name", (NSString *)kCGImagePropertyTIFFDocumentName,
			@"Image Description", (NSString *)kCGImagePropertyTIFFImageDescription,
			@"Make", (NSString *)kCGImagePropertyTIFFMake,
			@"Model", (NSString *)kCGImagePropertyTIFFModel,
			@"Software", (NSString *)kCGImagePropertyTIFFSoftware,
			@"Transfer Function", (NSString *)kCGImagePropertyTIFFTransferFunction,
			@"Date/Time", (NSString *)kCGImagePropertyTIFFDateTime,
			@"Artist", (NSString *)kCGImagePropertyTIFFArtist,
			@"Host Computer", (NSString *)kCGImagePropertyTIFFHostComputer,
			@"Copyright", (NSString *)kCGImagePropertyTIFFCopyright,
			@"White Point", (NSString *)kCGImagePropertyTIFFWhitePoint,
			@"Primary Chromaticities", (NSString *)kCGImagePropertyTIFFPrimaryChromaticities,
			nil], (NSString *)kCGImagePropertyTIFFDictionary,
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"JFIF Info", @".",
			@"Progressive", (NSString *)kCGImagePropertyJFIFIsProgressive,
			nil], (NSString *)kCGImagePropertyJFIFDictionary,
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"Exif Info", @".",
			@"Exposure Time", (NSString *)kCGImagePropertyExifExposureTime,
			@"F Number", (NSString *)kCGImagePropertyExifFNumber,
			@"Exposure Program", (NSString *)kCGImagePropertyExifExposureProgram,
			@"Spectral Sensitivity", (NSString *)kCGImagePropertyExifSpectralSensitivity,
			@"ISO Speed Ratings", (NSString *)kCGImagePropertyExifISOSpeedRatings,
			@"OECF", (NSString *)kCGImagePropertyExifOECF,
			@"Date/Time (Original)", (NSString *)kCGImagePropertyExifDateTimeOriginal,
			@"Date/Time (Digitized)", (NSString *)kCGImagePropertyExifDateTimeDigitized,
			@"Components Configuration", (NSString *)kCGImagePropertyExifComponentsConfiguration,
			@"Compressed BPP", (NSString *)kCGImagePropertyExifCompressedBitsPerPixel,
			@"Shutter Speed", (NSString *)kCGImagePropertyExifShutterSpeedValue,
			@"Aperture", (NSString *)kCGImagePropertyExifApertureValue,
			@"Brightness", (NSString *)kCGImagePropertyExifBrightnessValue,
			@"Exposure Bias", (NSString *)kCGImagePropertyExifExposureBiasValue,
			@"Max Aperture", (NSString *)kCGImagePropertyExifMaxApertureValue,
			@"Subject Distance", (NSString *)kCGImagePropertyExifSubjectDistance,
			@"Metering Mode", (NSString *)kCGImagePropertyExifMeteringMode,
			@"Light Source", (NSString *)kCGImagePropertyExifLightSource,
			@"Flash", (NSString *)kCGImagePropertyExifFlash,
			@"Focal Length", (NSString *)kCGImagePropertyExifFocalLength,
			@"Subject Area", (NSString *)kCGImagePropertyExifSubjectArea,
			@"Maker Note", (NSString *)kCGImagePropertyExifMakerNote,
			@"User Comment", (NSString *)kCGImagePropertyExifUserComment,
			@"Subsec Time", (NSString *)kCGImagePropertyExifSubsecTime,
			@"Subsec Time (Orginal)", (NSString *)kCGImagePropertyExifSubsecTimeOrginal,
			@"Subsec Time (Digitized)", (NSString *)kCGImagePropertyExifSubsecTimeDigitized,
			@"Flash Pix Version", (NSString *)kCGImagePropertyExifFlashPixVersion,
			@"Color Space", (NSString *)kCGImagePropertyExifColorSpace,
			@"Related Sound File", (NSString *)kCGImagePropertyExifRelatedSoundFile,
			@"Flash Energy", (NSString *)kCGImagePropertyExifFlashEnergy,
			@"Spatial Frequency Response", (NSString *)kCGImagePropertyExifSpatialFrequencyResponse,
			@"Focal Plane X Resolution", (NSString *)kCGImagePropertyExifFocalPlaneXResolution,
			@"Focal Plane Y Resolution", (NSString *)kCGImagePropertyExifFocalPlaneYResolution,
			@"Focal Plane Resolution Unit", (NSString *)kCGImagePropertyExifFocalPlaneResolutionUnit,
			@"Subject Location", (NSString *)kCGImagePropertyExifSubjectLocation,
			@"Exposure Index", (NSString *)kCGImagePropertyExifExposureIndex,
			@"Sensing Method", (NSString *)kCGImagePropertyExifSensingMethod,
			@"File Source", (NSString *)kCGImagePropertyExifFileSource,
			@"Scene Type", (NSString *)kCGImagePropertyExifSceneType,
			@"Custom Rendered", (NSString *)kCGImagePropertyExifCustomRendered,
			@"Exposure Mode", (NSString *)kCGImagePropertyExifExposureMode,
			@"White Balance", (NSString *)kCGImagePropertyExifWhiteBalance,
			@"Digital Zoom Ratio", (NSString *)kCGImagePropertyExifDigitalZoomRatio,
			@"Focal Length In 35mm Film", (NSString *)kCGImagePropertyExifFocalLenIn35mmFilm,
			@"Scene Capture Type", (NSString *)kCGImagePropertyExifSceneCaptureType,
			@"Gain Control", (NSString *)kCGImagePropertyExifGainControl,
			@"Contrast", (NSString *)kCGImagePropertyExifContrast,
			@"Saturation", (NSString *)kCGImagePropertyExifSaturation,
			@"Sharpness", (NSString *)kCGImagePropertyExifSharpness,
			@"Device Setting Description", (NSString *)kCGImagePropertyExifDeviceSettingDescription,
			@"Subject Dist Range", (NSString *)kCGImagePropertyExifSubjectDistRange,
			@"Image Unique ID", (NSString *)kCGImagePropertyExifImageUniqueID,
			@"Gamma", (NSString *)kCGImagePropertyExifGamma,
			nil], (NSString *)kCGImagePropertyExifDictionary,
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"Exif (Aux) Info", @".",
			@"Lens Model", (NSString *)kCGImagePropertyExifAuxLensModel,
			@"Serial Number", (NSString *)kCGImagePropertyExifAuxSerialNumber,
			@"Lens ID", (NSString *)kCGImagePropertyExifAuxLensID,
			@"Lens Serial Number", (NSString *)kCGImagePropertyExifAuxLensSerialNumber,
			@"Image Number", (NSString *)kCGImagePropertyExifAuxImageNumber,
			@"Flash Compensation", (NSString *)kCGImagePropertyExifAuxFlashCompensation,
			@"Owner Name", (NSString *)kCGImagePropertyExifAuxOwnerName,
			@"Firmware", (NSString *)kCGImagePropertyExifAuxFirmware,
			nil], (NSString *)kCGImagePropertyExifAuxDictionary,
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"PNG Info", @".",
			@"Gamma", (NSString *)kCGImagePropertyPNGGamma,
			@"Interlaced", (NSString *)kCGImagePropertyPNGInterlaceType,
			@"sRGB Intent", (NSString *)kCGImagePropertyPNGsRGBIntent,
			nil], (NSString *)kCGImagePropertyPNGDictionary,
		nil];
	NSDictionary *const properties = [[[[self displayController] activeNode] resourceAdapter] imageProperties];
	[_imageProperties release];
	_imageProperties = [[[properties PG_replacementUsingObject:keyLabels preserveUnknown:NO getTopLevelKey:NULL] PG_flattenedDictionary] copy];
	NSLog(@"hmm... %@", properties);
	[self changeSearch:nil];
}

#pragma mark -PGFloatingPanelController

- (NSString *)nibName
{
	return @"PGInspector";
}
- (BOOL)setDisplayController:(PGDisplayController *)controller
{
	PGDisplayController *const oldController = [self displayController];
	if(![super setDisplayController:controller]) return NO;
	[oldController PG_removeObserver:self name:PGDisplayControllerActiveNodeWasReadNotification];
	[[self displayController] PG_addObserver:self selector:@selector(displayControllerActiveNodeWasRead:) name:PGDisplayControllerActiveNodeWasReadNotification];
	[self displayControllerActiveNodeWasRead:nil];
	return YES;
}

#pragma mark -NSObject

- (void)dealloc
{
	[propertiesTable setDelegate:nil];
	[propertiesTable setDataSource:nil];
	[_imageProperties release];
	[_matchingProperties release];
	[_matchingLabels release];
	[super dealloc];
}

#pragma mark -NSObject(NSMenuValidation)

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	SEL const action = [anItem action];
	if(@selector(copy:) == action && ![[propertiesTable selectedRowIndexes] count]) return NO;
	return [super validateMenuItem:anItem];
}

#pragma mark -<NSTableDataSource>

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [_matchingLabels count];
}
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSString *const label = [_matchingLabels objectAtIndex:row];
	if(tableColumn == labelColumn) {
		return label;
	} else if(tableColumn == valueColumn) {
		return [_matchingProperties objectForKey:label];
	}
	return nil;
}

#pragma mark -<NSTableViewDelegate>

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	if(tableColumn == labelColumn) {
		[cell setAlignment:NSRightTextAlignment];
		[cell setFont:[[NSFontManager sharedFontManager] convertFont:[cell font] toHaveTrait:NSBoldFontMask]];
	}
}

@end

@implementation NSObject(PGAdditions)

#pragma mark -NSObject(PGAdditions)

- (id)PG_replacementUsingObject:(id)replacement preserveUnknown:(BOOL)preserve getTopLevelKey:(out id *)outKey
{
	if(!replacement) return preserve ? self : nil;
	if(outKey) *outKey = replacement;
	return self;
}

@end

@implementation NSDictionary(PGAdditions)

#pragma mark -NSDictionary(PGAdditions)

- (NSDictionary *)PG_flattenedDictionary
{
	NSMutableDictionary *const results = [NSMutableDictionary dictionary];
	for(id const key in self) {
		id const obj = [self objectForKey:key];
		if([obj isKindOfClass:[NSDictionary class]]) [results addEntriesFromDictionary:obj];
		else [results setObject:obj forKey:key];
	}
	return results;
}

#pragma mark -NSObject(PGAdditions)

- (id)PG_replacementUsingObject:(id)replacement preserveUnknown:(BOOL)preserve getTopLevelKey:(out id *)outKey
{
	if(![replacement isKindOfClass:[NSDictionary class]]) return [super PG_replacementUsingObject:replacement preserveUnknown:preserve getTopLevelKey:outKey];
	NSMutableDictionary *const result = [NSMutableDictionary dictionary];
	for(id const key in self) {
		id replacementKey = key;
		id const replacementObj = [[self objectForKey:key] PG_replacementUsingObject:[(NSDictionary *)replacement objectForKey:key] preserveUnknown:preserve getTopLevelKey:&replacementKey];
		if(replacementObj) [result setObject:replacementObj forKey:replacementKey];
	}
	if(outKey) *outKey = [(NSDictionary *)replacement objectForKey:@"."];
	return result;
}

@end
