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
@property (strong, nonatomic) id			context;
@property (strong, nonatomic) SMInfo		*subInfo;

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

@end


NS_ASSUME_NONNULL_END
