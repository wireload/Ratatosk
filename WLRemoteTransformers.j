/*
 * WLRemoteTransformers.j
 * Ratatosk
 *
 * Created by Alexander Ljungberg on September 28, 2011.
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

@import "WLDate-Util.j"

var IsNumberRegExp = new RegExp('^\d+$');

/*!
    Accept ISO8601 dates from the server, and format in ISO8601 when tranforming back to the server. Note that when transferring from remote->local, any ISO8601 format is accepted, but when transmitting from local->remote the format YYYY-MM-DDTHH:MM:SS +0000 is always used.
*/
@implementation WLDateTransformer : CPObject

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

+ (Class)transformedValueClass
{
    return [CPDate class];
}

- (id)transformedValue:(id)value
{
    if (value)
    {
        return new Date(Date.parseISO8601(value));
    }
    else
    {
        return nil;
    }
}

- (id)reverseTransformedValue:(id)value
{
    if (value)
    {
        // We want to send ISO8601 UTC dates.
        return [value utcDescription];
    }
    else
        return nil;
}

@end

@implementation WLIdSingleTransformer : CPObject

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

+ (Class)transformedValueClass
{
    return [CPNumber class];
}

- (id)transformedValue:(id)value
{
    if (value)
        return value.id;
    else
        return nil;
}

- (id)reverseTransformedValue:(id)value
{
    if (value)
        return {'id': value};
    else
        return {};
}

@end

/*!
    Instantiate 0 or 1 foreign object using whatever info is available,
    or update an existing object if it's already in the register.
*/
@implementation WLForeignObjectTransformer : CPObject
{
    id  foreignClass;
}

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

+ (Class)transformedValueClass
{
    return [WLRemoteObject class];
}

+ (id)forObjectClass:aForeignClass
{
    if (r = [self new])
    {
        r.foreignClass = aForeignClass;
    }
    return r;
}

- (id)transformedValue:(id)value
{
    if (value)
        return [[foreignClass alloc] initWithJson:value];

    return null;
}

/*!
    Reverse is not exact and just generates ids even if the original
    input had more data.
*/
- (id)reverseTransformedValue:(id)value
{
    var pk = [value pk];
    if (pk === nil)
        return nil;

    var dummy = [[foreignClass alloc] init],
        remotePkProperty = [dummy pkProperty],
        pkString = "" + pk,
        remoteName = [remotePkProperty remoteName],
        rObj = {};
    rObj[remoteName] = (IsNumberRegExp.test(pkString) ? parseInt(pkString) : pkString);

    return rObj;
}

@end

/*!
    Instantiate foreign objects using whatever info is available,
    or update existing objects if they're already in the register.
    In both cases, return an array with prepared instances.
*/
@implementation WLForeignObjectsTransformer : WLForeignObjectTransformer
{
}

- (id)transformedValue:(id)values
{
    var r = [];

    if (!values)
        return nil;

    if (!values.isa || ![values isKindOfClass:CPArray])
        [CPException raise:CPInvalidArgumentException reason:"WLForeignObjectsTransformer expects arrays"];

    for (var i = 0, count = [values count]; i < count; i++)
    {
        var obj = [super transformedValue:values[i]];
        if (obj !== nil)
            [r addObject:obj];
    }

    return r;
}

/*!
    Reverse is not exact and just generates ids even if the original
    input had more data.
*/
- (id)reverseTransformedValue:(id)values
{
    var r = [];

    for (var i = 0, count = [values count]; i < count; i++)
    {
        var value = values[i],
            repr = [super reverseTransformedValue:value];
        if (repr)
            [r addObject:repr];
    }

    return r;
}

@end


/*!
    Like WLForeignObjectsTransformer but if a value turns out not to be
    an array, assume it's a single instance of the foreign object.
*/
@implementation WLForeignObjectOrObjectsTransformer : WLForeignObjectsTransformer
{
}

- (id)transformedValue:(id)values
{
    if (!values)
        return nil;

    if (!values.isa || ![values isKindOfClass:CPArray])
        values = [values];

    return [super transformedValue:values];
}

@end

/*!
    Instantiate foreign objects using a primary key value as a string only. If the
    object is in the register, it will be used, otherwise a new unloaded object
    will be created (which can then be sent ensureLoaded to load fully.)
*/
@implementation WLForeignObjectByIdTransformer : CPObject
{
    id  foreignClass;
}

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

+ (Class)transformedValueClass
{
    return [WLRemoteObject class];
}

+ (id)forObjectClass:aForeignClass
{
    if (r = [self new])
    {
        r.foreignClass = aForeignClass;
    }
    return r;
}

- (id)transformedValue:(id)value
{
    return [foreignClass instanceForPk:value create:YES];
}

- (id)reverseTransformedValue:(id)value
{
    return [value pk];
}

@end

/*!
    Like WLForeignObjectByIdTransformer but take a list of ids to populate an array
    of remote objects. This could be used for an array of resource URIs for instance,
    if the PK is the resource URI.
*/
@implementation WLForeignObjectsByIdsTransformer : WLForeignObjectByIdTransformer
{
}

+ (Class)transformedValueClass
{
    return [CPArray class];
}

- (id)transformedValue:(id)values
{
    if (!values)
        return nil;

    if (!values.isa || ![values isKindOfClass:CPArray])
        [CPException raise:CPInvalidArgumentException reason:"WLForeignObjectsTransformer expects arrays"];

    var r = [];
    for (var i = 0, count = [values count]; i < count; i++)
    {
        var obj = [super transformedValue:values[i]];
        if (obj !== nil)
            [r addObject:obj];
    }

    return r;
}

- (id)reverseTransformedValue:(id)values
{
    var r = [];

    for (var i = 0, count = [values count]; i < count; i++)
    {
        var value = values[i],
            repr = [super reverseTransformedValue:value];
        if (repr)
            [r addObject:repr];
    }

    return r;
}

@end

/*!
    Takes a string and makes it a CPURL. Reversible.
*/
@implementation WLURLTransformer : CPObject

+ (boolean)allowsReverseTransformation
{
    return YES;
}

+ (Class)transformedValueClass
{
    return [CPURL class];
}

- (id)transformedValue:(id)aValue
{
    if (!aValue)
        return nil;
    return [CPURL URLWithString:aValue];
}

- (id)reverseTransformedValue:(id)aValue
{
    return [aValue absoluteString];
}

@end

/*!
    Takes a string and makes it a CPColor. Reversible.
*/
@implementation WLColorTransformer : CPObject

+ (boolean)allowsReverseTransformation
{
    return YES;
}

+ (Class)transformedValueClass
{
    return [CPColor class];
}

- (id)transformedValue:(id)aValue
{
    if (!aValue)
        return nil;
    return [CPColor colorWithHexString:aValue];
}

- (id)reverseTransformedValue:(id)aValue
{
    return [aValue hexString];
}

@end

/*!
    Takes a string URI and makes it a CPImage. Reversible.
*/
@implementation WLImageTransformer : CPObject

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

+ (Class)transformedValueClass
{
    return [CPImage class];
}

- (id)transformedValue:(id)aValue
{
    if (!aValue)
        return nil;
    return [[CPImage alloc] initWithContentsOfFile:aValue];
}

- (id)reverseTransformedValue:(id)aValue
{
    return [aValue filename];
}

@end

/*!
    Takes a boolean and makes it a boolean, which by itself would not be very useful. However, in reverse this transformer makes any JavaScript value into a boolean. E.g. nil and undefined become NO before being sent to the server.
*/
@implementation WLBooleanTransformer : CPObject

+ (boolean)allowsReverseTransformation
{
    return YES;
}

+ (Class)transformedValueClass
{
    return [CPNumber class];
}

- (id)transformedValue:(id)aValue
{
    return !!aValue;
}

- (id)reverseTransformedValue:(id)aValue
{
    return !!aValue;
}

@end

/*!
    Transform CPDecimalNumbers into strings or floats.
*/
@implementation WLDecimalNumberTransformer : CPObject
{
    id remoteFormat;
}

+ (id)transformerWithFormat:(Class)aFormat
{
    return [[WLDecimalNumberTransformer alloc] initWithFormat:aFormat];
}

+ (boolean)allowsReverseTransformation
{
    return YES;
}

+ (Class)transformedValueClass
{
    return [CPDecimalNumber class];
}

- (id)initWithFormat:(Class)aFormat
{
    if (self = [super init])
    {
        if (!(aFormat == CPNumber || aFormat == CPString))
            [CPException raise:CPInvalidArgumentException reason:@"Unsupported format."];
        remoteFormat = aFormat;
    }

    return self;
}

- (id)transformedValue:(id)aValue
{
    return [CPDecimalNumber decimalNumberWithString:"" + aValue];
}

- (id)reverseTransformedValue:(id)aValue
{
    if (remoteFormat == CPNumber)
        return [aValue floatValue];
    else
        return [aValue stringValue];
}

@end
