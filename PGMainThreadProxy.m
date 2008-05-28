#import "PGMainThreadProxy.h"

@implementation PGMainThreadProxy

#pragma mark Instance Methods

- (id)initWithTarget:(id)anObject
{
	_target = [anObject retain];
	return self;
}

#pragma mark NSProxy

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
{
	return [_target methodSignatureForSelector:sel];
}
- (void)forwardInvocation:(NSInvocation *)invocation
{
	[invocation setTarget:_target];
	[invocation performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:YES];
}

#pragma mark NSProxy

- (void)dealloc
{
	[_target performSelectorOnMainThread:@selector(release) withObject:nil waitUntilDone:NO]; // Just because -[NSObject release] is threadsafe doesn't mean -[MyFunkyClass dealloc] is.
	[super dealloc];
}

@end
