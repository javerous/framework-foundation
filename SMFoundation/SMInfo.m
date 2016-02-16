/*
 *  SMInfo.m
 *
 *  Copyright 2016 Avérous Julien-Pierre
 *
 *  This file is part of SMFoundation.
 *
 *  SMFoundation is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  SMFoundation is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with SMFoundation.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import "SMInfo.h"


NS_ASSUME_NONNULL_BEGIN


/*
** SMInfo - Private
*/
#pragma mark - SMInfo - Private

@interface SMInfo ()

// -- Properties (RW) --
@property (assign, nonatomic) SMInfoKind	kind;
@property (strong, nonatomic) NSString		*domain;
@property (assign, nonatomic) int			code;
@property (strong, nonatomic, nullable) id			context;
@property (strong, nonatomic, nullable) SMInfo		*subInfo;

@end



/*
** SMInfo
*/
#pragma mark - SMInfo

@implementation SMInfo


/*
** SMInfo - Instance
*/
#pragma mark - SMInfo - Instance

+ (SMInfo *)infoOfKind:(SMInfoKind)kind domain:(NSString *)domain code:(int)code
{
	NSAssert(domain, @"domain is nil");

	SMInfo *info = [[SMInfo alloc] init];
	
	info.kind = kind;
	info.domain = domain;
	info.code = code;
	
	return info;
}

+ (SMInfo *)infoOfKind:(SMInfoKind)kind domain:(NSString *)domain code:(int)code context:(nullable id)context
{
	NSAssert(domain, @"domain is nil");
	
	SMInfo *info = [[SMInfo alloc] init];
	
	info.kind = kind;
	info.domain = domain;
	info.code = code;
	info.context = context;
	
	return info;
}

+ (SMInfo *)infoOfKind:(SMInfoKind)kind domain:(NSString *)domain code:(int)code info:(nullable SMInfo *)sinfo
{
	NSAssert(domain, @"domain is nil");

	SMInfo *info = [[SMInfo alloc] init];
	
	info.kind = kind;
	info.domain = domain;
	info.code = code;
	info.subInfo = sinfo;
	
	return info;
}

+ (SMInfo *)infoOfKind:(SMInfoKind)kind domain:(NSString *)domain code:(int)code context:(nullable id)context info:(nullable SMInfo *)sinfo
{
	NSAssert(domain, @"domain is nil");

	SMInfo *info = [[SMInfo alloc] init];
	
	info.kind = kind;
	info.domain = domain;
	info.code = code;
	info.context = context;
	info.subInfo = sinfo;
	
	return info;
}

- (id)init
{
    self = [super init];
	
    if (self)
	{
		_timestamp = [NSDate date];
    }
	
    return self;
}



/*
** SMInfo - Rendering
*/
#pragma mark - SMInfo - Rendering

#pragma mark Descriptors

static NSMutableDictionary *gDescriptors;
static NSMutableDictionary *gLocalizers;

+ (dispatch_queue_t)renderDescriptorQueue
{
	static dispatch_once_t	onceToken;
	static dispatch_queue_t	descriptorQueue;

	dispatch_once(&onceToken, ^{
		descriptorQueue = dispatch_queue_create("com.smfoundation.info.descriptors", DISPATCH_QUEUE_SERIAL);
	});

	return descriptorQueue;
}

+ (void)registerRenderDescriptors:(NSDictionary *)descriptors localizer:(nullable NSString * (^)(NSString *token))localizer
{
	if (!localizer)
	{
		NSBundle *bundle = [NSBundle mainBundle];
		
		localizer = ^ NSString * (NSString *token) {
			return [bundle localizedStringForKey:token value:@"" table:nil];
		};
	}
	
	// Store items.
	dispatch_async([self renderDescriptorQueue], ^{
		
		if (!gDescriptors)
			gDescriptors = [[NSMutableDictionary alloc] init];
		
		[descriptors enumerateKeysAndObjectsUsingBlock:^(NSString *  _Nonnull domain, id  _Nonnull content, BOOL * _Nonnull stop) {
			gDescriptors[domain] = content;
			gLocalizers[domain] = localizer;
		}];
	});
}

+ (NSDictionary *)renderDescriptorForDomain:(NSString *)domain kind:(SMInfoKind)kind code:(int)code
{
	__block NSDictionary *descriptor;
	
	dispatch_sync([self renderDescriptorQueue], ^{
		descriptor = gDescriptors[domain][@(kind)][@(code)];
	});
	
	return descriptor;
}


#pragma mark Rendering

- (NSString *)renderComplete
{
	NSMutableString *result = [[NSMutableString alloc] init];
	
	// Get info.
	NSDictionary *infos = [[self class] renderDescriptorForDomain:_domain kind:_kind code:_code];
	
	if (!infos)
	{
		[result appendFormat:@"Unknow (domain='%@'; kind=%d; code=%d", self.domain, self.kind, self.code];
		
		return result;
	}
	
	// Add the error name.
	[result appendFormat:@"[%@] ", infos[SMInfoNameKey]];
	
	// Add the message string
	NSString *msg = [self renderMessage];
	
	if (msg)
		[result appendString:msg];
	
	// Ad the sub-info
	if (self.subInfo)
	{
		[result appendString:@" "];
		[result appendString:[self.subInfo _render]];
	}
	
	return result;
}

- (NSString *)_render
{
	NSMutableString *result = [[NSMutableString alloc] init];
	
	// Get info.
	NSDictionary *infos = [[self class] renderDescriptorForDomain:_domain kind:_kind code:_code];
	
	if (!infos)
	{
		[result appendFormat:@"{Unknow}"];
		
		return result;
	}
	
	// Add the errcode and the info
	[result appendFormat:@"{%@ - ", infos[SMInfoNameKey]];
	
	// Add the message string
	NSString *msg = [self renderMessage];
	
	if (msg)
		[result appendString:msg];
	
	// Add the other sub-info
	if (self.subInfo)
	{
		[result appendString:@" "];
		[result appendString:[self.subInfo _render]];
	}
	
	[result appendString:@"}"];
	
	return result;
}

- (NSString *)renderMessage
{
	NSDictionary	*infos = [[self class] renderDescriptorForDomain:_domain kind:_kind code:_code];
	NSString		*msg = infos[SMInfoTextKey];
	
	if (!msg)
	{
		NSString * (^dyn)(SMInfo *) =  infos[SMInfoDynTextKey];
		
		if (dyn)
			msg = dyn(self);
	}
	
	if (msg)
	{
		if ([infos[SMInfoLocalizableKey] boolValue])
			return NSLocalizedString(msg, @"");
		else
			return msg;
	}
	
	return nil;
}

@end


NS_ASSUME_NONNULL_END
