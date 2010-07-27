#import "CommandLineCommon.h"

#import "XADString.h"
#import "NSStringPrinting.h"

void PrintEncodingList()
{
	NSEnumerator *enumerator=[[XADString availableEncodingNames] objectEnumerator];
	NSArray *encodingarray;
	while(encodingarray=[enumerator nextObject])
	{
		NSString *description=[encodingarray objectAtIndex:0];
		if((id)description==[NSNull null]||[description length]==0) description=nil;

		NSString *encoding=[encodingarray objectAtIndex:1];

		NSString *aliases=nil;
		if([encodingarray count]>2) aliases=[[encodingarray subarrayWithRange:
		NSMakeRange(2,[encodingarray count]-2)] componentsJoinedByString:@", "];

		[@"  * " print];

		[encoding print];

		if(aliases)
		{
			[@" (" print];
			[aliases print];
			[@")" print];
		}

		if(description)
		{
			[@": " print];
			[description print];
		}

		[@"\n" print];
	}
}

