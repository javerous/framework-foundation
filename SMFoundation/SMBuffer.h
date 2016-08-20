/*
 *  SMBuffer.h
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
** SMBuffer
*/
#pragma mark - SMBuffer

@interface SMBuffer : NSObject

// -- Bytes --
- (void)pushBytes:(const void *)bytes size:(NSUInteger)size copy:(BOOL)copy; 	// Insert at the beggin
- (void)appendBytes:(const void *)bytes size:(NSUInteger)size copy:(BOOL)copy;	// Insert at the end

- (NSUInteger)readBytes:(void *)bytes size:(NSUInteger)size; // Read data from beggin

// -- Tools --
- (nullable NSData *)dataUpToCStr:(const char *)search includeSearch:(BOOL)includeSearch; // Read data up to the string "search"

- (void)clean;
- (void)print;

// -- Properties --
- (NSUInteger)size;

@end


NS_ASSUME_NONNULL_END
