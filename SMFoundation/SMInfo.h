/*
 *  SMInfo.h
 *
 *  Copyright 2019 Avérous Julien-Pierre
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
** Defines
*/
#pragma mark - Defines

// Descriptor.
#define SMInfoNameKey			@"name"
#define SMInfoTextKey			@"text"
#define SMInfoDynTextKey		@"dyn_text"
#define SMInfoLocalizableKey	@"localizable"



/*
** Types
*/
#pragma mark - Types

typedef NS_ENUM(unsigned int, SMInfoKind) {
	SMInfoInfo,
	SMInfoWarning,
	SMInfoError,
};

typedef NSDictionary * _Nullable (^SMInfoDescriptorBuilder)(SMInfoKind kind, int code);
typedef NSString * _Nullable (^SMInfoLocalizer)(NSString *token);



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

// -- Descriptors --
+ (void)registerDomainsDescriptors:(NSDictionary *)descriptors localizer:(nullable SMInfoLocalizer)localizer;

// -- Rendering --
@property (nonatomic, readonly, copy) NSString * _Nonnull renderComplete;
@property (nonatomic, readonly, copy) NSString * _Nullable renderMessage;

@end


NS_ASSUME_NONNULL_END

