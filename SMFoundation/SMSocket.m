/*
 *  SMSocket.m
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

#include <netdb.h>

#import "SMSocket.h"

#import "SMDebugLog.h"
#import "SMBuffer.h"
#import "SMInfo.h"


NS_ASSUME_NONNULL_BEGIN


/*
** Prototypes
*/
#pragma mark - Prototypes

static BOOL doAsyncSocket(int sock);



/*
** SMSocketOperationHandler
*/
#pragma mark - SMSocketOperationHandler

@interface SMSocketOperationHandler : NSObject

@property (assign, nonatomic) SMSocketOperation		operation;
@property (assign, nonatomic) NSUInteger			size;
@property (assign, nonatomic) NSUInteger			tag;
@property (strong, nonatomic, nullable) id			context;

@end



/*
** SMSocket - Private
*/
#pragma mark - SMSocket - Private

@interface SMSocket ()
{
	// -- Vars --
	// > Managed socket
	int					_sock;
	
	// > Queue & Sources
	dispatch_queue_t	_socketQueue;
	
	dispatch_source_t	_tcpReader;
	dispatch_source_t	_tcpWriter;
	
	// > Buffer
	SMBuffer			*_readBuffer;
	SMBuffer			*_writeBuffer;
	bool				_writeActive;
	
	// > Delegate
	dispatch_queue_t	_delegateQueue;
	__weak id <SMSocketDelegate> _delegate;
	
	// > Operations
	SMSocketOperationHandler	*_goperation;
	NSMutableArray				*_operations;
}

// -- Errors --
- (void)callError:(SMSocketError) error fatal:(BOOL)fatal;

// -- Data Input --
- (void)_dataAvailable;
- (BOOL)_runOperation:(SMSocketOperationHandler *)operation;

@end



/*
** SMSocket
*/
#pragma mark - SMSocket

@implementation SMSocket


/*
** SMSocket - Instance
*/
#pragma mark - SMSocket - Instance

+ (void)initialize
{
	[self registerInfoDescriptors];
}

- (nullable instancetype)initWithIP:(NSString *)ip port:(uint16_t)port
{
	NSAssert(ip, @"ip is nil");
	
	// Configure resolution.
	struct addrinfo hints;
	
	memset(&hints, 0, sizeof(hints));
	
	hints.ai_family = PF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;
	hints.ai_protocol = IPPROTO_TCP;
	hints.ai_flags = AI_NUMERICHOST | AI_NUMERICSERV;
	
	// Resolve.
	struct addrinfo	*res0;
	int				error;
 
	error = getaddrinfo(ip.UTF8String, [NSString stringWithFormat:@"%u", port].UTF8String, &hints, &res0);
	
	if (error)
		return nil;
	
	// Search for the first valid resolution.
	struct addrinfo *res;
	int				sock;
	
	for (res = res0; res; res = res->ai_next)
	{
		sock = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
		
		if (sock < 0)
			continue;
		
		if (connect(sock, res->ai_addr, res->ai_addrlen) < 0)
		{
			close(sock);
			continue;
		}
		
		// Valid one.
		freeaddrinfo(res0);
		
		return [self initWithSocket:sock];
	}

	return nil;
}

- (instancetype)initWithSocket:(int)descriptor
{
	self = [super init];
	
	if (self)
	{
		// -- Set vars --
		_sock = descriptor;

		// -- Configure socket as asynchrone --
		doAsyncSocket(_sock);
		
		// -- Create Buffer --
		_readBuffer = [[SMBuffer alloc] init];
		_writeBuffer = [[SMBuffer alloc] init];
		
		// Create containers.
		_operations = [[NSMutableArray alloc] init];
		
		// -- Create Queue --
		_socketQueue = dispatch_queue_create("com.smfoundation.socket.main", DISPATCH_QUEUE_SERIAL);
		_delegateQueue = dispatch_queue_create("com.smfoundation.socket.delegate", DISPATCH_QUEUE_SERIAL);

		// -- Build Read / Write Source --
		_tcpReader = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)_sock, 0, _socketQueue);
		_tcpWriter = dispatch_source_create(DISPATCH_SOURCE_TYPE_WRITE, (uintptr_t)_sock, 0, _socketQueue);
		
		// Set the read handler
		dispatch_source_set_event_handler(_tcpReader, ^{
			
			// Build a buffer to read available data
			size_t		estimate = dispatch_source_get_data(_tcpReader);
			void		*buffer = malloc(estimate);
			ssize_t		sz;
			
			// Read data
			sz = read(_sock, buffer, estimate);
			
			// Check read result
			if (sz < 0)
			{
				[self callError:SMSocketErrorRead fatal:YES];
				free(buffer);
			}
			else if (sz == 0 && errno != EAGAIN)
			{
				[self callError:SMSocketErrorReadClosed fatal:YES];
				free(buffer);
			}
			else if (sz > 0)
			{
				if ([_readBuffer size] + (size_t)sz > 50 * 1024 * 1024)
				{
					[self callError:SMSocketErrorReadFull fatal:YES];
					free(buffer);
				}
				else
				{
					// Append data to the buffer
					[_readBuffer appendBytes:buffer size:(NSUInteger)sz copy:NO];
					
					// Manage datas
					[self _dataAvailable];
				}
			}
			else
				free(buffer);
		});
		
		// Set the read handler
		dispatch_source_set_event_handler(_tcpWriter, ^{
			
			// If we are no more data, deactivate the write event, else write them
			if ([_writeBuffer size] == 0)
			{
				if (_writeActive)
				{
					_writeActive = false;
					dispatch_suspend(_tcpWriter);
				}
			}
			else
			{
				char		buffer[4096];
				NSUInteger	size = [_writeBuffer readBytes:buffer size:sizeof(buffer)];
				ssize_t		sz;
				
				// Write data
				sz = write(_sock, buffer, size);
				
				// Check write result
				if (sz < 0)
				{
					[self callError:SMSocketErrorWrite fatal:YES];
				}
				else if (sz == 0 && errno != EAGAIN)
				{
					[self callError:SMSocketErrorWriteClosed fatal:YES];
				}
				else if (sz > 0)
				{
					// Reinject remaining data in the buffer
					if (sz < size)
						[_writeBuffer pushBytes:buffer + sz size:(size - (NSUInteger)sz) copy:YES];
					
					// If we have space, signal it to fill if necessary
					id <SMSocketDelegate> delegate = _delegate;
					
					if ([_writeBuffer size] < 1024 && _delegateQueue && delegate && [delegate respondsToSelector:@selector(socketRunPendingWrite:)])
					{
						dispatch_async(_delegateQueue, ^{
							[delegate socketRunPendingWrite:self];
						});
					}
				}
			}
		});
		
		// -- Set Cancel Handler --
		__block int count = 2;
		
		dispatch_block_t bcancel = ^{
			
			count--;
			
			if (count <= 0 && _sock != -1)
			{
				// Close the socket
				close(_sock);
				_sock = -1;
			}
		};
		
		dispatch_source_set_cancel_handler(_tcpReader, bcancel);
		dispatch_source_set_cancel_handler(_tcpWriter, bcancel);
		
		// -- Resume Read Source --
		dispatch_resume(_tcpReader);
	}
	
	return self;
}

- (void)dealloc
{
	SMDebugLog(@"SMSocket dealloc");
}


/*
** SMSocket - Delegate
*/
#pragma mark - SMSocket - Delegate

- (void)setDelegate:(nullable id<SMSocketDelegate>)delegate
{
	dispatch_async(_socketQueue, ^{
		
		// Hold delegate.
		_delegate = delegate;
		
		if (!delegate)
			return;

		// Check if some data can send to the new delegate
		if ([_readBuffer size] > 0)
			[self _dataAvailable];
	});
}

- (nullable id <SMSocketDelegate>)delegate
{
	__block id <SMSocketDelegate> delegate;
	
	dispatch_sync(_socketQueue, ^{
		delegate = _delegate;
	});
	
	return delegate;
}



/*
** SMSocket - Sending
*/
#pragma mark - SMSocket - Sending

- (BOOL)sendBytes:(const void *)bytes size:(NSUInteger)size copy:(BOOL)copy
{
	NSAssert(bytes, @"bytes is NULL");
	NSAssert(size > 0, @"size is zero");
	
	void *cpy = NULL;
	
	// Copy data if needed.
	if (copy)
	{
		cpy = malloc(size);
		
		memcpy(cpy, bytes, size);
	}
	else
		cpy = (void *)bytes;
	
	// Put data in send buffer, and activate sending if needed.
	dispatch_async(_socketQueue, ^{
		
		// Check that we can alway write
		if (!_tcpWriter)
		{
			free(cpy);
			return;
		}
		
		// Append data in write buffer
		[_writeBuffer appendBytes:cpy size:size copy:NO];
		
		// Activate write if needed
		if ([_writeBuffer size] > 0 && !_writeActive)
		{
			_writeActive = YES;
			
			dispatch_resume(_tcpWriter);
		}
	});
	
	return true;
}

- (BOOL)sendBuffer:(SMBuffer *)buffer
{
	if ([buffer size] == 0)
		return NO;
	
	return NO;
}



/*
** SMSocket - Operations
*/
#pragma mark - SMSocket - Operations

- (void)setGlobalOperation:(SMSocketOperation)operation size:(NSUInteger)size tag:(NSUInteger)tag
{
	dispatch_async(_socketQueue, ^{
		
		// Create global operation.
		_goperation = [[SMSocketOperationHandler alloc] init];
		
		_goperation.operation = operation;
		_goperation.size = size;
		_goperation.tag = tag;
		
		// Check if operations can be executed.
		if ([_readBuffer size] > 0)
			[self _dataAvailable];
	});
}

- (void)removeGlobalOperation
{
	dispatch_async(_socketQueue, ^{
		_goperation = nil;
	});
}

- (void)scheduleOperation:(SMSocketOperation)operation size:(NSUInteger)size tag:(NSUInteger)tag
{
	dispatch_async(_socketQueue, ^{
		
		// Create global operation.
		SMSocketOperationHandler *op = [[SMSocketOperationHandler alloc] init];
		
		op.operation = operation;
		op.size = size;
		op.tag = tag;
		
		// Add the operation.
		[_operations addObject:op];
		
		// Check if operations can be executed.
		if ([_readBuffer size] > 0)
			[self _dataAvailable];
	});
}



/*
** SMSocket - Life
*/
#pragma mark - SMSocket - Life

- (void)stop
{
	dispatch_async(_socketQueue, ^{
		
		if (_tcpWriter)
		{
			// Resume the source if suspended.
			if (!_writeActive)
				dispatch_resume(_tcpWriter);
			
			// Cancel & release it
			dispatch_source_cancel(_tcpWriter);
			_tcpWriter = nil;
		}
		
		if (_tcpReader)
		{
			// Cancel & release the source.
			dispatch_source_cancel(_tcpReader);
			_tcpReader = nil;
		}
	});
}



/*
** SMSocket - Errors
*/
#pragma mark - SMSocket - Errors

- (void)callError:(SMSocketError)error fatal:(BOOL)fatal
{
	// If fatal, just stop.
	if (fatal)
		[self stop];
	
	// Check delegate
	id <SMSocketDelegate> delegate = _delegate;
	
	if (!delegate)
		return;
	
	if ([delegate respondsToSelector:@selector(socket:error:)] == NO)
		return;
	
	SMInfo *err = [SMInfo infoOfKind:SMInfoError domain:SMSocketInfoDomain code:error];
	
	// Dispatch on the delegate queue.
	dispatch_async(_delegateQueue, ^{
		[delegate socket:self error:err];
	});
}



/*
** SMSocket - Data Input
*/
#pragma mark - SMSocket - Data Input

- (void)_dataAvailable
{
	// > socketQueue <
		
	// Check if we have a global operation, else execute scheduled operation.
	if (_goperation)
	{
		while (1)
		{
			if (![self _runOperation:_goperation])
				break;
		}
	}
	else
	{
		NSMutableIndexSet	*indexes = [[NSMutableIndexSet alloc] init];
		NSUInteger			i, count = _operations.count;
		
		for (i = 0; i < count; i++)
		{
			SMSocketOperationHandler *op = _operations[i];
			
			if ([self _runOperation:op])
				[indexes addIndex:i];
			else
				break;
		}
		
		[_operations removeObjectsAtIndexes:indexes];
	}
}

- (BOOL)_runOperation:(SMSocketOperationHandler *)operation
{
	// > socketQueue <
	
	NSAssert(operation, @"operation is nil");
	
	// Check delegate.
	id <SMSocketDelegate> delegate = _delegate;
	
	if (!delegate)
		return NO;
	
	// Nothing to read, nothing to do.
	if ([_readBuffer size] == 0)
		return false;
	
	// Execute the  operation.
	switch (operation.operation)
	{
		// Operation is to read a chunk of raw data.
		case SMSocketOperationData:
		{
			// Get the amount to read.
			NSUInteger size = operation.size;
			
			if (size == 0)
				size = [_readBuffer size];
			
			if (size > [_readBuffer size])
				return NO;
			
			void		*buffer = malloc(size);
			NSUInteger	tag = operation.tag;
			NSData		*data;
			
			// Read the chunk of data.
			size = [_readBuffer readBytes:buffer size:size];
			
			data = [[NSData alloc] initWithBytesNoCopy:buffer length:size freeWhenDone:YES];
			
			// -- Give to delegate --
			dispatch_async(_delegateQueue, ^{
				[delegate socket:self operationAvailable:SMSocketOperationData tag:tag content:data];
			});
			
			return YES;
		}
			
		// Operation is to read lines.
		case SMSocketOperationLine:
		{
			NSUInteger		max = operation.size;
			NSMutableArray	*lines = NULL;
			NSUInteger		tag = operation.tag;
			
			// Build lines vector
			if (operation.context)
				lines = operation.context;
			else
			{
				lines = [[NSMutableArray alloc] init];
				
				operation.context = lines;
			}
			
			// Parse lines
			while (1)
			{
				// Check that we have the amount of line needed.
				if (max > 0 && lines.count >= max)
					break;
				
				// Get line
				NSData *line = [_readBuffer dataUpToCStr:"\n" includeSearch:NO];
								
				if (!line)
					break;
				
				// Add the line
				[lines addObject:line];
			}
			
			// Check that we have lines
			if (lines.count == 0)
				return NO;
			
			// Check that we have enought lines.
			if (max > 0 && lines.count < max)
				return NO;
			
			// Clean context (the delegate is responsive to deallocate lines).
			operation.context = nil;
						
			// -- Give to delegate --
			dispatch_async(_delegateQueue, ^{
				[delegate socket:self operationAvailable:SMSocketOperationLine tag:tag content:lines];
			});
			
			return YES;
		}
	}
	
	return NO;
}



/*
** SMSocket - Infos
*/
#pragma mark - SMSocket - Infos

+ (void)registerInfoDescriptors
{
	NSMutableDictionary *descriptors = [[NSMutableDictionary alloc] init];
	
	// == SMSocketInfoDomain ==
	descriptors[SMSocketInfoDomain] = ^ NSDictionary * (SMInfoKind kind, int code) {
		
		switch (kind)
		{
			case SMInfoInfo:
			{
				break;
			}
			
			case SMInfoWarning:
			{
				break;
			}
				
			case SMInfoError:
			{
				switch ((SMSocketError)code)
				{
					case SMSocketErrorRead:
					{
						return @{
							SMInfoNameKey : @"SMSocketErrorRead",
							SMInfoTextKey : @"core_socket_read_error",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case SMSocketErrorReadClosed:
					{
						return @{
							SMInfoNameKey : @"SMSocketErrorReadClosed",
							SMInfoTextKey : @"core_socket_read_closed",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case SMSocketErrorReadFull:
					{
						return @{
							SMInfoNameKey : @"SMSocketErrorReadFull",
							SMInfoTextKey : @"core_socker_read_full",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case SMSocketErrorWrite:
					{
						return @{
							SMInfoNameKey : @"SMSocketErrorWrite",
							SMInfoTextKey : @"core_socket_write_error",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case SMSocketErrorWriteClosed:
					{
						return @{
							SMInfoNameKey : @"SMSocketErrorWriteClosed",
							SMInfoTextKey : @"core_socket_write_closed",
							SMInfoLocalizableKey : @YES,
						};
					}
				}
				
				break;
			}
		}
		
		return nil;
	};
	
	[SMInfo registerDomainsDescriptors:descriptors localizer:^NSString * _Nonnull(NSString * _Nonnull token) {
		return SMLocalizedString(token, @"");
	}];
}

@end



/*
** SMSocketOperationHandler
*/
#pragma mark - SMSocketOperationHandler

@implementation SMSocketOperationHandler

@end



/*
** Tools
*/
#pragma mark - Tools

// == Use async I/O on a socket ==
static BOOL doAsyncSocket(int sock)
{
	// Set as non blocking
	int arg = fcntl(sock, F_GETFL, NULL);
	
	if (arg == -1)
		return false;
	
	arg |= O_NONBLOCK;
	arg = fcntl(sock, F_SETFL, arg);
	
	if (arg == -1)
		return false;
	
	return true;
}


NS_ASSUME_NONNULL_END
