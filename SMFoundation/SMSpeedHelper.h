/*
 *  SMSpeedHelper.h
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
** SMSpeedHelper
*/
#pragma mark - SMSpeedHelper

@interface SMSpeedHelper : NSObject

// -- Instance --
- (instancetype)initWithCompleteAmount:(NSUInteger)amount;

// -- Update --
- (void)setCurrentAmount:(NSUInteger)amount;
- (void)addAmount:(NSUInteger)amount;

// -- Compute --
- (double)averageSpeed;
- (NSTimeInterval)remainingTime;

@property (strong, atomic, nullable) void (^updateHandler)(NSTimeInterval remainingTime);

@end

NS_ASSUME_NONNULL_END
