/*
 *  SMOperationsQueue.h
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
	SMOperationsControlContinue,
	SMOperationsControlFinish
} SMOperationsControlType;

typedef void (^SMOperationsControl)(SMOperationsControlType type);
typedef void (^SMOperationsBlock)(SMOperationsControl ctrl);

typedef void (^SMOperationsAddCancelBlock)(dispatch_block_t block);
typedef void (^SMOperationsCancelableBlock)(SMOperationsControl ctrl, SMOperationsAddCancelBlock addCancelBlock);


/*
** SMOperationsQueue
*/
#pragma mark - SMOperationsQueue

@interface SMOperationsQueue : NSObject

// -- Properties --
@property (strong, atomic, nullable) dispatch_queue_t defaultQueue;

// -- Instance --
- (id)init;
- (id)initStarted;

// -- Schedule --
- (void)scheduleBlock:(SMOperationsBlock)block;
- (void)scheduleOnQueue:(nullable dispatch_queue_t)queue block:(SMOperationsBlock)block;

- (void)scheduleCancelableBlock:(SMOperationsCancelableBlock)block;
- (void)scheduleCancelableOnQueue:(nullable dispatch_queue_t)queue block:(SMOperationsCancelableBlock)block;


// -- Life --
- (void)start;

- (void)cancel;


// -- Handler --
@property (strong, atomic, nullable) void (^finishHandler)(BOOL canceled); // Called each time the operation queue become empty or queue was canceled.

@end


NS_ASSUME_NONNULL_END
