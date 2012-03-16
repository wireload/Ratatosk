/*
 * WLRemoteObject.j
 * Ratatosk
 *
 * Created by Alexander Ljungberg on November 16, 2009.
 * Copyright 2009-11, WireLoad Inc. All rights reserved.
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

var WLRemoteObjectByClassByPk = {},
    WLRemoteObjectDirtProof = NO;

/*!
    A WLRemoteObject is a proxy object meant to be synced with a remote object
    through an API and a WLRemoteLink. Every WLRemoteObject must have a
    unique primary key, which can be the REST URI of the object (as a
    CPString) or a database numeric id. The exception is for new objects
    have nil as their PK.

    A WLRemoteObject is equal to another WLRemoteObject with the same class
    and key. The object supports loading and saving from and to JSON and
    keeps automatic track of which properties are dirty and need to be saved.

    By default, objects autosave when simple properties are changed.

    Subclasses must implement:
        + (CPArray)remoteProperties

    Subclasses might want to implement:
        - (void)remotePath
*/
@implementation WLRemoteObject : CPObject
{
    id              pk @accessors;

    CPSet           _remoteProperties;
    Object          _propertyLastRevision;
    CPSet           _deferredProperties;
    int             _revision;
    int             _lastSyncedRevision;
    CPDate          lastSyncedAt @accessors;
    WLRemoteAction  createAction;
    WLRemoteAction  deleteAction;
    WLRemoteAction  saveAction;
    WLRemoteAction  contentDownloadAction;
    BOOL            _shouldAutoSave @accessors(property=shouldAutoSave);
    BOOL            _suppressAutoSave;
    BOOL            _suppressRemotePropertiesObservation;
    BOOL            _mustSaveAgain;
    id              _delegate @accessors(property=delegate);

    CPUndoManager   undoManager @accessors;
}

+ (Object)_objectsByPk
{
    if (WLRemoteObjectByClassByPk === nil)
        WLRemoteObjectByClassByPk = {};

    if (WLRemoteObjectByClassByPk[self] == undefined)
        WLRemoteObjectByClassByPk[self] = {};

    return WLRemoteObjectByClassByPk[self];
}

+ (id)instanceForPk:(id)pk
{
    return [self instanceForPk:pk create:NO];
}

/*!
    Return the object with the given PK from the register. If `create` is specified,
    a new unloaded object with the given PK will be created if the PK is not yet in
    the register.

    If pk is nil or undefined, nil is returned.
*/
+ (id)instanceForPk:(id)pk create:(BOOL)shouldCreate
{
    if (pk === nil || pk === undefined)
        return nil;

    var objects = [self _objectsByPk];
    if (objects[pk] === undefined)
    {
        if (!shouldCreate)
            return nil;

        var object = [self new];
        // Setting the pk will automatically add the object to objects[pk].
        [object setPk:pk];
    }

    return objects[pk];
}

+ (void)setInstance:obj forPk:(id)pk
{
    if (pk === nil)
        return nil;
    if ([obj class] !== self)
        [CPException raise:CPInvalidArgumentException reason:@"" + [obj class] + " setInstance:forPk: should be used for setting " + obj + "."];

    var objects = [self _objectsByPk];

    objects[pk] = obj;
}

+ (CPArray)allObjects
{
    r = [CPMutableArray new];
    var objects = [self _objectsByPk];
    for (var pk in objects)
    {
        if (objects.hasOwnProperty(pk))
            [r addObject:objects[pk]];
    }
    return r;
}

+ (void)clearInstanceCache
{
    WLRemoteObjectByClassByPk = {};
}

+ (void)setDirtProof:(BOOL)aFlag
{
    WLRemoteObjectDirtProof = aFlag;
}

+ (BOOL)isLoadingObjects
{
    // This is not the original purpose, but works out quite nicely.
    return WLRemoteObjectDirtProof;
}

/*!
    Specify object properties by implementing this class method on subclasses. The format is:

    [
        [<local property name> [, remote property name [, property transformer]]]
    ]

    If no remote property name is specified, the local property name is used as the remote property
    name.

    At a minimum the PK property has to be defined.
*/
+ (CPArray)remoteProperties
{
    return [
        ['pk', 'id']
    ];
}

+ (CPArray)objectsFromJson:jsonArray
{
    var r = [CPArray array];
    for (var i = 0; i < jsonArray.length; i++)
    {
        [r addObject:[[self alloc] initWithJson:jsonArray[i]]];
    }
    return r;
}

- (id)init
{
    if (self = [super init])
    {
        _revision = 0;
        _lastSyncedRevision = -1;
        _shouldAutoSave = YES;
        _remoteProperties = [CPSet set];
        _propertyLastRevision = {};
        _deferredProperties = [CPSet set];
        lastSyncedAt = [CPDate distantPast];

        var remoteProperties = [],
            otherProperties = [[self class] remoteProperties];

        if (otherProperties)
        {
            for (var i = 0, count = [otherProperties count]; i < count; i++)
            {
                var property = otherProperties[i],
                    localName = property[0],
                    remoteName = property[1],
                    transformer = property[2];

                if (!localName)
                    [CPException raise:CPInvalidArgumentException reason:@"Incorrect `+ (CPArray)remoteProperties` for RemoteObject classs " + [self class] + "."];
                if (!remoteName)
                    remoteName = localName;
                if (!transformer)
                    transformer = nil;

                [remoteProperties addObject:[RemoteProperty propertyWithLocalName:localName remoteName:remoteName transformer:transformer]];
            }
        }

        [self registerRemoteProperties:remoteProperties];
    }

    return self;
}

- (id)initWithJson:(id)js
{
    _suppressRemotePropertiesObservation = YES;

    if (self = [self init])
    {
        // (This should always be true)
        if (pk === nil || pk  === undefined)
        {
            // Check if the JSON is for an instance we are already tracking.
            var pkProperty = [self pkProperty],
                remotePkName = [pkProperty remoteName];
            if (js[remotePkName] !== undefined)
            {
                var _value = js[remotePkName];
                if ([pkProperty valueTransformer])
                    _value = [[pkProperty valueTransformer] transformedValue:_value];

                var existingObject = [[self class] instanceForPk:_value];

                if (existingObject)
                {
                    // Yes we are tracking an existing object. Update that object instead and return it.
                    self = existingObject;
                    [existingObject updateFromJson:js];
                    return self;
                }
            }
        }

        [self updateFromJson:js];
        _suppressRemotePropertiesObservation = NO;
        [self activateRemotePropertiesObservation];
    }

    return self;
}

- (void)registerRemoteProperties:(CPArray)someProperties
{
    for (var i = 0, count = [someProperties count]; i < count; i++)
    {
        var property = someProperties[i];
        if ([_remoteProperties containsObject:property])
            continue;

        if (!_suppressRemotePropertiesObservation)
        {
            [self addObserver:self forKeyPath:[property localName] options:nil context:property];
            // FIXME Since the undo manager is no longer read from a central place, this will do nothing.
            // This action needs to be taken when setUndoManager: is received instead.
            [self registerKeyForUndoManagement:[property localName]];
        }
        [_remoteProperties addObject:property];
        [_deferredProperties addObject:property];
    }
}

- (void)registerKeyForUndoManagement:(CPString)aLocalName
{
    if (aLocalName == "pk")
        return;
    [[self undoManager] observeChangesForKeyPath:aLocalName ofObject:self];
}

- (void)pkProperty
{
    return [self remotePropertyForKey:"pk"];
}

- (RemoteProperty)remotePropertyForKey:(CPString)aLocalName
{
    var remotePropertiesEnumerator = [_remoteProperties objectEnumerator],
        property;
    while (property = [remotePropertiesEnumerator nextObject])
        if ([property localName] == aLocalName)
            return property;
    return nil;
}

- (void)activateRemotePropertiesObservation
{
    var remotePropertiesEnumerator = [_remoteProperties objectEnumerator],
        property;
    while (property = [remotePropertiesEnumerator nextObject])
    {
        [self registerKeyForUndoManagement:[property localName]];
        [self addObserver:self forKeyPath:[property localName] options:nil context:property];
    }
}

- (void)observeValueForKeyPath:(CPString)aKeyPath ofObject:(id)anObject change:(CPDictionary)change context:(id)aContext
{
    var isBeforeFlag = !![change objectForKey:CPKeyValueChangeNotificationIsPriorKey];
    if (isBeforeFlag)
        return;

    if ([change valueForKey:CPKeyValueChangeKindKey] == CPKeyValueChangeSetting && [_remoteProperties containsObject:aContext])
    {
        var before = [change valueForKey:CPKeyValueChangeOldKey],
            after = [change valueForKey:CPKeyValueChangeNewKey];
        if (before !== after && ((before === nil && after !== nil) || ![before isEqual:after]))
            [self makeDirtyProperty:[aContext localName]];
        [_deferredProperties removeObject:aContext];
    }
}

- (void)cleanAll
{
    _propertyLastRevision = {};
}

- (void)cleanProperty:(CPString)localName
{
    delete _propertyLastRevision[localName];
}

- (void)makeAllDirty
{
    var remotePropertiesEnumerator = [_remoteProperties objectEnumerator],
        property;
    while (property = [remotePropertiesEnumerator nextObject])
    {
        [self makeDirtyProperty:[property localName]]
    }
}

- (void)makeDirtyProperty:(CPString)localName
{
    if (WLRemoteObjectDirtProof)
        return;

    _propertyLastRevision[localName] = ++_revision;
    if (!_suppressAutoSave && ![self isNew] && _shouldAutoSave)
    {
        // Run the check for whether we should autosave at the end of the
        // run loop so that batch changes can collate. This also enables
        // the [object setProperty:X];[object cleanAll]; without having to
        // suppress auto saves.
        [[CPRunLoop currentRunLoop] performSelector:"ensureSaved" target:self argument:nil order:0 modes:[CPDefaultRunLoopMode]];
    }
}

/*!
    Mark the named property as not yet having been downloaded so that [instance ensureLoaded] will cause it to be redownloaded.
    You might do this if you know a property has updated server side and needs to be reread.
*/
- (void)invalidateProperty:(CPString)localName
{
    var property = [self remotePropertyForKey:localName];
    if (property == nil)
        [CPException raise:CPInvalidArgumentException reason:@"Unknown property " + localName + "."];

    delete _propertyLastRevision[localName];
    [_deferredProperties addObject:property];
}

- (BOOL)isDirty
{
    return [[self dirtyProperties] count] > 0;
}

- (void)dirtyProperties
{
    var r = [CPSet set],
        property = nil,
        objectEnumerator = [_remoteProperties objectEnumerator];

    while (property = [objectEnumerator nextObject])
    {
        var localName = [property localName];
        if (_propertyLastRevision[localName] && _propertyLastRevision[localName] > _lastSyncedRevision)
            [r addObject:property];
    }
    return r;
}

/*!
    Every property begins 'deferred', meaning unloaded. When a property is set
    through initWithJson, updateFromJson, or a mutator, it is no longer considered
    deferred.
*/
- (BOOL)isPropertyDeferred:(CPString)localName
{
    var property = [self remotePropertyForKey:localName];
    if (!property)
        [CPException raise:CPInvalidArgumentException reason:@"Unknown property " + localName + "."];
    return [_deferredProperties containsObject:property];
}

- (BOOL)isPropertyDirty:(CPString)localName
{
    return _propertyLastRevision[localName] && _propertyLastRevision[localName] > _lastSyncedRevision;
}

- (void)setPk:(id)aPk
{
    var objectByPk = WLRemoteObjectByClassByPk[[self class]];
    if (pk !== nil && objectByPk !== undefined)
        delete objectByPk[pk];
    pk = aPk;
    [[self class] setInstance:self forPk:pk];
}

- (void)updateFromJson:js
{
    var property = nil,
        objectEnumerator = [_remoteProperties objectEnumerator];

    while (property = [objectEnumerator nextObject])
        [self updateFromJson:js remoteProperty:property];
}

- (void)updateFromJson:js preservingDirtyProperties:(BOOL)shouldPreserveDirty
{
    var property = nil,
        objectEnumerator = [_remoteProperties objectEnumerator];

    while (property = [objectEnumerator nextObject])
    {
        // If the local version is changed, don't overwrite it with the remote.
        if (shouldPreserveDirty && [[self dirtyProperties] containsObject:property])
            continue;
        [self updateFromJson:js remoteProperty:property];
    }
}

- (void)updateFromJson:js remoteProperty:(RemoteProperty)aProperty
{
    var remoteName = [aProperty remoteName];
    if (js[remoteName] !== undefined)
    {
        var _value = js[remoteName],
            localName = [aProperty localName];
        if ([aProperty valueTransformer])
            _value = [[aProperty valueTransformer] transformedValue:_value];
        [self setValue:_value forKey:localName];
        [_deferredProperties removeObject:aProperty];
    }
}

- (id)asPostJSObject
{
    var r = {},
        property = nil,
        objectEnumerator = [[self dirtyProperties] objectEnumerator];

    while (property = [objectEnumerator nextObject])
    {
        var _value = [self valueForKey:[property localName]];
        if ([property valueTransformer] && [[[property valueTransformer] class] allowsReverseTransformation])
            _value = [[property valueTransformer] reverseTransformedValue:_value];
        r[[property remoteName]] = _value;
    }

    return r;
}

- (BOOL)isEqual:(id)anObject
{
    if (self === anObject)
        return YES;

    if (![anObject isKindOfClass:[self class]])
        return NO;

    // Entries with no primary key can only be equal if they
    // are identical.
    if ([self pk] === nil)
        return NO;

    return [self pk] == [anObject pk];
}

/*!
    The path of this resource within the API. The path should not include the path to the API root (see WLRemoteLink).

    By default, the PK is assumed to the the unique path.
*/
- (CPString)remotePath
{
    return [self pk];
}

/*!
    The path to use when GETing (downloading) this resource. By default this is [self remotePath].
*/
- (CPString)getPath
{
    return [self remotePath];
}

/*!
    The path to use when POSTing (creating) a new resource. By default this is [self remotePath].
*/
- (CPString)postPath
{
    return [self remotePath];
}

/*!
    The path to use when PUTting (updating) this resource. By default this is [self remotePath].
*/
- (CPString)putPath
{
    return [self remotePath];
}

/*!
    The path to use when DELETEing this resource. By default this is [self remotePath].
*/
- (CPString)deletePath
{
    return [self remotePath];
}

- (BOOL)isNew
{
    return pk === nil;
}

/*!
    Create or recreate this object remotely.
*/
- (void)create
{
    [[self undoManager] registerUndoWithTarget:self
                                      selector:@selector(delete)
                                        object:nil];

    [self ensureCreated];
}

/*!
    Delete this object remotely.
*/
- (void)delete
{
    [[self undoManager] registerUndoWithTarget:self
                               selector:@selector(create)
                                 object:nil];

    [self ensureDeleted];
}

- (void)ensureCreated
{
    if (![self isNew] || createAction !== nil)
        return;

    // FIXME Should this be here or in init somewhere? In init we don't yet know if
    // this object will be loaded from remote or if it's being created.

    // Since we're creating the object, there are no deferred fields. Without clearing
    // these, ensureLoaded would lead to a pointless GET.
    _deferredProperties = [CPSet set];

    // Also consider all fields dirty so that any initial values get POSTed. E.g. if a new
    // RemoteObject has a title attribute like 'unnamed' by default, that should be transmitted
    // to the server.
    [self makeAllDirty];

    createAction = [WLRemoteAction schedule:WLRemoteActionPostType path:[self postPath] delegate:self message:"Create " + [self description]];
}

- (void)ensureDeleted
{
    if ([self isNew] || deleteAction !== nil)
        return;

    // Path might not be known yet. A delete can be scheduled before the object has been created. The path will be
    // set in remoteActionWillBegin when the path must be known.
    deleteAction = [WLRemoteAction schedule:WLRemoteActionDeleteType path:nil delegate:self message:"Delete " + [self description]];
}

- (void)ensureLoaded
{
    if ([_deferredProperties count] == 0 || contentDownloadAction !== nil)
        return;

    // Path might not be known yet. A load can be scheduled before the object has been created. The path will be
    // set in remoteActionWillBegin when the path must be known.
    contentDownloadAction = [WLRemoteAction schedule:WLRemoteActionGetType path:nil delegate:self message:"Loading " + [self description]];
}

- (void)ensureSaved
{
    if (![self isDirty])
        return;

    // If a save action is already in the pipe, relax.
    if (saveAction !== nil)
    {
        if (![saveAction isStarted])
            return;

        /*
            The ongoing save is saving stale information. We must ensure
            another save will be scheduled after this one.
        */
        _mustSaveAgain = YES;
        return;
    }

    CPLog.info("Save " + self + " dirt: " + [[self dirtyProperties] description]);
    saveAction = [WLRemoteAction schedule:WLRemoteActionPutType path:nil delegate:self message:"Save " + [self description]];
}

- (void)remoteActionWillBegin:(WLRemoteAction)anAction
{
    if ([anAction type] == WLRemoteActionPostType)
    {
        if (pk)
        {
            CPLog.error("Attempt to create an existing object");
            return;
        }

        [anAction setPayload:[self asPostJSObject]];
        // Assume the action will succeed or retry until it does.
        [self setLastSyncedAt:[CPDate date]];
        _lastSyncedRevision = _revision;
    }
    else if ([anAction type] == WLRemoteActionDeleteType)
    {
        if (pk === nil)
        {
            CPLog.error("Attempt to delete a non existant object");
            return;
        }

        [anAction setPayload:nil];
        // Assume the action will succeed or retry until it does.
        [self setLastSyncedAt:[CPDate date]];
        _lastSyncedRevision = _revision;
        [anAction setPath:[self deletePath]];
    }
    else if ([anAction type] == WLRemoteActionPutType)
    {
        if (!pk)
        {
            CPLog.error("Attempt to save non created object " + [self description]);
            return;
        }

        [anAction setMessage:"Saving " + [self description]];
        [anAction setPayload:[self asPostJSObject]];
        // Assume the action will succeed or retry until it does.
        [self setLastSyncedAt:[CPDate date]];
        _lastSyncedRevision = _revision;
        [anAction setPath:[self putPath]];
    }
    else if ([anAction type] == WLRemoteActionGetType)
    {
        if (!pk)
        {
            CPLog.error("Attempt to download non created entry " + [self description]);
            return;
        }

        [anAction setPath:[self getPath]];
    }
}

- (void)remoteActionDidReceivePostData:(Object)aResult
{
    [WLRemoteObject setDirtProof:YES];
    [[self undoManager] disableUndoRegistration];
    // Take any data received from the POST and update the object correspondingly -
    // in particular we need the primary key that was generated. But at the same time
    // we don't want to overwrite any changes the user made while the POST was happening,
    // so we preserve dirty properties here.
    [self updateFromJson:aResult preservingDirtyProperties:YES];
    [[self undoManager] enableUndoRegistration];
    [WLRemoteObject setDirtProof:NO];
}

- (void)remoteActionDidFinish:(WLRemoteAction)anAction
{
    if ([anAction type] == WLRemoteActionPostType)
    {
        [self remoteActionDidReceivePostData:[anAction result]];

        createAction = nil;
        if ([_delegate respondsToSelector:@selector(remoteObjectWasCreated:)])
            [_delegate remoteObjectWasCreated:self];
    }
    else if ([anAction type] == WLRemoteActionDeleteType)
    {
        // The previous PK is now gone.
        [self setPk:nil];

        // There is nothing to save anymore.
        [saveAction cancel];
        saveAction = nil;

        // After the object has been deleted, the next call to 'ensureCreated' will
        // create a new object. When that creation happens all the data should be
        // considered dirty to ensure it gets sent with the creation.
        [self makeAllDirty];

        deleteAction = nil;
        [self remoteObjectWasDeleted];
    }
    else if ([anAction type] == WLRemoteActionPutType)
    {
        saveAction = nil;
        if (_mustSaveAgain)
        {
            _mustSaveAgain = NO;
            [self ensureSaved];
        }
    }
    else if ([anAction type] == WLRemoteActionGetType)
    {
        // Assume whatever was downloaded is the most current info, so nothing gets dirty.
        [WLRemoteObject setDirtProof:YES];
        [[self undoManager] disableUndoRegistration];
        [self updateFromJson:[anAction result]];
        [[self undoManager] enableUndoRegistration];
        [WLRemoteObject setDirtProof:NO];
        contentDownloadAction = nil;
        [self remoteObjectWasLoaded];
    }
}

- (void)remoteObjectWasLoaded
{
    if ([_delegate respondsToSelector:@selector(remoteObjectWasLoaded:)])
        [_delegate remoteObjectWasLoaded:self];
}

- (void)remoteObjectWasDeleted
{
    if ([_delegate respondsToSelector:@selector(remoteObjectWasDeleted:)])
        [_delegate remoteObjectWasDeleted:self];
}

@end

var WLRemoteObjectClassKey = "WLRemoteObjectClassKey",
    WLRemoteObjectPkKey = "WLRemoteObjectPkKey";

/*!
    TODO Do something sensible here.
*/
@implementation WLRemoteObject (CPCoding)

- (id)initWithCoder:(CPCoder)aCoder
{
    var clz = [aCoder decodeObjectForKey:WLRemoteObjectClassKey],
        pk = [aCoder decodeObjectForKey:WLRemoteObjectPkKey];

    return [WLRemoteObject instanceOf:clz withPk:pk];
}

- (void)encodeWithCoder:(CPCoder)aCoder
{
    [super encodeWithCoder:aCoder];

    [aCoder encodeObject:[self class] forKey:WLRemoteObjectClassKey];
    [aCoder encodeObject:[self pk] forKey:WLRemoteObjectPkKey];
}

@end

@implementation RemoteProperty : CPObject
{
    CPString            localName @accessors;
    CPString            remoteName @accessors;
    CPValueTransformer  valueTransformer @accessors;
}

+ (id)propertyWithName:(CPString)aName
{
    return [self propertyWithLocalName:aName remoteName:aName transformer:nil];
}

+ (id)propertyWithLocalName:(CPString)aLocalName remoteName:(CPString)aRemoteName
{
    return [self propertyWithLocalName:aLocalName remoteName:aRemoteName transformer:nil];
}

+ (id)propertyWithLocalName:(CPString)aLocalName remoteName:(CPString)aRemoteName transformer:(CPValueTransformer)aTransformer
{
    var r = [RemoteProperty new];
    [r setLocalName:aLocalName];
    [r setRemoteName:aRemoteName];
    [r setValueTransformer:aTransformer];
    return r;
}

- (BOOL)isEqual:(id)anOther
{
    return (anOther !== nil && anOther.isa && [anOther isKindOfClass:RemoteProperty] && anOther.localName == self.localName);
}

- (CPString)description
{
    return "<RemoteProperty " + remoteName + ":" + localName + ">";
}

@end

