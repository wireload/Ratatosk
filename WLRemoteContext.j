/*
 * WLRemoteContext.j
 * Ratatosk
 *
 * Created by Alexander Ljungberg on August 31, 2012.
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

@import "WLRemoteLink.j"

var SharedRemoteContext = nil;

var WLRemoteContextPkPrefix = "!",
    WLRemoteContextUidPrefix = "$";

var ContextKeyForObject = function(anObject)
{
    var remoteName = [anObject remoteName],
        uniqueId = [anObject pk];

    if (uniqueId !== nil && uniqueId !== undefined)
        return remoteName + ":" + WLRemoteContextPkPrefix + uniqueId;

    return remoteName + ":" + WLRemoteContextUidPrefix + [anObject UID];
}

/*!
    The remote context is the graph of remote objects associated with an API connection.

    Only a single, global context is supported today.
*/
@implementation WLRemoteContext : CPObject
{
    WLRemoteLink remoteLink @accessors;

    CPDictionary managedObjects;
}

+ (WLRemoteContext)sharedRemoteContext
{
    if (!SharedRemoteContext)
        SharedRemoteContext = [WLRemoteContext new];

    return SharedRemoteContext;
}

- (id)init
{
    if (self = [super init])
    {
        managedObjects = [CPMutableDictionary new];
        remoteLink = [WLRemoteLink sharedRemoteLink];
    }

    return self;
}

/*!
    Reset the receiver to its initial state, forgetting all remote objects. All remote object instances which belonged to this context will be invalid after this operation and any such references should be discarded.
*/
- (void)reset
{
    managedObjects = [CPMutableDictionary new];
}

- (void)registerObject:(WLRemoteObject)anObject
{
    var key = ContextKeyForObject(anObject),
        existingObject = [managedObjects objectForKey:key];

    if (existingObject && existingObject !== anObject)
        [CPException raise:CPInvalidArgumentException reason:@"Object with specified PK already exists in context (" + [anObject remoteName] + " " + [anObject pk] + ")."];

    [managedObjects setObject:anObject forKey:key];
}

- (void)unregisterObject:(WLRemoteObject)anObject
{
    var key = ContextKeyForObject(anObject);

    [managedObjects removeObjectForKey:key];
}

- (CPArray)registeredObjects
{
    return [managedObjects allValues];
}

- (CPArray)registeredObjectsForRemoteName:(CPString)aRemoteName
{
    var r = [];

    [managedObjects enumerateKeysAndObjectsUsingBlock:function(aKey, anObject)
        {
            if (aKey.lastIndexOf(aRemoteName, 0) === 0)
                [r addObject:anObject];
        }];

    return r;
}

- (WLRemoteObject)registeredObjectForRemoteName:(CPString)aRemoteName withPk:(id)aPk
{
    var key = aRemoteName + ":" + WLRemoteContextPkPrefix + aPk;

    return [managedObjects objectForKey:key];
}

@end
