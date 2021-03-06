/*
 *  SMSocket.h
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
** Globals
*/
#pragma mark - Globals

#define SMSocketInfoDomain	@"SMSocketInfoDomain"



/*
** Forward
*/
#pragma mark - Forward

@class SMSocket;
@class SMBuffer;
@class SMInfo;



/*
** Types
*/
#pragma mark - Types

// == Socket Errors ==
typedef NS_ENUM(unsigned int, SMSocketError) {
    SMSocketErrorReadClosed,
	SMSocketErrorRead,
	SMSocketErrorReadFull,
	
	SMSocketErrorWriteClosed,
	SMSocketErrorWrite,
};

// == Socket Operations ==
typedef NS_ENUM(unsigned int, SMSocketOperation) {
	SMSocketOperationData,
	SMSocketOperationLine
};



/*
** SMSocketDelegate
*/
#pragma mark - SMSocketDelegate

@protocol SMSocketDelegate <NSObject>

@required
- (void)socket:(SMSocket *)socket operationAvailable:(SMSocketOperation)operation tag:(NSUInteger)tag content:(id)content;

@optional
- (void)socket:(SMSocket *)socket error:(SMInfo *)error;
- (void)socketRunPendingWrite:(SMSocket *)socket;

@end



/*
** SMSocket
*/
#pragma mark - SMSocket

@interface SMSocket : NSObject

// -- Instance --
- (instancetype)initWithSocket:(int)descriptor NS_DESIGNATED_INITIALIZER;

- (nullable instancetype)initWithIP:(NSString *)ip port:(uint16_t)port;

- (instancetype)init NS_UNAVAILABLE;

// -- Properties --
@property (weak, atomic, nullable) id <SMSocketDelegate> delegate;

// -- Sending --
- (BOOL)sendBytes:(const void *)bytes size:(NSUInteger)size copy:(BOOL)copy;
- (BOOL)sendBuffer:(SMBuffer *)buffer;

// -- Operations --
- (void)setGlobalOperation:(SMSocketOperation)operation size:(NSUInteger)size tag:(NSUInteger)tag;
- (void)removeGlobalOperation;

- (void)scheduleOperation:(SMSocketOperation)operation size:(NSUInteger)size tag:(NSUInteger)tag;

// -- Life --
- (void)stop;

@end


NS_ASSUME_NONNULL_END
