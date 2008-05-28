#import <Cocoa/Cocoa.h>

@interface PGEncodingAlert : NSWindowController
{
	@private
	IBOutlet NSTableView      *encodingsTable;
	IBOutlet NSTableColumn    *encodingColumn;
	IBOutlet NSTableColumn    *sampleColumn;
	         NSArray         *_encodings;
	         NSArray         *_encodingNames;
	         NSArray         *_samples;
	         NSStringEncoding _defaultEncoding;
	         id               _delegate;
}

- (id)initWithString:(char const *)bytes guess:(NSStringEncoding)guess;

- (IBAction)ok:(id)sender;
- (IBAction)cancel:(id)sender;

- (void)beginSheetForWindow:(NSWindow *)window withDelegate:(id)anObject; // If 'window' is nil, uses a modal alert instead of a sheet.
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

@end

@interface NSObject (PGEncodingAlertDelegate)

- (void)encodingAlertDidEnd:(PGEncodingAlert *)sender selectedEncoding:(NSStringEncoding)encoding;

@end
