/*
 *  SMSpeedHelper.m
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

#import "SMSpeedHelper.h"

#import "SMTimeHelper.h"


NS_ASSUME_NONNULL_BEGIN


/*
** SMSpeedStatement
*/
#pragma mark - SMSpeedStatement

@interface SMSpeedStatement : NSObject

@property (assign, nonatomic) NSUInteger	amount;
@property (assign, nonatomic) double		timestamp;

@end

@implementation SMSpeedStatement
@end



/*
** SMSpeedHelper
*/
#pragma mark - SMSpeedHelper

@implementation SMSpeedHelper
{
	dispatch_queue_t _localQueue;
	
	NSUInteger	_currentAmount;
	NSUInteger	_completeAmount;
	
	double			_lastSet;
	NSMutableArray	*_statements;

	dispatch_source_t	_timer;
	
	void (^_updateHandler)(NSTimeInterval);
}


/*
** SMSpeedHelper - Instance
*/
#pragma mark - SMSpeedHelper - Instance

- (instancetype)initWithCompleteAmount:(NSUInteger)amount
{
	self = [super init];
	
	if (self)
	{
		_localQueue = dispatch_queue_create("com.smfoundation.speed-helper.local", DISPATCH_QUEUE_SERIAL);
		_completeAmount = amount;
		
		_statements = [[NSMutableArray alloc] init];
	}
	
	return self;
}



/*
** SMSpeedHelper - Properties
*/
#pragma mark - SMSpeedHelper - Properties

- (void)setUpdateHandler:(void (^ _Nullable)(NSTimeInterval))updateHandler
{
	dispatch_async(_localQueue, ^{
		
		_updateHandler = updateHandler;
		
		if (!_updateHandler && _timer)
		{
			dispatch_source_cancel(_timer);
			_timer = nil;
		}
	});
}

- (void (^ _Nullable)(NSTimeInterval))updateHandler
{
	__block void (^result)(NSTimeInterval) = nil;
	
	dispatch_sync(_localQueue, ^{
		result = _updateHandler;
	});
	
	return result;
}


/*
** SMSpeedHelper - Update
*/
#pragma mark - SMSpeedHelper - Update

- (void)setCurrentAmount:(NSUInteger)currentAmout
{
	double ts = SMTimeStamp();
	
	dispatch_async(_localQueue, ^{
		[self _setCurrentAmount:currentAmout timestamp:ts];
	});
}

- (void)addAmount:(NSUInteger)amount
{
	double ts = SMTimeStamp();

	dispatch_async(_localQueue, ^{
		
		NSUInteger newAmount = _currentAmount + amount;
		
		[self _setCurrentAmount:newAmount timestamp:ts];
	});
}


- (void)_setCurrentAmount:(NSUInteger)currentAmout timestamp:(double)ts
{
	// > _localQueue <
	
	if (currentAmout == 0 || currentAmout > _completeAmount || currentAmout < _currentAmount)
		return;
	
	if (ts - _lastSet < 1.0)
		return;
	
	// Update stats.
	SMSpeedStatement *statement = [[SMSpeedStatement alloc] init];
	
	_lastSet = ts;
	_currentAmount = currentAmout;
	
	statement.amount = currentAmout;
	statement.timestamp = ts;
	
	[_statements addObject:statement];
	
	if (_statements.count > 10)
		[_statements removeObjectAtIndex:0];
	
	// Start timer if necessary.
	if (_updateHandler && _timer == nil && _statements.count >= 2)
	{
		__weak SMSpeedHelper *weakSelf = self;

		_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _localQueue);
		
		dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC, 0);
		
		dispatch_source_set_event_handler(_timer, ^{
			
			SMSpeedHelper *strongSelf = weakSelf;
			
			if (!strongSelf)
				return;
			
			void (^updateHandler)(NSTimeInterval) = strongSelf->_updateHandler;

			if (updateHandler)
				updateHandler([strongSelf _remainingTime]);
		});
		
		dispatch_resume(_timer);
	}
}



/*
** SMSpeedHelper - Compute
*/
#pragma mark - SMSpeedHelper - Compute

- (double)averageSpeed
{
	__block double result;
	
	dispatch_sync(_localQueue, ^{
		result = [self _averageSpeed];
	});
	
	return result;
}

- (double)_averageSpeed
{
	// > localQueue <
	
	NSUInteger	i, count = _statements.count;
	double		sumWeightedSpeed = 0.0;
	NSUInteger	sumWeight = 0;
	
	if (count < 2)
		return -2.0;
	
	// Compute weighted average.
	for (i = 1; i < count; i++)
	{
		// > Get following statements.
		SMSpeedStatement *st1, *st2;
 
		st1 = _statements[i - 1];
		st2 = _statements[i];
		
		// > Compute delta time.
		double deltaTime = st2.timestamp - st1.timestamp;
		
		if (deltaTime <= 0)
			continue;
		
		// > Compute weighted speed.
		sumWeightedSpeed += ((double)(st2.amount - st1.amount) / deltaTime) * (double)i;
		sumWeight += i;
	}
	
	return sumWeightedSpeed / (double)sumWeight;
}

- (NSTimeInterval)remainingTime
{
	__block NSTimeInterval result;
	
	dispatch_sync(_localQueue, ^{
		result = [self _remainingTime];
	});
	
	return result;
}

- (NSTimeInterval)_remainingTime
{
	// > localQueue <

	double speed = [self _averageSpeed];
	
	if (speed == -2.0)
		return -2.0;
	
	if (speed == 0.0)
		return -1.0;
	
	NSUInteger remainingAmount = _completeAmount - _currentAmount;
	
	return (double)remainingAmount / speed;
}

@end


NS_ASSUME_NONNULL_END
