/*
 *  SMDataSignature.m
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

#import "SMDataSignature.h"

#import "SMSignatureHelper.h"


NS_ASSUME_NONNULL_BEGIN


/*
** SMDataSignature
*/
#pragma mark - SMDataSignature

@implementation SMDataSignature

+ (BOOL)validateSignature:(NSData *)signature data:(NSData *)data publicKey:(NSData *)publicKey
{
	NSAssert(signature.length > 0, @"signature is empty");
	NSAssert(data.length > 0, @"data is empty");
	NSAssert(publicKey.length > 0, @"publicKey is empty");
	
	// Import key.
	SecKeyRef sPublicKey = [SMSignatureHelper copyKeyFromData:publicKey isPrivate:NO];
	
	if (!sPublicKey)
		return NO;
	
	// Declarations.
	NSNumber		*result = nil;
	SecTransformRef verifyTransform = NULL;
	
	// Create signature transform.
	verifyTransform = SecVerifyTransformCreate(sPublicKey, (__bridge CFDataRef)signature, NULL);
	
	if (verifyTransform == NULL)
		goto end;
	
	if (SecTransformSetAttribute(verifyTransform, kSecPaddingKey, kSecPaddingPKCS1Key, NULL) != true)
		goto end;
	
	if (SecTransformSetAttribute(verifyTransform, kSecInputIsAttributeName, kSecInputIsPlainText, NULL) != true)
		goto end;
	
	if (SecTransformSetAttribute(verifyTransform, kSecDigestTypeAttribute, kSecDigestSHA2, NULL) != true)
		goto end;
	
	if (SecTransformSetAttribute(verifyTransform, kSecDigestLengthAttribute, (__bridge CFNumberRef)@(256), NULL) != true)
		goto end;
	
	// Set signature input.
	SecTransformSetAttribute(verifyTransform, kSecTransformInputAttributeName, (__bridge CFDataRef)data, NULL);
	
	// Build the signature.
	result = (__bridge_transfer NSNumber *)SecTransformExecute(verifyTransform, NULL);
	
end:
	if (sPublicKey)
		CFRelease(sPublicKey);
	
	if (verifyTransform)
		CFRelease(verifyTransform);

	return result.boolValue;
}

@end


NS_ASSUME_NONNULL_END
