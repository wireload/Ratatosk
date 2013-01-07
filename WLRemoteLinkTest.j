/*
 * WLRemoteLinkTest.j
 * Ratatosk
 *
 * Created by Alexander Ljungberg on June 15, 2010.
 * Copyright 2010, WireLoad Inc. All rights reserved.
 *
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * Redistributions of source code must retain the above copyright notice, this
 * list of conditions and the following disclaimer. Redistributions in binary
 * form must reproduce the above copyright notice, this list of conditions and
 * the following disclaimer in the documentation and/or other materials provided
 * with the distribution. Neither the name of WireLoad Inc. nor the names
 * of its contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

@import "WLRemoteLink.j"

@implementation WLRemoteLinkTest : OJTestCase

- (void)testIsSecure
{
    var link = [WLRemoteLink new];
    [link setBaseUrl:'http://wireload.net/'];
    [self assertFalse:[link isSecure]];

    [link setBaseUrl:'https://wireload.net/'];
    [self assertTrue:[link isSecure]];

    [link setBaseUrl:'/api/'];
    [self assertFalse:[link isSecure]];
}

- (void)testUrlWithSslIffNeeded
{
    var link = [WLRemoteLink new];

    [link setBaseUrl:'http://wireload.net/'];
    [self assert:[link urlWithSslIffNeeded:'http://bob.com'] equals:'http://bob.com'];
    [self assert:[link urlWithSslIffNeeded:'https://bob.com'] equals:'http://bob.com'];
    [self assert:[link urlWithSslIffNeeded:'https://chronicle-dev.s3.amazonaws.com/user/1/1A?AWSAccessKeyId=AKIAJBFB4CAIFFTR6OMA&Expires=1277683200&Signature=w3SUFvN5Q%2B9ZEExy4hO3Tgywlo4%3D'] equals:'http://chronicle-dev.s3.amazonaws.com/user/1/1A?AWSAccessKeyId=AKIAJBFB4CAIFFTR6OMA&Expires=1277683200&Signature=w3SUFvN5Q%2B9ZEExy4hO3Tgywlo4%3D'];

    [link setBaseUrl:'https://wireload.net/'];
    [self assert:[link urlWithSslIffNeeded:'http://bob.com'] equals:'https://bob.com'];
    [self assert:[link urlWithSslIffNeeded:'https://bob.com'] equals:'https://bob.com'];

    [self assert:[link urlWithSslIffNeeded:'/bob/'] equals:'/bob/'];
    [self assert:[link urlWithSslIffNeeded:'hTTp://bob.com'] equals:'https://bob.com'];
}

@end
