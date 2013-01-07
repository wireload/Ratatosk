/*
 * WLRemoteTransformersTest.j
 * Ratatosk
 *
 * Created by Alexander Ljungberg on January 7, 2013.
 * Copyright 2013, WireLoad Inc. All rights reserved.
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

@import "WLRemoteTransformers.j"

@implementation WLRemoteTransformersTest : OJTestCase
{
}

- (void)testDateTransformer
{
    var transformer = [WLDateTransformer new];

    [self assert:[[CPDate alloc] initWithString:@"2012-12-21 18:13:19 +0000"] equals:[transformer transformedValue:@"2012-12-21T18:13:19Z"]];
    [self assert:[[CPDate alloc] initWithString:@"2012-12-21 18:13:19 +0000"] equals:[transformer transformedValue:@"2012-12-21T18:13:19 +0000"]];
    [self assert:[[CPDate alloc] initWithString:@"2012-12-21 18:13:19 +0000"] equals:[transformer transformedValue:@"2012-12-21T19:13:19 +0100"]];
}

- (void)testDateTransformerReverse
{
    var transformer = [WLDateTransformer new];

    [self assert:@"2012-12-21T18:13:19 +0000" equals:[transformer reverseTransformedValue:[[CPDate alloc] initWithString:@"2012-12-21 18:13:19 +0000"]]];
    [self assert:@"2012-12-21T18:13:19 +0000" equals:[transformer reverseTransformedValue:[[CPDate alloc] initWithString:@"2012-12-21 19:13:19 +0100"]]];
}

@end
