/*
 *  SMInfo.m
 *
 *  Copyright 2017 Avérous Julien-Pierre
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

- (instancetype)init
{
    self = [super init];
	
    if (self)
	{
		_timestamp = [NSDate date];
    }
	
    return self;
}



/*
** SMInfo - Descriptors
*/
#pragma mark - SMInfo - Descriptors

static NSMutableDictionary *gDescriptorsBuilders;
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

+ (void)registerDomainsDescriptors:(NSDictionary *)descriptors localizer:(nullable SMInfoLocalizer)localizer
{
	NSAssert(descriptors, @"descriptors is nil");
	
	// Store items.
	dispatch_async([self renderDescriptorQueue], ^{
		
		if (!gDescriptorsBuilders)
			gDescriptorsBuilders = [[NSMutableDictionary alloc] init];
		
		if (!gLocalizers)
			gLocalizers = [[NSMutableDictionary alloc] init];
		
		[descriptors enumerateKeysAndObjectsUsingBlock:^(NSString *  _Nonnull domain, SMInfoDescriptorBuilder _Nonnull builder, BOOL * _Nonnull stop) {
			gDescriptorsBuilders[domain] = builder;
			gLocalizers[domain] = localizer;
		}];
	});
}

+ (NSDictionary *)renderDescriptorForDomain:(NSString *)domain kind:(SMInfoKind)kind code:(int)code
{
	__block NSDictionary *descriptor;
	
	dispatch_sync([self renderDescriptorQueue], ^{
		
		descriptor = gDescriptors[domain][@(kind)][@(code)];
		
		if (!descriptor)
		{
			SMInfoDescriptorBuilder builder = gDescriptorsBuilders[domain];
			
			descriptor = builder(kind, code);
			
			if (descriptor)
			{
				
				if (!gDescriptors)
					gDescriptors = [[NSMutableDictionary alloc] init];
				
				NSMutableDictionary *kinds = gDescriptors[domain];
				
				if (!kinds)
				{
					kinds = [[NSMutableDictionary alloc] init];
					gDescriptors[domain] = kinds;
				}
				
				NSMutableDictionary *codes = kinds[@(kind)];
				
				if (!codes)
				{
					codes = [[NSMutableDictionary alloc] init];
					kinds[@(kind)] = codes;
				}
				
				codes[@(code)] = descriptor;
			}
		}
	});
	
	return descriptor;
}

+ (NSString *)localizeToken:(NSString *)token forDomain:(NSString *)domain
{
	__block NSString *localized;
	
	dispatch_sync([self renderDescriptorQueue], ^{
		NSString * (^localizer)(NSString *token) = gLocalizers[domain];
		
		if (localizer)
			localized = localizer(token);
		else
			localized = NSLocalizedString(token, @"");
	});

	return localized;
}



/*
** SMInfo - Rendering
*/
#pragma mark - SMInfo - Rendering

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

- (nullable NSString *)renderMessage
{
	NSDictionary	*infos = [[self class] renderDescriptorForDomain:_domain kind:_kind code:_code];
	NSString		*msg = infos[SMInfoTextKey];
	
	if (!msg)
	{
		NSString * (^dyn)(id context) =  infos[SMInfoDynTextKey];
		
		if (dyn)
			msg = dyn(self.context);
	}
	
	if (msg)
	{
		if ([infos[SMInfoLocalizableKey] boolValue])
			return [[self class] localizeToken:msg forDomain:_domain];
		else
			return msg;
	}
	
	return nil;
}

@end


NS_ASSUME_NONNULL_END
