/*
 *  SMBuffer.m
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

#import "SMBuffer.h"

#import "SMDebugLog.h"


NS_ASSUME_NONNULL_BEGIN


/*
** Types
*/
#pragma mark - Types

typedef struct _sm_item sm_item;

struct _sm_item
{
	void	*data;
	size_t	size;
	
	sm_item *next;
	sm_item *prev;
};

typedef struct _sm_items sm_items;

struct _sm_items
{
	sm_item	*first;
	sm_item	*last;
	
	size_t	size;
};



/*
** Prototypes
*/
#pragma mark - Prototypes

size_t memsearch(const uint8_t *token, size_t token_sz, const uint8_t *data, size_t data_sz);



/*
** SMBuffer - Private
*/
#pragma mark - SMBuffer - Private

@interface SMBuffer ()
{
	sm_items *_items;
}

@end



/*
** SMBuffer
*/
#pragma mark - SMBuffer

@implementation SMBuffer


/*
** SMBuffer - Instance
*/
#pragma mark - SMBuffer - Instance

- (instancetype)init
{
    self = [super init];
	
    if (self)
	{
		_items = (sm_items *)(malloc(sizeof(sm_items)));
		
		_items->first = NULL;
		_items->last = NULL;
		_items->size = 0;
    }
    return self;
}

- (void)dealloc
{
	SMDebugLog(@"SMBuffer dealloc");
	
	[self clean];
	
	free(_items);
}



/*
** SMBuffer - Bytes
*/
#pragma mark - SMBuffer - Bytes

- (void)pushBytes:(const void *)bytes size:(NSUInteger)size copy:(BOOL)copy
{
	NSAssert(size > 0, @"size is zero");
	NSAssert(bytes, @"bytes is NULL");
	
	sm_item	*item = (sm_item *)(malloc(sizeof(sm_item)));
	
	// Set data
	if (copy)
	{
		item->data = malloc(size);
		
		memcpy(item->data, bytes, size);
	}
	else
		item->data = (void *)bytes;
	
	// Set others
	item->size = size;
	item->prev = NULL;
	item->next = NULL;
	
	// Insert it
	if (_items->first)
	{
		item->next = _items->first;
		_items->first->prev = item;
	}
	_items->first = item;
	
	if (!_items->last)
		_items->last = item;
	
	// Update global size
	_items->size += size;
}

- (void)appendBytes:(const void *)bytes size:(NSUInteger)size copy:(BOOL)copy
{
	NSAssert(size > 0, @"size is zero");
	NSAssert(bytes, @"bytes is nil");
	
	sm_item	*item = (sm_item *)(malloc(sizeof(sm_item)));
	
	// Set data
	if (copy)
	{
		item->data = malloc(size);
		
		memcpy(item->data, bytes, size);
	}
	else
		item->data = (void *)bytes;
	
	// Set others
	item->size = size;
	item->prev = NULL;
	item->next = NULL;
	
	// Insert it
	item->prev = _items->last;
	
	if (_items->last)
		_items->last->next = item;
	
	_items->last = item;
	
	if (!_items->first)
		_items->first = item;
	
	// Update global size
	_items->size += size;
}

- (NSUInteger)readBytes:(void *)bytes size:(NSUInteger)size
{
	NSAssert(size > 0, @"size is zero");
	NSAssert(bytes, @"bytes is nil");
	
	size_t	readden = 0;
	sm_item	*item  = _items->first;
	
	if (size > _items->size)
		size = _items->size;
	
	while (size > 0 && item)
	{
		// Compute size to read from the item
		size_t part = 0;
		
		if (item->size > size)
			part = size;
		else
			part = item->size;
		
		// Write them
		memcpy(bytes, item->data, part);
		
		// Update status
		bytes = (char *)bytes + part;
		size -= part;
		readden += part;
		
		sm_item	*tmp = item;
		
		// Go on next
		item = item->next;
		
		// Remove item
		_items->first = tmp->next;
		if (!_items->first)
			_items->last = NULL;
		
		if (tmp->next)
			tmp->next->prev = NULL;
		
		// The block is removed, remove its size
		_items->size -= tmp->size;
		
		// Reinsert remening data
		if (part < tmp->size)
		{
			size_t	rest = tmp->size - part;
			void	*buff = malloc(rest);
			
			memcpy(buff, (char *)tmp->data + part, rest);
			
			[self pushBytes:buff size:rest copy:NO];
		}
		
		// Clean item
		free(tmp->data);
		free(tmp);
	}
	
	return readden;
}



/*
** SMBuffer - Tools
*/
#pragma mark - SMBuffer - Tools

- (nullable NSData *)dataUpToCStr:(const char *)search includeSearch:(BOOL)includeSearch
{
	NSAssert(search, @"search is NULL");
	
	bool		found = false;
	size_t		sz = 0;
	sm_item		*item = _items->first;
	
	size_t		search_len = strlen(search);
	
	size_t		pos = 0;
	
	while (item)
	{
		pos = memsearch((uint8_t *)search, search_len, (uint8_t *)item->data, item->size);
		
		if (pos != (size_t)(-1))
		{
			sz += pos + search_len;
			found = true;
			
			break;
		}
		
		sz += item->size;
		item = item->next;
	}
	
	if (found && sz > 0)
	{
		void *result = malloc(sz);
		
		[self readBytes:result size:sz];
		
		if (!includeSearch)
			sz -= search_len;
		
		return [[NSData alloc] initWithBytesNoCopy:result length:sz freeWhenDone:YES];
	}
	
	return nil;
}

- (void)clean
{
	sm_item	*item, *nitem;
	
	item = _items->first;
	
	while (item)
	{
		nitem = item->next;
		
		free(item->data);
		free(item);
		
		item = nitem;
	}
	
	_items->first = NULL;
	_items->last = NULL;
	_items->size = 0;
}

- (void)print
{
	sm_item	*item = _items->first;
	
	fprintf(stderr, "First = %p\n", item);
	
	while (item)
	{
		fprintf(stderr, "(%p; %016lu) -> ", item->data, item->size);
		
		item = item->next;
	}
	
	fprintf(stderr, "x\n");
}



/*
** SMBuffer - Properties
*/
#pragma mark - SMBuffer - Properties

- (NSUInteger)size
{
	return _items->size;
}

@end



/*
** C Function
*/
#pragma mark - C Function

// == Search a chunk of data in another chunk of data ==
size_t memsearch(const uint8_t *token, size_t token_sz, const uint8_t *data, size_t data_sz)
{
	size_t	pos = 0;
	size_t	i = 0;
	
	while (token_sz <= data_sz)
	{
		for (i = 0; i < token_sz; i++)
		{
			if (data[i] != token[i])
				break;
		}
		
		if (i >= token_sz)
			return pos;
		
		pos++;
		data++;
		data_sz--;
	}
	
	return (size_t)(-1);
}


NS_ASSUME_NONNULL_END
