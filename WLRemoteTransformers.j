/*
 * WLRemoteTransformers.j
 * RemoteObject
 *
 * Created by Alexander Ljungberg on September 28, 2011.
 * Copyright 2009-11, WireLoad Inc. All rights reserved.
 */

@import "WLDate-Util.j"

var IsNumberRegExp = new RegExp('^\d+$');

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
        // If the timezone specifier was left out, add it.
        var dateTestRegEx = new RegExp(' [+-]\d{4}$');
        if (!dateTestRegEx.test(value))
            value += ' +0000';
        return [[CPDate alloc] initWithString:value];
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
        // We want to send UTC dates.
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

    for (var i = 0, count = [values count]; i < count; i++)
    {
        obj = [super transformedValue:values[i]];
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
