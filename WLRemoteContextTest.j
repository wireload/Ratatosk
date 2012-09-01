/*
 * WLRemoteContextTest.j
 * Ratatosk
 *
 * Created by Alexander Ljungberg on September 1, 2012.
 * Copyright 2012, WireLoad Inc. All rights reserved.
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

@import "WLRemoteObject.j"
@import "WLRemoteObjectTest.j"
@import "WLRemoteTransformers.j"

@implementation WLRemoteContextTest : OJTestCase
{
}

- (void)tearDown
{
    [[WLRemoteContext sharedRemoteContext] reset];
}

- (void)testRegisteredObjects
{
    var context = [WLRemoteContext sharedRemoteContext];

    [self assert:[] equals:[context registeredObjects] message:@"empty context"];
    [self assert:[] equals:[context registeredObjectsOfClass:[TestRemoteObject class]] message:@"empty context"];
    [self assert:nil equals:[context registeredObjectOfClass:[TestRemoteObject class] withPk:5] message:@"empty context"];

    var test1 = [[TestRemoteObject alloc] initWithJson:{'id': 5, 'name': 'test1'}],
        test2 = [[TestRemoteObject alloc] initWithJson:{'id': 15, 'name': 'test2'}];

    [self assert:[test1, test2] equals:[context registeredObjectsOfClass:[TestRemoteObject class]] message:@"objects in context"];
    [self assert:test1 equals:[context registeredObjectOfClass:[TestRemoteObject class] withPk:5] message:@"test1 in context"];

    var test3 = [[TestRemoteObject alloc] initWithJson:{'id': 1, 'name': 'test2 name', 'other_objects':
            [{'id': 5, 'coolness': 17}, {'id': 9}]
        }];

    [self assert:[test1, test2, test3] equals:[context registeredObjectsOfClass:[TestRemoteObject class]] message:@"objects in context"];

    var other1 = [[test3 otherObjects] firstObject],
        other2 = [[test3 otherObjects] lastObject];

    [self assert:[other1, other2] equals:[context registeredObjectsOfClass:[OtherRemoteObject class]] message:@"other object in context"];
}

@end

