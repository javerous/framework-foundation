/*
 *  SMSpeedHelper.m
 *
 *  Copyright 2018 Avérous Julien-Pierre
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

#import <os/lock.h>

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
	os_unfair_lock _internalLock;
	
	NSUInteger	_currentAmount;
	NSUInteger	_completeAmount;
	
	double			_lastSet;
	NSMutableArray		*_statements;
	SMSpeedStatement	*_freeStatement;

	dispatch_source_t	_timer;
	
	void (^_updateHandler)(SMSpeedHelper *);
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
		_internalLock = OS_UNFAIR_LOCK_INIT;
		
		_completeAmount = amount;
		
		_statements = [[NSMutableArray alloc] init];
	}
	
	return self;
}



/*
** SMSpeedHelper - Properties
*/
#pragma mark - SMSpeedHelper - Properties

- (void)setUpdateHandler:(void (^ _Nullable)(SMSpeedHelper *))updateHandler
{
	os_unfair_lock_lock(&_internalLock);
	{
		_updateHandler = updateHandler;

		if (!_updateHandler && _timer)
		{
			dispatch_source_cancel(_timer);
			_timer = nil;
		}
	}
	os_unfair_lock_unlock(&_internalLock);
}

- (void (^ _Nullable)(SMSpeedHelper *))updateHandler
{
	void (^result)(SMSpeedHelper *) = nil;
	
	os_unfair_lock_lock(&_internalLock);
	{
		result = _updateHandler;
	}
	os_unfair_lock_unlock(&_internalLock);

	return result;
}


/*
** SMSpeedHelper - Update
*/
#pragma mark - SMSpeedHelper - Update

- (void)setCurrentAmount:(NSUInteger)currentAmout
{
	double ts = SMTimeStamp();
	
	os_unfair_lock_lock(&_internalLock);
	{
		[self _setCurrentAmount:currentAmout timestamp:ts];
	}
	os_unfair_lock_unlock(&_internalLock);
}

- (void)addAmount:(NSUInteger)amount
{
	double ts = SMTimeStamp();

	os_unfair_lock_lock(&_internalLock);
	{
		NSUInteger newAmount = _currentAmount + amount;
		
		[self _setCurrentAmount:newAmount timestamp:ts];
	}
	os_unfair_lock_unlock(&_internalLock);
}


- (void)_setCurrentAmount:(NSUInteger)currentAmout timestamp:(double)ts
{
	// > internalLock <
	
	// Check parameters.
	if (currentAmout == 0 || currentAmout <= _currentAmount || currentAmout > _completeAmount)
		return;
	
	// Update stats.
	_currentAmount = currentAmout;

	// Optimization.
	if (ts - _lastSet < 1.0)
		return;
	
	_lastSet = ts;

	// Add statement.
	SMSpeedStatement *statement;
	
	if (_freeStatement)
	{
		statement = _freeStatement;
		_freeStatement = nil;
	}
	else
		statement = [[SMSpeedStatement alloc] init];

	statement.amount = _currentAmount;
	statement.timestamp = ts;
	
	[_statements addObject:statement];
	
	// Remove older statement.
	if (_statements.count > 10)
	{
		_freeStatement = [_statements objectAtIndex:0];
		[_statements removeObjectAtIndex:0];
	}
	
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
			
			__auto_type updateHandler = strongSelf.updateHandler;

			if (updateHandler)
				updateHandler(strongSelf);
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
	double result;
	
	os_unfair_lock_lock(&_internalLock);
	{
		result = [self _averageSpeed];
	}
	os_unfair_lock_unlock(&_internalLock);
	
	return result;
}

- (double)_averageSpeed
{
	// > internalLock <
	
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
	NSTimeInterval result;
	
	os_unfair_lock_lock(&_internalLock);
	{
		result = [self _remainingTime];
	}
	os_unfair_lock_unlock(&_internalLock);
	
	return result;
}

- (NSTimeInterval)_remainingTime
{
	// > internalLock <

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
