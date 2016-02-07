/*
 *  SMInfo.h
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

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN


/*
** Types
*/
#pragma mark - Types

typedef enum
{
	SMInfoInfo,
	SMInfoWarning,
	SMInfoError,
} SMInfoKind;



/*
** Forward
*/
#pragma mark - Forward

@class SMInfo;



/*
** SMInfo
*/
#pragma mark - SMInfo

@interface SMInfo : NSObject

// -- Properties --
@property (assign, nonatomic, readonly) SMInfoKind	kind;

@property (strong, nonatomic, readonly) NSString	*domain;
@property (assign, nonatomic, readonly)	int			code;
@property (strong, nonatomic, readonly)	id			context;

@property (strong, nonatomic, readonly) NSDate		*timestamp;

@property (strong, nonatomic, readonly) SMInfo		*subInfo;


// -- Instance --
+ (SMInfo *)infoOfKind:(SMInfoKind)kind domain:(NSString *)domain code:(int)code;
+ (SMInfo *)infoOfKind:(SMInfoKind)kind domain:(NSString *)domain code:(int)code context:(nullable id)context;
+ (SMInfo *)infoOfKind:(SMInfoKind)kind domain:(NSString *)domain code:(int)code info:(nullable SMInfo *)info;
+ (SMInfo *)infoOfKind:(SMInfoKind)kind domain:(NSString *)domain code:(int)code context:(nullable id)context info:(nullable SMInfo *)info;

@end


NS_ASSUME_NONNULL_END

