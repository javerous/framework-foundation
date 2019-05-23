/*
 *  SMOperationsQueue.m
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

#import "SMOperationsQueue.h"


NS_ASSUME_NONNULL_BEGIN


/*
** BSTOperationsItem - Interface
*/
#pragma mark - BSTOperationsItem - Interface

@interface BSTOperationsItem : NSObject

@property (strong, nonatomic) SMOperationsQueue	*operations;

@property (strong, nonatomic) SMOperationsCancelableBlock	block;
@property (strong, nonatomic) dispatch_queue_t				queue;

@end



/*
** SMOperationsQueue - Private
*/
#pragma mark - SMOperationsQueue - Private

@interface SMOperationsQueue ()
{
	dispatch_queue_t _localQueue;
	dispatch_queue_t _userQueue;

	NSMutableArray	*_pending;
	BOOL			_isExecuting;
	BOOL			_isStarted;
	
	NSMutableArray	*_cancelBlocks;
	BOOL			_isCanceled;
	
	BOOL			_isFinished;
}

@end



/*
** SMOperationsQueue
*/
#pragma mark - SMOperationsQueue

@implementation SMOperationsQueue


/*
** SMOperationsQueue - Instance
*/
#pragma mark - SMOperationsQueue - Instance

- (instancetype)init
{
    self = [super init];
	
    if (self)
	{
        _pending = [[NSMutableArray alloc] init];
		
		_localQueue = dispatch_queue_create("com.smfoundation.operation-queue.local", DISPATCH_QUEUE_SERIAL);
		_userQueue = dispatch_queue_create("com.smfoundation.operation-queue.user", DISPATCH_QUEUE_SERIAL);
    }
	
    return self;
}

- (instancetype)initStarted
{
	self = [self init];
	
	if (self)
	{
		_isStarted = YES;
	}
	
	return self;
}



/*
** SMOperationsQueue - Life
*/
#pragma mark - SMOperationsQueue - Life

- (void)start
{
	dispatch_async(_localQueue, ^{
		
		if (_isStarted)
			return;
		
		_isStarted = YES;
		
		[self _continue];
	});
}



/*
** SMOperationsQueue - Schedule
*/
#pragma mark - SMOperationsQueue - Schedule

- (void)scheduleBlock:(SMOperationsBlock)block
{
	NSAssert(block, @"block is nil");

	[self scheduleCancelableBlock:^(SMOperationsControl ctrl, SMOperationsAddCancelBlock addCancelBlock) {
		block(ctrl);
	}];
}

- (void)scheduleOnQueue:(nullable dispatch_queue_t)queue block:(SMOperationsBlock)block
{
	NSAssert(block, @"block is nil");

	[self scheduleCancelableOnQueue:queue block:^(SMOperationsControl ctrl, SMOperationsAddCancelBlock addCancelBlock) {
		block(ctrl);
	}];
}

- (void)scheduleCancelableBlock:(SMOperationsCancelableBlock)block
{
	NSAssert(block, @"block is nil");

	[self scheduleCancelableOnQueue:nil block:block];
}

- (void)scheduleCancelableOnQueue:(nullable dispatch_queue_t)queue block:(SMOperationsCancelableBlock)block
{
	NSAssert(block, @"block is nil");

	if (!queue)
	{
		queue = _defaultQueue;
		
		if (!queue)
			queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	}
	
	BSTOperationsItem *item = [[BSTOperationsItem alloc] init];
	
	item.operations = self;
	item.queue = (dispatch_queue_t)queue;
	item.block = block;
	
	dispatch_async(_localQueue, ^{
		
		if (_isCanceled)
			return;
		
		if (_isExecuting == NO && _isStarted == YES)
			[self _executeItem:item];
		else
			[_pending addObject:item];
	});
}

- (void)cancel
{
	dispatch_async(_localQueue, ^{
		
		if (_isCanceled)
			return;
		
		_isCanceled = YES;
		
		// Nothing cancelable.
		if (_isFinished)
			return;
		
		// Call current cancel blocks.
		for (dispatch_block_t block in _cancelBlocks)
			dispatch_async(_userQueue, block);
		
		[_cancelBlocks removeAllObjects];
		
		// Call cancel handler.
		void (^tHandler)(BOOL canceled) = self.finishHandler;
		
		if (tHandler)
			dispatch_async(_userQueue, ^{ tHandler(YES); });
		
		// Remove pending.
		[_pending removeAllObjects];
	});
}


/*
** SMOperationsQueue - Helpers
*/
#pragma mark - SMOperationsQueue - Helpers

- (void)_scheduleNextItem
{
	// > localQueue <
	
	if (_pending.count == 0)
		return;
	
	BSTOperationsItem *item = _pending[0];
	
	[_pending removeObjectAtIndex:0];
	
	[self _executeItem:item];
}

- (void)_executeItem:(BSTOperationsItem *)item
{
	// > localQueue <
	
	NSAssert(item, @"item is nil");
	
	// Mark as executing.
	_isExecuting = YES;
	_isFinished = NO;
	
	// Execute block.
	dispatch_async(item.queue, ^{
		
		// > Controller.
		__block BOOL executed = NO;
		
		SMOperationsControl ctrl = ^(SMOperationsControlType type) {
			
			dispatch_async(_localQueue, ^{
				
				NSAssert(!executed, @"control already executed");
				
				executed = YES;
				_isExecuting = NO;
				_cancelBlocks = nil;
				
				switch (type)
				{
					case SMOperationsControlContinue:
					{
						[self _continue];
						break;
					}
						
					case SMOperationsControlFinish:
					{
						[self _stop];
						break;
					}
				}
			});
		};
		
		// > Cancelation.
		SMOperationsAddCancelBlock addCancelBlock = ^(dispatch_block_t cancelBlock) {
			
			NSAssert(cancelBlock, @"cancelBlock is nil");

			
			dispatch_async(_localQueue, ^{
				
				// Can't add cancel block after the operation is fully executed.
				NSAssert(!executed, @"control already executed");
				
				// If already canceled, cancel right now.
				if (_isCanceled)
				{
					dispatch_async(_userQueue, ^{
						cancelBlock();
					});
					return;
				}
				
				// Store cancel block.
				if (!_cancelBlocks)
					_cancelBlocks = [[NSMutableArray alloc] init];
				
				[_cancelBlocks addObject:cancelBlock];
			});
		};
		
		// > Call block.
		item.block(ctrl, addCancelBlock);
	});
}



/*
** SMOperationsQueue - Control
*/
#pragma mark - SMOperationsQueue - Control

- (void)_continue
{
	// > localQueue <

	if (_isCanceled)
		return;
	
	void (^tHandler)(BOOL canceled) = self.finishHandler;

	if (_pending.count > 0)
	{
		[self _scheduleNextItem];
	}
	else
	{
		_isFinished = YES;
		
		if (tHandler)
			dispatch_async(_userQueue, ^{ tHandler(NO); });
	}
}

- (void)_stop
{
	// > localQueue <

	if (_isCanceled)
		return;
	
	_isFinished = YES;
	
	[_pending removeAllObjects];
	
	void (^tHandler)(BOOL canceled) = self.finishHandler;

	if (tHandler)
		dispatch_async(_userQueue, ^{ tHandler(NO); });
}

@end



/*
** BSTOperationsItem
*/
#pragma mark - BSTOperationsItem

@implementation BSTOperationsItem

@end


NS_ASSUME_NONNULL_END
