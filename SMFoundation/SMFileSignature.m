/*
 *  SMFileSignature.m
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

#import <Security/Security.h>

#import <CommonCrypto/CommonCrypto.h>
#import <dlfcn.h>

#import "SMFileSignature.h"

#import "SMSignatureHelper.h"


NS_ASSUME_NONNULL_BEGIN


/*
** SMFileSignature
*/
#pragma mark - SMFileSignature

@implementation SMFileSignature


/*
** SMFileSignature - Key Generation
*/
#pragma mark - SMFileSignature - Key Generation

+ (nullable NSDictionary *)generateKeyPairsOfSize:(NSUInteger)keySize
{
	// Configure generation.
	NSMutableDictionary	*keyPairAttr = [[NSMutableDictionary alloc] init];

	keyPairAttr[(id)kSecAttrKeyType] = (id)kSecAttrKeyTypeRSA;
	keyPairAttr[(id)kSecAttrKeySizeInBits] = @(keySize);
	
	// Generate.
	SecKeyRef	publicKeyRef;
	SecKeyRef	privateKeyRef;
	OSStatus	err;
	
	err = SecKeyGeneratePair((__bridge CFDictionaryRef)keyPairAttr, &publicKeyRef, &privateKeyRef);
	
	if (err != noErr)
		return nil;
	
	// Convert to data.
	NSData *publicKeyData = [self dataFromKey:publicKeyRef];
	NSData *privateKeyData = [self dataFromKey:privateKeyRef];
	
	if (!publicKeyData || !privateKeyData)
		return nil;

	// Return.
	return @{ SMPrivateKeyData : privateKeyData, SMPublicKeyData : publicKeyData };
}



/*
** SMFileSignature - Signatures
*/
#pragma mark - SMFileSignature - Signatures

+ (nullable NSData *)signedDataWithContentsOfURL:(NSURL *)url privateKey:(NSData *)privateKey
{
	NSAssert(url, @"url is nil");
	NSAssert(privateKey, @"privateKey is nil");

	// Import key.
	SecKeyRef sPrivateKey = [SMSignatureHelper copyKeyFromData:privateKey isPrivate:YES];

	if (!sPrivateKey)
		return nil;

	// Declarations.
	NSData			*result = nil;
	SecTransformRef signingTransform = NULL;
	CFReadStreamRef	readStream = NULL;

	// Create fstream.
	readStream = CFReadStreamCreateWithFile(kCFAllocatorDefault, (__bridge CFURLRef)url);
	
	if (!readStream)
		goto end;
		
	if (CFReadStreamOpen(readStream) != true)
		goto end;

	// Create signature transform.
	signingTransform = SecSignTransformCreate(sPrivateKey, NULL);
	
	if (signingTransform == NULL)
		goto end;

	if (SecTransformSetAttribute(signingTransform, kSecPaddingKey, kSecPaddingPKCS1Key, NULL) != true)
		goto end;

	if (SecTransformSetAttribute(signingTransform, kSecInputIsAttributeName, kSecInputIsPlainText, NULL) != true)
		goto end;

	if (SecTransformSetAttribute(signingTransform, kSecDigestTypeAttribute, kSecDigestSHA2, NULL) != true)
		goto end;
	
	if (SecTransformSetAttribute(signingTransform, kSecDigestLengthAttribute, (__bridge CFNumberRef)@(256), NULL) != true)
		goto end;

	// Set signature input.
	SecTransformSetAttribute(signingTransform, kSecTransformInputAttributeName, readStream, NULL);
	
	// Execute.
	result = (__bridge_transfer NSData *)SecTransformExecute(signingTransform, NULL);

end:
	if (sPrivateKey)
		CFRelease(sPrivateKey);

	if (signingTransform)
		CFRelease(signingTransform);
	
	if (readStream)
	{
		CFReadStreamClose(readStream);
		CFRelease(readStream);
	}
	
	return result;
}

+ (BOOL)validateSignature:(NSData *)signature fileURL:(NSURL *)url publicKey:(NSData *)publicKey
{
	NSAssert(signature, @"signature is nil");
	NSAssert(url, @"url is nil");
	NSAssert(publicKey, @"publicKey is nil");
	
	// Import key.
	SecKeyRef sPublicKey = [SMSignatureHelper copyKeyFromData:publicKey isPrivate:NO];
	
	if (!sPublicKey)
		return NO;
	
	// Declarations.
	NSNumber		*result = nil;
	SecTransformRef verifyTransform = NULL;
	CFReadStreamRef	readStream = NULL;
	
	// Create stream.
	readStream = CFReadStreamCreateWithFile(kCFAllocatorDefault, (__bridge CFURLRef)url);
	
	if (!readStream)
		goto end;
	
	if (CFReadStreamOpen(readStream) != true)
		goto end;
	
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
	SecTransformSetAttribute(verifyTransform, kSecTransformInputAttributeName, readStream, NULL);
	
	// Build the signature.	
	result = (__bridge_transfer NSNumber *)SecTransformExecute(verifyTransform, NULL);
	
end:
	if (sPublicKey)
		CFRelease(sPublicKey);
	
	if (verifyTransform)
		CFRelease(verifyTransform);
	
	if (readStream)
	{
		CFReadStreamClose(readStream);
		CFRelease(readStream);
	}

	return result.boolValue;
}



/*
** SMFileSignature - Key Serialization
*/
#pragma mark - SMFileSignature - Key Serialization

+ (nullable NSData *)dataFromKey:(SecKeyRef)cryptoKey
{
	NSAssert(cryptoKey, @"cryptoKey is nil");
	
    // Create and populate the parameters object with a basic set of values
    SecItemImportExportKeyParameters params;
	
    params.version = SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION;
    params.flags = 0;
    params.passphrase = NULL;
    params.alertTitle = NULL;
    params.alertPrompt = NULL;
    params.accessRef = NULL;
    params.keyUsage = NULL;
    params.keyAttributes = NULL;
	
	// Export the key to data.
	OSStatus					err;
    SecExternalFormat			externalFormat = kSecFormatOpenSSL;
    SecItemImportExportFlags	flags = 0;
    CFDataRef					keyData = NULL;
	
	err = SecItemExport(cryptoKey, externalFormat, flags, &params, &keyData);
	   
	if (err != noErr)
		return nil;
	
    return (__bridge_transfer NSData *)keyData;
}

@end


NS_ASSUME_NONNULL_END
