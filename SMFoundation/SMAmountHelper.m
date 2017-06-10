/*
 *  SMAmountHelper.m
 *
 *  Copyright 2017 Avérous Julien-Pierre
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

#import "SMAmountHelper.h"


NS_ASSUME_NONNULL_BEGIN


/*
** Funbctions
*/
#pragma mark - Functions

NSString * SMStringFromBytesAmount(uint64_t size)
{
	// Compute GB.
	uint64_t	gb = 0;
	float		fgb;
	
	gb = size / (1024 * 1024 * 1024);
	fgb = (float)size / (float)(1024 * 1024 * 1024);
	size = size % (1024 * 1024 * 1024);
	
	// Compute MB.
	uint64_t	mb = 0;
	float		fmb;
	
	mb = size / (1024 * 1024);
	fmb = (float)size / (float)(1024 * 1024);
	size = size % (1024 * 1024);
	
	// Compute KB.
	uint64_t	kb = 0;
	float		fkb;
	
	kb = size / (1024);
	fkb = (float)size / (float)(1024);
	size = size % (1024);
	
	// Compute B.
	uint64_t b = 0;

	b = size;
	
	
	// Compose result.
	if (gb)
	{
		if (mb)
			return [NSString stringWithFormat:@"%.01f %@", fgb, SMLocalizedString(@"size_gb", @"")];
		else
			return [NSString stringWithFormat:@"%llu %@", gb, SMLocalizedString(@"size_gb", @"")];
	}
	else if (mb)
	{
		if (kb)
			return [NSString stringWithFormat:@"%.01f %@", fmb, SMLocalizedString(@"size_mb", @"")];
		else
			return [NSString stringWithFormat:@"%llu %@", mb, SMLocalizedString(@"size_mb", @"")];
	}
	else if (kb)
	{
		if (b)
			return [NSString stringWithFormat:@"%.01f %@", fkb, SMLocalizedString(@"size_kb", @"")];
		else
			return [NSString stringWithFormat:@"%llu %@", kb, SMLocalizedString(@"size_kb", @"")];
	}
	else if (b)
		return [NSString stringWithFormat:@"%llu %@", b, SMLocalizedString(@"size_b", @"")];
	
	return [NSString stringWithFormat:@"0 %@", SMLocalizedString(@"size_b", @"")];
}

NSString * SMStringFromSecondsAmount(NSTimeInterval doubleSeconds)
{
	NSUInteger seconds = (NSUInteger)doubleSeconds;
	
	// Compute days.
	NSUInteger days;
	
	days = seconds / (24 * 3600);
	seconds = seconds % (24 * 3600);

	// Compute hours.
	NSUInteger hours;
	
	hours = seconds / 3600;
	seconds = seconds % (3600);
	
	// Compute minutes.
	NSUInteger minutes;
	
	minutes = seconds / 60;
	seconds = seconds % (60);
	
	// Compose result.
	if (days)
	{
		if (hours)
			return [NSString stringWithFormat:@"%lu %@, %lu %@", days, SMLocalizedString(@"time_days", @""), hours, SMLocalizedString(@"time_hours", @"")];
		else
			return [NSString stringWithFormat:@"%lu %@", days, SMLocalizedString(@"time_days", @"")];
	}
	else if (hours)
	{
		if (minutes)
			return [NSString stringWithFormat:@"%lu %@, %lu %@", hours, SMLocalizedString(@"time_hours", @""), minutes, SMLocalizedString(@"time_minutes", @"")];
		else
			return [NSString stringWithFormat:@"%lu %@", hours, SMLocalizedString(@"time_hours", @"")];
	}
	else if (minutes)
	{
		if (seconds)
			return [NSString stringWithFormat:@"%lu %@, %lu %@", minutes, SMLocalizedString(@"time_minutes", @""), seconds, SMLocalizedString(@"time_seconds", @"")];
		else
			return [NSString stringWithFormat:@"%lu %@", minutes, SMLocalizedString(@"time_minutes", @"")];
	}
	else
		return [NSString stringWithFormat:@"%lu %@", seconds, SMLocalizedString(@"time_seconds", @"")];
}


NS_ASSUME_NONNULL_END
