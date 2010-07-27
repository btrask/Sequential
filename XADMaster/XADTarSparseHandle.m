#import "XADTarSparseHandle.h"
#import "SystemSpecific.h"

@implementation XADTarSparseHandle

// Make a new sparse handle by wrapping around another CSHandle
-(id)initWithHandle:(CSHandle *)handle size:(off_t)size
{
	if( (self = [super initWithName:[handle name]]) )
	{
		parent = [handle retain];
		regions = malloc( sizeof( XADTarSparseRegion ) );
		regions[ 0 ].nextRegion = -1;
		regions[ 0 ].size = [parent fileSize];
		regions[ 0 ].offset = 0;
		regions[ 0 ].hasData = YES;
		regions[ 0 ].dataOffset = 0;
		
		numRegions = 1;
		currentOffset = 0;
		currentRegion = 0;
		realFileSize = size;
		
	}
	return( self );
}

// Copy constructor
-(id)initAsCopyOf:(XADTarSparseHandle *)other
{
	if( (self = [super initAsCopyOf:other]) )
	{
		parent = [other->parent copy];
		numRegions = other->numRegions;
		regions = malloc( sizeof( XADTarSparseRegion ) * numRegions );
		memcpy( regions, other->regions, sizeof( XADTarSparseRegion ) * numRegions );
		currentOffset = other->currentOffset;
		currentRegion = other->currentRegion;
		realFileSize = other->realFileSize;
	}
	return( self );
}

// Free all regions, allow parent release.
-(void)dealloc
{
	free( regions );
	[parent release];
	[super dealloc];
}

// Find which region some offset is in.
-(int)regionIndexForOffset:(off_t)offset
{
	// That is not a valid offset!
	if( offset >= [self fileSize] ) {
		[self _raiseEOF];
	}

	// Go through all regions until one fits.
	int index = 0;
	while(
		index < numRegions &&
		(offset < regions[ index ].offset ||
		offset >= regions[ index ].offset + regions[ index ].size)
	)
	{
		index++;
	}

	return( index );
}

// Add a new sparse region.
// You can only ever add a region entirely inside of another region.
-(void)addSparseRegionFrom:(off_t)start length:(off_t)length
{
	for( int i = 0; i < numRegions; i++ ) {
	//	fprintf( stderr, "%d: %d->%d (%s - %d) => %d\n", i, regions[ i ].offset, regions[ i ].size, (regions[ i ].hasData ? "has data" : "no data"), regions[ i ].dataOffset, regions[ i ].nextRegion );
	}

	int inRegion = [self regionIndexForOffset:start];
	//fprintf( stderr, "In region %d\n", inRegion );
	if( start + length >= regions[ inRegion ].offset + regions[ inRegion ].size )
	{
		//fprintf( stderr, "s: %d; l: %d; iro:%d; irs: %d; s1: %d, s2: %d (i: %d)\n", start, length, regions[ inRegion ].offset, regions[ inRegion ].size, start + length, regions[ inRegion ].offset + regions[ inRegion ].size, [self regionIndexForOffset:start] );
		
		[NSException raise:NSInvalidArgumentException format:@"Attempted to add sparse region over region boundary."];
	}

	// Make two new regions.
	regions = reallocf( regions, sizeof( XADTarSparseRegion ) * ( numRegions + 2 ) );

	// Start processing at the end.
	regions[ numRegions + 1 ].offset = start + length;
	regions[ numRegions + 1 ].dataOffset = start - regions[ inRegion ].offset;
	regions[ numRegions + 1 ].size = regions[ inRegion ].size - regions[ numRegions + 1 ].dataOffset;
	regions[ numRegions + 1 ].nextRegion = regions[ inRegion ].nextRegion;
	regions[ numRegions + 1 ].hasData = YES;

	// Sparse region being added.
	regions[ numRegions ].offset = start;
	regions[ numRegions ].size = length;
	regions[ numRegions ].hasData = NO;
	regions[ numRegions ].nextRegion = numRegions + 1;

	// Refumble old region.
	regions[ inRegion ].size = regions[ inRegion ].size - regions[ numRegions + 1 ].size;
	regions[ inRegion ].nextRegion = numRegions;

	// Current region might have changed by this.
	currentRegion = [self regionIndexForOffset:currentOffset];

	numRegions += 2;

	//fprintf( stderr, "Adding section worked.\n" );
}

// Add a new sparse region as last region of a file.
-(void)addFinalSparseRegionEndingAt:(off_t)regionEndsAt
{
	for( int i = 0; i < numRegions; i++ ) {
// 		fprintf( stderr, "%d: %d->%d (%s - %d) => %d\n", i, regions[ i ].offset, regions[ i ].size, (regions[ i ].hasData ? "has data" : "no data"), regions[ i ].dataOffset, regions[ i ].nextRegion );
	}

	XADTarSparseRegion inRegion = regions[ [self regionIndexForOffset:([self fileSize] - 1)] ];
	
	// Make a new region.
	regions = reallocf( regions, sizeof( XADTarSparseRegion ) * ( numRegions + 1 ) );

	// Figure out the current size.
	off_t sizeBeforeAdding = 0;
	for( int i = 0; i < numRegions; i++ )
	{
		sizeBeforeAdding += regions[ i ].size;
	}

	// Sparse region being added.
	regions[ numRegions ].offset = sizeBeforeAdding;
	regions[ numRegions ].size = regionEndsAt - sizeBeforeAdding;
	regions[ numRegions ].hasData = NO;
	regions[ numRegions ].nextRegion = -1;

	// Refumble old region.
	inRegion.nextRegion = numRegions;

	// Current region might have changed by this.
	currentRegion = [self regionIndexForOffset:currentOffset];

	numRegions++;

	for( int i = 0; i < numRegions; i++ ) {
// 		fprintf( stderr, "%d: %d->%d (%s - %d) => %d\n", i, regions[ i ].offset, regions[ i ].size, (regions[ i ].hasData ? "has data" : "no data"), regions[ i ].dataOffset, regions[ i ].nextRegion );
	}

// 	fprintf( stderr, "Adding final section worked.\n" );
}

// Set the only region to "empty".
-(void)setSingleEmptySparseRegion
{
	regions[ numRegions ].offset = 0;
	regions[ numRegions ].size = [self fileSize];
	regions[ numRegions ].hasData = NO;
	regions[ numRegions ].nextRegion = -1;

	currentRegion = [self regionIndexForOffset:currentOffset];

	for( int i = 0; i < numRegions; i++ ) {
// 		fprintf( stderr, "%d: %d->%d (%s - %d) => %d\n", i, regions[ i ].offset, regions[ i ].size, (regions[ i ].hasData ? "has data" : "no data"), regions[ i ].dataOffset, regions[ i ].nextRegion );
	}

// 	fprintf( stderr, "Setting single section worked.\n" );
}

// Return real file size.
-(off_t)fileSize
{
	return( realFileSize );
}

// Just return our saved offset.
-(off_t)offsetInFile
{
	return( currentOffset );
}

-(BOOL)atEndOfFile
{
	return( currentOffset == [self fileSize] );
}

// Just set the internal offset.
// Seeking in parent handle is done on demand.
-(void)seekToFileOffset:(off_t)offs
{
	currentOffset = offs;
}

// The same as for seekToFileOffset applies.
-(void)seekToEndOfFile
{
	currentOffset = [self fileSize];
}

// Return data from parent handle or \0 in sparse regions.
// I'd heartily recommend not adding more sparse regions after you started
// reading because if you do things will break.
-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
// 	fprintf( stderr, "Readatmost %d\n", num );
	// Do not read further than allowed.
	if( currentOffset + num > [self fileSize] )
	{
//		fprintf( stderr, "Oops: %d plus %d = %d > %d\n", currentOffset, num, currentOffset + num, [self fileSize] );
//		[self _raiseEOF];
	}

	// Seek if we have to.
	if( regions[ currentRegion ].hasData && regions[ currentRegion ].dataOffset != [parent offsetInFile] )
	{
	//	fprintf( stderr, "Seeking: %d.\n", regions[ currentRegion ].dataOffset );
		[parent seekToFileOffset:regions[ currentRegion ].dataOffset];
	}
	
	// Fill the buffer with data.
	memset( buffer, 0, num );
	long positionInBuffer = 0;
	long stopAtSize = [self fileSize];
	off_t positionInRegion = regions[ currentRegion ].offset - currentOffset;
	off_t dataLeftInRegion = regions[ currentRegion ].size - positionInRegion;
	while( positionInBuffer + dataLeftInRegion < num && currentOffset < stopAtSize )
	{
// 		fprintf( stderr, "Reading: %d really %d.\n", positionInBuffer, currentOffset );
		if( regions[ currentOffset ].hasData )
		{
			[parent readAtMost:dataLeftInRegion toBuffer:buffer];
		}
		currentRegion = regions[ currentRegion ].nextRegion;
		positionInRegion = 0;
		dataLeftInRegion = regions[ currentRegion ].size;
		currentOffset += dataLeftInRegion;
	}

	// Read the last segment of data, if required.
	if( regions[ currentRegion ].hasData )
	{
		[parent readAtMost:(num - positionInBuffer) toBuffer:buffer];
		currentOffset += num - positionInBuffer;
	}

	// If we in a sparse region now, push the file offset up.
	if( currentOffset < [self fileSize] ) {
		long remaining = [self fileSize] - currentOffset;
		if( positionInBuffer + remaining <= num )
		{
			positionInBuffer += remaining;
			currentOffset += remaining;
		}
		else
		{
			currentOffset += num - positionInBuffer;
			positionInBuffer = num;
		}
	}
	
// 	fprintf( stderr, "Readatmost okay, read %d.\n", positionInBuffer );

	return( positionInBuffer );
}

@end
