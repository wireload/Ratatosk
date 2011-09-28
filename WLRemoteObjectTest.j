@import "WLRemoteObject.j"
@import "WLRemoteTransformers.j"

@implementation WLRemoteObjectTest : OJTestCase
{
}

- (void)testInstanceByPk
{
    [self assert:nil equals:[TestRemoteObject instanceOf:TestRemoteObject forPk:nil] message:"nothing for pk nil"];

    var test1 = [[TestRemoteObject alloc] initWithJson:{'id': 5, 'name': 'test1'}],
        test2 = [[TestRemoteObject alloc] initWithJson:{'id': 15, 'name': 'test2'}];

    [self assertTrue:[WLRemoteObject instanceOf:TestRemoteObject forPk:5] === test1 message:"test1 at pk 5"];
    [self assertTrue:[WLRemoteObject instanceOf:TestRemoteObject forPk:15] === test2 message:"test2 at pk 15"];

    [test1 setPk:nil];
    [self assert:nil equals:[WLRemoteObject instanceOf:TestRemoteObject forPk:5] message:"test1 no longer at pk 5"];

    [test1 setPk:7];
    [self assertTrue:[WLRemoteObject instanceOf:TestRemoteObject forPk:5] === nil message:"nothing at pk 5"];
    [self assertTrue:[WLRemoteObject instanceOf:TestRemoteObject forPk:7] === test1 message:"test1 now at pk 7"];
    [self assertTrue:[WLRemoteObject instanceOf:TestRemoteObject forPk:15] === test2];

    // No conflicts between different kinds of remote objects.
    var test3 = [[OtherRemoteObject alloc] initWithJson:{'id': 5}],
        test4 = [[OtherRemoteObject alloc] initWithJson:{'id': 7}],
        test5 = [[OtherRemoteObject alloc] initWithJson:{'id': 15}];

    [self assertTrue:[WLRemoteObject instanceOf:TestRemoteObject forPk:7] === test1];
    [self assertTrue:[WLRemoteObject instanceOf:TestRemoteObject forPk:15] === test2];
    [self assertTrue:[WLRemoteObject instanceOf:OtherRemoteObject forPk:7] === test4];
    [self assertTrue:[WLRemoteObject instanceOf:OtherRemoteObject forPk:15] === test5];
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
}

- (void)testForeignKeyTransformer
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
    var jso = [test2 asPostJSObject];
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

    [self assertFalse:[test1 isDirty] message:"test1 isDirty"];
    [self assertFalse:[test2 isDirty] message:"test2 isDirty"];

    [test2 setName:"Bob"];
    [self assertFalse:[test1 isDirty] message:"test1 isDirty"];
    [self assertTrue:[test2 isDirty] message:"test2 isDirty"];

    [test2 cleanAll];
    [self assertFalse:[test2 isDirty] message:"test2 isDirty"];
}

@end

@implementation TestRemoteObject : WLRemoteObject
{
    CPString    name @accessors;
    long        count @accessors;
    CPArray     otherObjects @accessors;
}

- (void)init
{
    if (self = [super init])
    {
        otherObjects = [];
        [self registerRemoteProperties:[
            [RemoteProperty propertyWithName:'name'],
            [RemoteProperty propertyWithName:'count'],
            [RemoteProperty propertyWithLocalName:'otherObjects' remoteName:'other_objects' transformer:[WLForeignKeyTransformer forObjectClass:OtherRemoteObject]],
        ]];
    }
    return self;
}

- (CPString)description
{
    return [self UID]+ " " + [self pk] + " " + [self name];
}

@end

@implementation OtherRemoteObject : WLRemoteObject
{
    CPString coolness @accessors;
}

- (void)init
{
    if (self = [super init])
    {
        [self registerRemoteProperties:[
            [RemoteProperty propertyWithName:'coolness'],
        ]];
    }
    return self;
}

- (CPString)description
{
    return "OtherRemoteObject: " + [self UID] + s " " + [self pk];
}

@end
