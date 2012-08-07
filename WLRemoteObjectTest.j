/*
 * WLRemoteObjectTest.j
 * Ratatosk
 *
 * Created by Alexander Ljungberg on September 16, 2010.
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

@import "WLRemoteObject.j"
@import "WLRemoteTransformers.j"

@implementation WLRemoteObjectTest : OJTestCase
{
}

- (void)tearDown
{
    [WLRemoteObject clearInstanceCache];
}

- (void)testInstanceByPk
{
    [self assert:nil equals:[TestRemoteObject instanceForPk:nil] message:"nothing for pk nil"];

    var test1 = [[TestRemoteObject alloc] initWithJson:{'id': 5, 'name': 'test1'}],
        test2 = [[TestRemoteObject alloc] initWithJson:{'id': 15, 'name': 'test2'}];

    [self assertTrue:[TestRemoteObject instanceForPk:5] === test1 message:"test1 at pk 5"];
    [self assertTrue:[TestRemoteObject instanceForPk:15] === test2 message:"test2 at pk 15"];

    [test1 setPk:nil];
    [self assert:nil equals:[TestRemoteObject instanceForPk:5] message:"test1 no longer at pk 5"];

    [test1 setPk:7];
    [self assertTrue:[TestRemoteObject instanceForPk:5] === nil message:"nothing at pk 5"];
    [self assertTrue:[TestRemoteObject instanceForPk:7] === test1 message:"test1 now at pk 7"];
    [self assertTrue:[TestRemoteObject instanceForPk:15] === test2];

    // No conflicts between different kinds of remote objects.
    var test3 = [[OtherRemoteObject alloc] initWithJson:{'id': 5}],
        test4 = [[OtherRemoteObject alloc] initWithJson:{'id': 7}],
        test5 = [[OtherRemoteObject alloc] initWithJson:{'id': 15}];

    [self assertTrue:[TestRemoteObject instanceForPk:7] === test1];
    [self assertTrue:[TestRemoteObject instanceForPk:15] === test2];
    [self assertTrue:[OtherRemoteObject instanceForPk:7] === test4];
    [self assertTrue:[OtherRemoteObject instanceForPk:15] === test5];
}

- (void)testDeferredProperties
{
    [WLRemoteObject setDirtProof:YES];
    var test1 = [[TestRemoteObject alloc] initWithJson:{}],
        test2 = [[TestRemoteObject alloc] initWithJson:{'id': 1}],
        test3 = [[TestRemoteObject alloc] initWithJson:{'id': 2, 'name': 'a name'}];
    [WLRemoteObject setDirtProof:NO];

    [self assertTrue:[test1 isPropertyDeferred:'pk'] message:'id defined in test 1'];
    [self assertTrue:[test1 isPropertyDeferred:'name'] message:'name defined in test 1'];
    [self assertTrue:[test1 isPropertyDeferred:'count'] message:'count defined in test 1'];

    [self assertFalse:[test2 isPropertyDeferred:'pk']];
    [self assertTrue:[test2 isPropertyDeferred:'name']];
    [self assertTrue:[test2 isPropertyDeferred:'count']];

    [self assertFalse:[test3 isPropertyDeferred:'pk']];
    [self assertFalse:[test3 isPropertyDeferred:'name']];
    [self assertTrue:[test3 isPropertyDeferred:'count']];

    [test3 setCount:3];
    [self assertFalse:[test3 isPropertyDeferred:'count']];

    [WLRemoteObject setDirtProof:YES];
    [test1 updateFromJson:{'name': 'bob', 'count': 9}];
    [WLRemoteObject setDirtProof:NO];

    [self assertTrue:[test1 isPropertyDeferred:'pk']];
    [self assertFalse:[test1 isPropertyDeferred:'name']];
    [self assertFalse:[test1 isPropertyDeferred:'count']];

    [test1 setName:'hello'];
    [self assertTrue:[test1 isPropertyDirty:'name']];
    [test1 updateFromJson:{'name': 'bah'} preservingDirtyProperties:YES];
    [self assert:[test1 name] equals:'hello' message:"once a property has been loaded local changes should not be overwritten by remote updates"];

    [test1 invalidateProperty:"name"];
    [self assertTrue:[test1 isPropertyDeferred:'name']];
    [test1 updateFromJson:{'name': 'bah'} preservingDirtyProperties:YES];
    [self assert:[test1 name] equals:"bah"];
}

- (void)testForeignObjectsTransformer
{
    var test1 = [[TestRemoteObject alloc] initWithJson:{}],
        test2 = [[TestRemoteObject alloc] initWithJson:{'id': 1, 'name': 'test2 name', 'other_objects':
            [{'id': 5, 'coolness': 17}, {'id': 9}]
        }];

    [self assert:[] equals:[test1 otherObjects]];
    [self assertTrue:[[test2 otherObjects] count] == 2];

    var r1 = [test2 otherObjects][0];
    [self assert:5 equals:[r1 pk]];
    [self assert:[r1 coolness] equals:17];

    var r2 = [test2 otherObjects][1];
    [self assert:[r2 pk] equals:9];
    [self assert:[r2 coolness] equals:nil];
    [self assertTrue:[r2 isPropertyDeferred:'coolness']];

    [test2 makeAllDirty];
    var jso = [test2 asPatchJSObject];
    //CPLog.warn([CPDictionary dictionaryWithJSObject:jso['other_objects']]);

    [self assertTrue:5 == jso['other_objects'][0]['id'] || 9 == jso['other_objects'][0]['id']];
    [self assertTrue:5 == jso['other_objects'][1]['id'] || 9 == jso['other_objects'][1]['id']];
}

- (void)testDirt
{
    [WLRemoteObject setDirtProof:YES];
    var test1 = [[TestRemoteObject alloc] initWithJson:{}],
        test2 = [[TestRemoteObject alloc] initWithJson:{'id': 1, 'name': 'test2 name', 'other_objects':
            [{'id': 5, 'coolness': 17}, {'id': 9}]
        }];
    [WLRemoteObject setDirtProof:NO];

    [self assertFalse:[test1 isDirty] message:"test1 isDirty after creation"];
    [self assertFalse:[test2 isDirty] message:"test2 isDirty after creation"];

    [test2 setName:"Bob"];
    [self assertFalse:[test1 isDirty] message:"test1 isDirty"];
    [self assertTrue:[test2 isDirty] message:"test2 isDirty"];

    [test2 cleanAll];
    [self assertFalse:[test2 isDirty] message:"test2 isDirty after clean"];
}

- (void)testKeepActionPath
{
    // Normally a remote object will set its action path at the last moment in remoteActionWillBegin:,
    // rather than when first setting up the action, to give the path time to be changed by the result
    // of previous actions. However, if the action does not belong to the remote object, if it's just
    // an unrelated action which happens to have the remote object as its delegate, the remote object
    // shouldn't overwrite the path of the action.

    var test1 = [[TestRemoteObject alloc] initWithJson:{'id': 1, 'name': 'test2 name', 'other_objects':[{'id': 5, 'coolness': 17}, {'id': 9}]}],
        testAction = [WLRemoteAction schedule:WLRemoteActionGetType path:"somepath.json" delegate:test1 message:"Loading..."];

    [[WLRemoteLink sharedRemoteLink] setShouldFlushActions:YES];

    [self assert:@"somepath.json" equals:[testAction path] message:@"remote path of unrelated action not changed"];

    [[WLRemoteLink sharedRemoteLink] setShouldFlushActions:NO];
    [[WLRemoteLink sharedRemoteLink] cancelAllActions];

    // When the remote action is managing its action it should set the path.
    [test1 setName:@"other name"];
    [test1 ensureSaved];
    CPLog.error([WLRemoteLink sharedRemoteLink].actionQueue);

    [[WLRemoteLink sharedRemoteLink] setShouldFlushActions:YES];

    var lastAction = [WLRemoteAction lastAction];
    [self assert:testAction notSame:lastAction];
    [self assert:1 equals:[lastAction path] message:@"remote path of ensureSaved successfully set"];
}

@end

@implementation TestRemoteObject : WLRemoteObject
{
    CPString    name @accessors;
    long        count @accessors;
    CPArray     otherObjects @accessors;
}

+ (CPArray)remoteProperties
{
    return [
        ['pk', 'id'],
        ['name'],
        ['count'],
        ['otherObjects', 'other_objects', [WLForeignObjectsTransformer forObjectClass:OtherRemoteObject]],
    ];
}

- (id)init
{
    if (self = [super init])
    {
        otherObjects = [];
    }
    return self;
}

- (CPString)description
{
    return [self UID] + " " + [self pk] + " " + [self name];
}

@end

@implementation OtherRemoteObject : WLRemoteObject
{
    CPString coolness @accessors;
}

+ (CPArray)remoteProperties
{
    return [
        ['pk', 'id'],
        ['coolness'],
    ];
}

- (CPString)description
{
    return "OtherRemoteObject: " + [self UID] + " " + [self pk];
}

@end

var _lastAction,
    _lastRequest;

@implementation WLRemoteAction (UnitTest)

+ (WLRemoteAction)lastAction
{
    return _lastAction;
}

+ (CPURLRequest)lastRequest
{
    return _lastRequest;
}

- (CPURLConnection)makeConnectionWithRequest:(CPURLRequest)aRequest
{
    // CPLog.error(self + " makeConnection: " + aRequest);
    _lastAction = self;
    _lastRequest = aRequest;
    // Don't actually send anything.
}

@end
