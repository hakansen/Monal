//
//  AESGcm.m
//  Monal
//
//  Created by Anurodh Pokharel on 4/19/19.
//  Copyright © 2019 Monal.im. All rights reserved.
//

#import "AESGcm.h"
#import <MLCrypto/MLCrypto-Swift.h>

#if !TARGET_OS_MACCATALYST
#include <openssl/evp.h>
#include <openssl/rand.h>
#endif

@implementation AESGcm

+ (MLEncryptedPayload *) encrypt:(NSData *)body keySize:(int) keySize {
    if (@available(iOS 13.0, *)) {
        MLCrypto *crypto = [[MLCrypto alloc] init];
        uint8_t randomBytes[keySize];
        int result = SecRandomCopyBytes(kSecRandomDefault, keySize, randomBytes);
        if(result!=0) return nil;
        NSData *gcmKey = [[NSData alloc] initWithBytes:randomBytes length:keySize];

        EncryptedPayload *payload = [crypto encryptGCMWithKey:gcmKey decryptedContent:body];

        NSMutableData *combinedKey  = [NSMutableData dataWithData:gcmKey];
        [combinedKey appendData:payload.tag];
        MLEncryptedPayload *toreturn = [[MLEncryptedPayload alloc] initWithBody:payload.body key:combinedKey iv:payload.iv authTag:payload.tag];

        return  toreturn;

    }
    else
    {
#if !TARGET_OS_MACCATALYST
        EVP_CIPHER_CTX *ctx =EVP_CIPHER_CTX_new();
        int outlen;
        unsigned char outbuf[body.length];
        unsigned char tag[16];
        
        //genreate key and iv
        
        unsigned char key[keySize];
        RAND_bytes(key, sizeof(key));
        
        unsigned char iv[12];
        RAND_bytes(iv, sizeof(iv));
        
        NSData *gcmKey = [[NSData alloc] initWithBytes:key length:keySize];
        
        NSData *gcmiv= [[NSData alloc] initWithBytes:iv length:12];
        
        NSMutableData *encryptedMessage;
        
        ctx = EVP_CIPHER_CTX_new();
        /* Set cipher type and mode */
        if(keySize==16) {
            EVP_EncryptInit_ex(ctx, EVP_aes_128_gcm(), NULL, NULL, NULL);
        }
        
        if(keySize==32) {
            EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL);
        }
        /* Set IV length if default 96 bits is not approp riate */
        EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, (int) gcmiv.length, NULL);
        /* Initialise key and IV */
        EVP_EncryptInit_ex(ctx, NULL, NULL, gcmKey.bytes, gcmiv.bytes);
        EVP_CIPHER_CTX_set_padding(ctx,1);
        /* Encrypt plaintext */
        EVP_EncryptUpdate(ctx, outbuf, &outlen,body.bytes,(int)body.length);
        
        encryptedMessage = [NSMutableData dataWithBytes:outbuf length:outlen];
        
        /* Finalise: note get no output for GCM */
        EVP_EncryptFinal_ex(ctx, outbuf, &outlen);
        
        
        /* Get tag */
        EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, 16, tag);
        //[encryptedMessage appendBytes:tag length:16];
        
        NSMutableData *combinedKey  = [NSMutableData dataWithData:gcmKey];
        [combinedKey appendBytes:tag length:16];
        
        
        EVP_CIPHER_CTX_free(ctx);
        MLEncryptedPayload *toreturn = [[MLEncryptedPayload alloc] initWithBody:encryptedMessage key:combinedKey iv:gcmiv authTag:[NSData dataWithBytes:tag length:16]];
        
        return  toreturn;
#else
        return nil;
#endif
    }
}

+ (NSData *) decrypt:(NSData *)body withKey:(NSData *) key andIv:(NSData *)iv withAuth:( NSData * _Nullable )  auth {
    if (@available(iOS 13.0, *)) {
        
        MLCrypto *crypto = [[MLCrypto alloc] init];
        
        NSMutableData *combined = [[NSMutableData alloc] init];
        [combined appendData:iv];
        [combined appendData:body];
        [combined appendData:auth]; //if auth is nil assume it already was apended to body
        
        NSData *toReturn =[crypto decryptGCMWithKey:key encryptedContent:combined];
        return toReturn;
    } else
    {
#if !TARGET_OS_MACCATALYST
        int outlen, rv;
        unsigned char outbuf[key.length];
        EVP_CIPHER_CTX *ctx =EVP_CIPHER_CTX_new();
        
        /* Select cipher */
        if(key.length==16) {
            EVP_DecryptInit_ex(ctx, EVP_aes_128_gcm(), NULL, NULL, NULL);
        }
        
        if(key.length==32) {
            EVP_DecryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL);
        }
        
        /* Set IV length, omit for 96 bits */
        EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, (int)iv.length, NULL);
        /* Specify key and IV */
        EVP_DecryptInit_ex(ctx, NULL, NULL, key.bytes, iv.bytes);
        EVP_CIPHER_CTX_set_padding(ctx,1);
        /* Decrypt plaintext */
        NSMutableData *decdata = [[NSMutableData alloc] initWithCapacity:body.length];
        
        int byteCounter=0;
        while(byteCounter<body.length)
        {
            NSRange byteRange= NSMakeRange(byteCounter, key.length);
            if(byteCounter+key.length>body.length) byteRange=NSMakeRange(byteCounter, body.length-byteCounter);
            unsigned char bytes[byteRange.length];
            [body getBytes:bytes range:byteRange];
            EVP_DecryptUpdate(ctx, outbuf, &outlen, bytes, (int)byteRange.length);
            /* Output decrypted block */
            /* Finalise: note get no output for GCM */
            rv = EVP_DecryptFinal_ex(ctx, outbuf, &outlen);
            [decdata appendBytes:outbuf length:byteRange.length];
            byteCounter+=byteRange.length;
        }
        
        if(auth) {
            /* Set expected tag value. */
            EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, (int)auth.length, auth.bytes);
        }
        
        EVP_CIPHER_CTX_free(ctx);
        return  decdata;
#else
        return nil;
#endif
    }
}



@end
