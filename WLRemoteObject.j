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

@import "WLRemoteContext.j"
@import "WLRemoteLink.j"

var WLRemoteObjectDirtProof = NO,

    CamelCaseToHyphenPrefixStripper = new RegExp('^[_A-Z]+([A-Z])'),
    CamelCaseToHyphenator = new RegExp("([a-z])([A-Z])");

/*!
    Compare a and b whether a is CPObject or JS primitive.
*/
var isEqual = function(a, b) {
    if (a == nil || b == nil || !a.isa)
        return a === b;
    return [a isEqual:b];
}

function CamelCaseToHyphenated(camelCase)
{
    return camelCase.replace(CamelCaseToHyphenPrefixStripper, '$1').replace(CamelCaseToHyphenator, '$1-$2').toLowerCase();
};

/*!
    A WLRemoteObject is a proxy object meant to be synced with a remote object
    through an API and a WLRemoteLink. Every WLRemoteObject must have a
    unique primary key which can be the REST URI of the object (as a
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

    CPString        _remoteName @accessors(readonly, property=remoteName);
    CPSet           _remoteProperties @accessors(readonly, property=remoteProperties);

    Object          _propertyLastRevision;
    CPSet           _deferredProperties;
    int             _revision;
    int             _lastSyncedRevision;
    CPDate          lastSyncedAt @accessors;
    BOOL            _shouldAutoSave @accessors(property=shouldAutoSave);
    BOOL            _shouldAutoLoad @accessors(property=shouldAutoLoad);
    BOOL            _suppressAutoSave;
    BOOL            _suppressRemotePropertiesObservation;
    id              _delegate @accessors(property=delegate);

    CPMutableArray  _actions;
    CPMutableArray  _loadActions;

    CPUndoManager   undoManager @accessors;
}

/*!
    Deprectated. Use `[[WLRemoteContext sharedRemoteContext] registeredObjectForRemoteName:[self remoteName] withPk:pk]`.
*/
+ (id)instanceForPk:(id)pk
{
    if (pk === nil || pk === undefined)
        return nil;

    return [[WLRemoteContext sharedRemoteContext] registeredObjectForRemoteName:[self remoteName] withPk:pk];
}

/*!
    Deprectated. Use `[[WLRemoteContext sharedRemoteContext] registeredObjectForRemoteName:[self remoteName] withPk:pk]`.
*/
+ (id)instanceForPk:(id)pk create:(BOOL)shouldCreate
{
    if (pk === nil || pk === undefined)
        return nil;

    var r = [self instanceForPk:pk];

    if (r === nil && shouldCreate)
    {
        r = [self new];
        // Setting the pk will automatically register it.
        [r setPk:pk];
    }

    return r;
}

/*!
    Deprecated. Use `[[WLRemoteContext sharedRemoteContext] registeredObjectsForRemoteName:[self remoteName]]`.
*/
+ (CPArray)allObjects
{
    return [[WLRemoteContext sharedRemoteContext] registeredObjectsForRemoteName:[self remoteName]];
}

+ (void)clearInstanceCache
{
    [CPException raise:CPInvalidArgumentException reason:@"Use [WLRemoteContext reset] instead."];
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
    The name of the remote resource. The name of the resource combined with the PK of an instance is what uniquely identifies a specific resource. (For many APIs the PK is the resource URI and alone uniquely identifies the resource, but for APIs where the PK is something like an ID number the name is critical so that e.g. User 101 is not considered the same remote object as BlogPost 101.)

    If two classes are alternative implementations for the same remote resource, they should have the same remote name. E.g. if there is a remote resource called a "Shape" and two classes "Circle" and "Rectangle" implement two types of "Shape", their remoteName should be "shape" so that Ratatosk can recognise that both circles and rectangles should go in the same "bucket" of objects.

    By default the remoteName is the class name minus any leading prefix and converted from camelcase to lowercase with dashes. E.g. a remote object class like WLBlogPost would by default have a remoteName of 'blog-post'.
*/
+ (CPString)remoteName
{
    var className = CPStringFromClass([self class]);
    return CamelCaseToHyphenated(className);
}

/*!
    Specify object properties by implementing this class method on subclasses. The format is:

    [
        [<local property name> [, remote property name [, property transformer[, load only?]]]]
    ]

    If no remote property name is specified, the local property name is used as the remote property
    name.

    At a minimum the PK property has to be defined.

    Load only properties are read from the server but never written back, even if the property
    is changed locally. For instance, you might have a value which the server derives from other
    values, so it's effectively read-only server side. But you know how to derive this value too,
    so when you make local changes you want to immediately update your local value, thereby
    changing it in the client. But you can't write that back to the server. Load-only will ensure
    the property is READ from the server but never WRITTEN. Load-only properties do not affect
    the object isDirty status and do not participate in automatic undo management.

    The 'pk' property is automatically considered load only.
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

/*!
    When shouldAutoLoad is YES and this method returns YES for a property, any remote
    object set to that property will have `ensureLoaded` automatically called.
*/
+ (BOOL)automaticallyLoadsRemoteObjectsForKey:(CPString)aLocalName
{
    var capitalizedName = aLocalName.charAt(0).toUpperCase() + aLocalName.substring(1),
        selector = "automaticallyLoadsRemoteObjectsFor" + capitalizedName;

    if ([[self class] respondsToSelector:selector])
        return objj_msgSend([self class], selector);

    return NO;
}

- (id)init
{
    if (self = [super init])
    {
        _revision = 0;
        _lastSyncedRevision = -1;
        _shouldAutoSave = YES;
        _shouldAutoLoad = YES;
        _remoteName = [[self class] remoteName];
        _remoteProperties = [CPSet set];
        _propertyLastRevision = {};
        _deferredProperties = [CPSet set];
        lastSyncedAt = [CPDate distantPast];
        _actions = [CPMutableArray array];
        _loadActions = [CPMutableArray array];

        var remoteProperties = [],
            otherProperties = [[self class] remoteProperties];

        if (otherProperties)
        {
            for (var i = 0, count = [otherProperties count]; i < count; i++)
            {
                var property = otherProperties[i],
                    localName = property[0],
                    remoteName = property[1] || localName,
                    transformer = property[2] || nil,
                    loadOnly = (typeof property[3] !== "undefined") ? property[3] : localName == "pk" || NO;

                if (!localName)
                    [CPException raise:CPInvalidArgumentException reason:@"Incorrect `+ (CPArray)remoteProperties` for RemoteObject class " + [self class] + "."];

                [remoteProperties addObject:[RemoteProperty propertyWithLocalName:localName remoteName:remoteName transformer:transformer loadOnly:loadOnly]];
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
                var pkValue = js[remotePkName];
                if ([pkProperty valueTransformer])
                    pkValue = [[pkProperty valueTransformer] transformedValue:pkValue];

                var existingObject = [[self context] registeredObjectForRemoteName:[self remoteName] withPk:pkValue];

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

- (WLRemoteContext)context
{
    // For future compatibility when there can be multiple contexts.
    return [WLRemoteContext sharedRemoteContext];
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
            [self registerKeyForUndoManagement:property];
        }
        [_remoteProperties addObject:property];
        [_deferredProperties addObject:property];
    }
}

- (void)registerKeyForUndoManagement:(RemoteProperty)aProperty
{
    if ([aProperty isLoadOnly])
        return;
    [[self undoManager] observeChangesForKeyPath:[aProperty localName] ofObject:self];
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
        [self registerKeyForUndoManagement:property];
        [self addObserver:self forKeyPath:[property localName] options:nil context:property];

        if (_shouldAutoLoad && [[self class] automaticallyLoadsRemoteObjectsForKey:[property localName]])
        {
            if ([[self valueForKeyPath:[property localName]] isKindOfClass:[CPArray class]])
                [[self valueForKeyPath:[property localName]] makeObjectsPerformSelector:@selector(ensureLoaded)];
            else
                [[self valueForKeyPath:[property localName]] ensureLoaded];
        }
    }
}

- (void)observeValueForKeyPath:(CPString)aKeyPath ofObject:(id)anObject change:(CPDictionary)change context:(id)aContext
{
    var isBeforeFlag = !![change objectForKey:CPKeyValueChangeNotificationIsPriorKey];
    if (isBeforeFlag)
        return;

    if ([_remoteProperties containsObject:aContext])
    {
        var localName = [aContext localName],
            kind = [change objectForKey:CPKeyValueChangeKindKey],
            after = [change objectForKey:CPKeyValueChangeNewKey];

        if (kind === CPKeyValueChangeSetting)
        {
            var before = [change objectForKey:CPKeyValueChangeOldKey];

            if (!isEqual(before, after))
                [self makeDirtyProperty:localName];

            [_deferredProperties removeObject:aContext];

            if (_shouldAutoLoad && [[self class] automaticallyLoadsRemoteObjectsForKey:localName])
            {
                if ([after isKindOfClass:[CPArray class]])
                    [after makeObjectsPerformSelector:@selector(ensureLoaded)];
                else
                    [self ensureLoaded];
            }
        }
        else if (kind === CPKeyValueChangeInsertion || kind === CPKeyValueChangeReplacement)
        {
            [self makeDirtyProperty:localName];

            if (_shouldAutoLoad && [[self class] automaticallyLoadsRemoteObjectsForKey:localName])
                [after makeObjectsPerformSelector:@selector(ensureLoaded)];
        }
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

- (CPSet)dirtyProperties
{
    var r = [CPSet set],
        property = nil,
        objectEnumerator = [_remoteProperties objectEnumerator];

    while (property = [objectEnumerator nextObject])
    {
        if ([property isLoadOnly])
            continue;
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
    if (pk === aPk)
        return;

    var context = [self context];
    [context unregisterObject:self];

    pk = aPk;
    if (pk)
        [context registerObject:self];
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
        var after = js[remoteName],
            localName = [aProperty localName];
        if ([aProperty valueTransformer])
            after = [[aProperty valueTransformer] transformedValue:after];

        var before = [self valueForKeyPath:localName];
        // Avoid calling setValue:forKey: if we just received the value we already have. This will
        // happen frequently if `PUT` / `PATCH` requests respond with the object representation - most fields
        // will be unchanged and we don't want expensive KVO notifications to go out needlessly.
        if (!isEqual(before, after))
        {
            // CPLog.debug("Updating property %@ from JSON (before: %@ after: %@)", localName, before, after);
            [self setValue:after forKeyPath:localName];
        }

        [_deferredProperties removeObject:aProperty];
    }
}

- (id)asJSObjectForProperties:(CPSet)someProperties
{
    var r = {};

    [someProperties enumerateObjectsUsingBlock:function(aProperty)
        {
            var aValue = [self valueForKeyPath:[aProperty localName]],
                aValueTransformer = [aProperty valueTransformer];
            if (aValueTransformer && [[aValueTransformer class] allowsReverseTransformation])
                aValue = [aValueTransformer reverseTransformedValue:aValue];
            r[[aProperty remoteName]] = aValue;
        }
    ];

    return r;
}

- (id)asPatchJSObject
{
    return [self asJSObjectForProperties:[self dirtyProperties]];
}

- (id)asJSObject
{
    return [self asJSObjectForProperties:[self remoteProperties]];
}

- (BOOL)isEqual:(id)anObject
{
    if (self === anObject)
        return YES;

    if (![anObject isKindOfClass:WLRemoteObject])
        return NO;

    if (![[anObject remoteName] isEqual:[self remoteName]])
        return NO;

    // Entries with no primary key can only be equal if they
    // are identical.
    if ([self pk] === nil)
        return NO;

    return [self pk] == [anObject pk];
}

/*!
    The path of this resource within the API. The path should not include the path to the API root (see WLRemoteLink).

    By default, the PK is assumed to be the canonical resource URI.
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
    The path to use when PATCHing (updating) this resource. By default this is [self remotePath].
*/
- (CPString)patchPath
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
    return pk === nil || pk === undefined;
}

/*!
    Determines whether object needs to be created at schedule action time.

    Create is only needed if (object is not created yet) and (no create already scheduled or delete is scheduled afterwards).
*/
- (boolean)needsCreate
{
    var needsCreate = [self isNew];
    [_actions enumerateObjectsWithOptions:CPEnumerationReverse usingBlock:function(anAction, anIndex, aStop)
        {
            if ([anAction isDone])
                return;

            var type = [anAction type];

            if (type === WLRemoteActionPostType)
            {
                needsCreate = NO;
                aStop(YES);
            }
            else if (type === WLRemoteActionDeleteType)
            {
                needsCreate = YES;
                aStop(YES);
            }
        }];
    return needsCreate;
}

/*!
    Determines whether object needs to be deleted at schedule action time.

    Delete is only needed if (object is already created) and (no delete already scheduled or create is scheduled afterwards).
*/
- (boolean)needsDelete
{
    var needsDelete = ![self isNew];
    [_actions enumerateObjectsWithOptions:CPEnumerationReverse usingBlock:function(anAction, anIndex, aStop)
        {
            if ([anAction isDone])
                return;

            var type = [anAction type];

            if (type === WLRemoteActionPostType)
            {
                needsDelete = YES;
                aStop(YES);
            }
            else if (type === WLRemoteActionDeleteType)
            {
                needsDelete = NO;
                aStop(YES);
            }
        }];
    return needsDelete;
}

/*!
    Determines whether object needs to be loaded at schedule action time.

    Load is only needed if object is not deleted.
*/
- (boolean)needsLoad
{
    var needsLoad = ![self isNew] && [_deferredProperties count];
    [_actions enumerateObjectsWithOptions:CPEnumerationReverse usingBlock:function(anAction, anIndex, aStop)
        {
            if ([anAction isDone])
                return;

            var type = [anAction type];

            if (type === WLRemoteActionPostType)
                aStop(YES);
            else if (type === WLRemoteActionDeleteType)
            {
                needsLoad = NO;
                aStop(YES);
            }
        }];
    return needsLoad;
}

/*!
    Determines whether object needs to be saved at schedule action time.

    Save is only needed if object is dirty and no another create/save action is executing and object is not deleted.
*/
- (boolean)needsSave
{
    var needsSave = ![self isNew] && [self isDirty],
        saveActionType = [[[self context] remoteLink] saveActionType];
    [_actions enumerateObjectsWithOptions:CPEnumerationReverse usingBlock:function(anAction, anIndex, aStop)
        {
            if ([anAction isDone])
                return;

            var type = [anAction type];

            if (type === WLRemoteActionPostType || type === saveActionType)
            {
                needsSave = ![anAction isStarted];
                aStop(YES);
            }
            else if (type === WLRemoteActionDeleteType)
            {
                needsSave = NO;
                aStop(YES);
            }
        }];
    return needsSave;
}

/*!
    Determines whether object can be created at request action time.
*/
- (boolean)canCreate
{
    return !pk;
}

/*!
    Determines whether object can be deleted at request action time.
*/
- (boolean)canDelete
{
    return !!pk;
}

/*!
    Determines whether object can be loaded at request action time.
*/
- (boolean)canLoad
{
    return !!pk;
}

/*!
    Determines whether object can be saved at request action time.
*/
- (boolean)canSave
{
    return !!pk && [self isDirty];
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
    if (![self needsCreate])
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

    [_actions addObject:[WLRemoteAction schedule:WLRemoteActionPostType path:[self postPath] delegate:self message:"Create " + [self description]]];
}

- (void)ensureDeleted
{
    if (![self needsDelete])
        return;

    // Path might not be known yet. A delete can be scheduled before the object has been created. The path will be
    // set in remoteActionWillBegin when the path must be known.
    [_actions addObject:[WLRemoteAction schedule:WLRemoteActionDeleteType path:nil delegate:self message:"Delete " + [self description]]];
}

- (void)ensureLoaded
{
    if (![self needsLoad])
        return;

    [self reload];
}

/*!
    Reload the properties of this resource from the server. Also see `ensureLoaded` which only causes the resource to
    be retrieved if it hasn't already been fully downloaded.
*/
- (void)reload
{
    // We're only interested in most recent actions.
    [_loadActions makeObjectsPerformSelector:@selector(cancel)];
    [_loadActions removeAllObjects];

    // Path might not be known yet. A load can be scheduled before the object has been created. The path will be
    // set in remoteActionWillBegin when the path must be known.
    var action = [WLRemoteAction schedule:WLRemoteActionGetType path:nil delegate:self message:"Loading " + [self description]];
    [_actions addObject:action];
    [_loadActions addObject:action];
}

- (void)ensureSaved
{
    if (![self needsSave])
        return;

    var dirtDescription = [[[[self dirtyProperties] valueForKeyPath:@"localName"] allObjects] componentsJoinedByString:@", "];

    CPLog.info("Save " + [self description] + " dirt: " + dirtDescription);

    [_actions addObject:[WLRemoteAction schedule:[[[self context] remoteLink] saveActionType] path:nil delegate:self message:"Save " + [self description]]];
}

- (void)remoteActionWillBegin:(WLRemoteAction)anAction
{
    if (![_actions count] || [_actions objectAtIndex:0] !== anAction)
        return;

    switch ([anAction type])
    {
        case WLRemoteActionPostType:
            if ([self canCreate])
            {
                [anAction setPayload:[self asJSObject]];
                // Assume the action will succeed or retry until it does.
                [self setLastSyncedAt:[CPDate date]];
                _lastSyncedRevision = _revision;
            }
            else
            {
                if (pk)
                    CPLog.error("Attempt to create an existing object");

                [anAction cancel];
                [_actions removeObjectAtIndex:0];
            }
            break;
        case WLRemoteActionDeleteType:
            if ([self canDelete])
            {
                [anAction setPayload:nil];
                // Assume the action will succeed or retry until it does.
                [self setLastSyncedAt:[CPDate date]];
                _lastSyncedRevision = _revision;
                [anAction setPath:[self deletePath]];
            }
            else
            {
                if (!pk)
                    CPLog.error("Attempt to delete a non existant object");

                [anAction cancel];
                [_actions removeObjectAtIndex:0];
            }
            break;
        case [[[self context] remoteLink] saveActionType]:
            if ([self canSave])
            {
                var patchAction = [anAction type] === WLRemoteActionPatchType;

                [anAction setMessage:"Saving " + [self description]];
                [anAction setPayload:patchAction ? [self asPatchJSObject] : [self asJSObject]];
                [anAction setPath:patchAction ? [self patchPath] : [self putPath]];
                // Assume the action will succeed or retry until it does.
                [self setLastSyncedAt:[CPDate date]];
                _lastSyncedRevision = _revision;
            }
            else
            {
                if (!pk)
                    CPLog.error("Attempt to save non created object " + [self description]);

                [anAction cancel];
                [_actions removeObjectAtIndex:0];
            }
            break;
        case WLRemoteActionGetType:
            if ([self canLoad])
                [anAction setPath:[self getPath]];
            else
            {
                if (!pk)
                    CPLog.error("Attempt to load non created object " + [self description]);

                [anAction cancel];
                [_actions removeObjectAtIndex:0];
            }
            // Load action scheduled for execution should not be cancelled.
            [_loadActions removeObjectAtIndex:0];
            break;
        default:
            CPLog.error("Unexpected action: " + [anAction description]);
    }
}

- (void)remoteActionDidReceiveResourceRepresentation:(Object)aResult
{
    [WLRemoteObject setDirtProof:YES];
    [[self undoManager] disableUndoRegistration];
    // Take any data received from the POST/PUT/PATCH and update the object correspondingly -
    // in particular we might need any primary key that was generated. We could also get new
    // data for updated_at style fields.

    // At the same time we don't want to overwrite any changes the user made while the request
    // was processing, so we preserve dirty properties here.
    [self updateFromJson:aResult preservingDirtyProperties:YES];
    [[self undoManager] enableUndoRegistration];
    [WLRemoteObject setDirtProof:NO];
}

- (void)remoteActionDidFinish:(WLRemoteAction)anAction
{
    if (![_actions count] || [_actions objectAtIndex:0] !== anAction)
        return;

    switch ([anAction type])
    {
        case WLRemoteActionPostType:
            [self remoteActionDidReceiveResourceRepresentation:[anAction result]];

            if ([_delegate respondsToSelector:@selector(remoteObjectWasCreated:)])
                [_delegate remoteObjectWasCreated:self];
            break;
        case WLRemoteActionDeleteType:
            // The previous PK is now gone.
            [self setPk:nil];

            // After the object has been deleted, the next call to 'ensureCreated' will
            // create a new object. When that creation happens all the data should be
            // considered dirty to ensure it gets sent with the creation.
            [self makeAllDirty];
            [self remoteObjectWasDeleted];
            break;
        case [[[self context] remoteLink] saveActionType]:
            if (pk)
            {
                var patchAction = [anAction type] === WLRemoteActionPatchType;

                [anAction setMessage:"Saving " + [self description]];
                [anAction setPayload:patchAction ? [self asPatchJSObject] : [self asJSObject]];
                [anAction setPath:patchAction ? [self patchPath] : [self putPath]];

                // Assume the action will succeed or retry until it does.
                [self setLastSyncedAt:[CPDate date]];
                _lastSyncedRevision = _revision;
            }
            else
                CPLog.error("Attempt to save non created object " + [self description]);
            break;
        case WLRemoteActionGetType:
            // Assume whatever was downloaded is the most current info, so nothing gets dirty.
            [self remoteActionDidReceiveResourceRepresentation:[anAction result]];
            [self remoteObjectWasLoaded];
            break;
        default:
            CPLog.error("Unexpected action: " + [anAction description]);
    }

    [_actions removeObjectAtIndex:0];
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

#pragma mark CPObject

- (CPString)description
{
    return "<" + [self class] + " " + [self UID] + (pk ? " " + pk : "") + ">";
}

@end

@implementation WLRemoteObject (CPCoding)

- (id)initWithCoder:(CPCoder)aCoder
{
    if (self = [self init])
    {
        pk = [aCoder decodeObjectForKey:@"$pk"];

        if (pk)
        {
            var existingObject = [[self class] instanceForPk:pk];
            if (existingObject)
                return existingObject;
        }

        [_remoteProperties enumerateObjectsUsingBlock:function(aProperty, idx)
            {
                [self setValue:[aCoder decodeObjectForKey:"$" + [aProperty localName]] forKeyPath:[aProperty localName]];
            }];
    }

    return self;
}

- (void)encodeWithCoder:(CPCoder)aCoder
{
    [_remoteProperties enumerateObjectsUsingBlock:function(aProperty, idx)
        {
            [aCoder encodeObject:[self valueForKeyPath:[aProperty localName]] forKey:"$" + [aProperty localName]];
        }];
}

@end

@implementation RemoteProperty : CPObject
{
    CPString            localName @accessors;
    CPString            remoteName @accessors;
    CPValueTransformer  valueTransformer @accessors;
    boolean             loadOnly @accessors(getter=isLoadOnly);
}

+ (id)propertyWithName:(CPString)aName
{
    return [self propertyWithLocalName:aName remoteName:aName transformer:nil];
}

+ (id)propertyWithLocalName:(CPString)aLocalName remoteName:(CPString)aRemoteName
{
    return [self propertyWithLocalName:aLocalName remoteName:aRemoteName transformer:nil];
}

+ (id)propertyWithLocalName:(CPString)aLocalName remoteName:(CPString)aRemoteName transformer:(CPValueTransformer)aTransformer loadOnly:(boolean)shouldBeLoadOnly
{
    var r = [RemoteProperty new];
    [r setLocalName:aLocalName];
    [r setRemoteName:aRemoteName];
    [r setValueTransformer:aTransformer];
    [r setLoadOnly:shouldBeLoadOnly];
    return r;
}

- (BOOL)isEqual:(id)anOther
{
    return (anOther !== nil && anOther.isa && [anOther isKindOfClass:RemoteProperty] && anOther.localName == self.localName);
}

- (CPString)description
{
    return "<RemoteProperty " + remoteName + ":" + localName + (loadOnly ? " (load-only)" : "") + ">";
}

@end
