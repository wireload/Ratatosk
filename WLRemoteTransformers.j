/*
 * WLRemoteTransformers.j
 * RemoteObject
 *
 * Created by Alexander Ljungberg on September 28, 2011.
 * Copyright 2009-11, WireLoad Inc. All rights reserved.
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
        // We get dates in UTC implied.
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
        return { 'id': value };
    else
        return {};
}

@end

/*!
    Instantiate foreign objects using whatever info is available,
    or update existing objects if they're already in the register.
    In both cases, return an array with prepared instances.
*/
@implementation WLForeignKeyTransformer : CPObject
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

- (id)transformedValue:(id)values
{
    var r = [];

    for (var i = 0, count = [values count]; i < count; i++)
    {
        var value = values[i];

        if (value && value.id)
        {
            var id = value.id,
                obj = [WLRemoteObject instanceOf:foreignClass forPk:id];
            if (obj !== nil)
                [obj updateFromJson:value];
            else
                obj = [[foreignClass alloc] initWithJson:value];
            [r addObject:obj];
        }
    }

    return r;
}

/*!
    Reverse is not exact and just generates id's even if the original
    input had more data.
*/
- (id)reverseTransformedValue:(id)values
{
    var r = [];

    for (var i = 0, count = [values count]; i < count; i++)
    {
        var value = values[i],
            pk = [value pk];
        if (pk !== nil)
        {
            [r addObject:{'id': parseInt(pk)}];
        }
    }

    return r;
}

@end
