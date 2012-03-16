Ratatosk
========

Ratatosk is a Cappuccino remote object proxy for RESTful JSON based APIs.

Features:

* Download remote object JSON representation and transform it to local Objective-J objects.
* Partial downloads or 'lazy loading' (deferred loading of some properties.)
* Autosaving where changing an existing object leads to automatic PUT updates to the server.
* Generates GET, POST, PUT and DELETE actions properly.
* Resolve multiple references to the same remote object to a single local proxy.
* Maintain a sequential, retriable operations queue.
* Easily set up error handling with retries and application error handling (retries are automatic and `isInErrorState` is an observable property).
* Undo manager friendly.
* Backend agnostic: works just as well with a Ruby on Rails API as a Django Piston one.
* Optional XML API support.

## Usage ##

To be written. In the meantime, please see the source documentation and the unit tests.

## Auto Loading ##

If an object has a relationship to another object, you might want to automatically send `ensureLoaded` to that other object when discovered. You can do that with the auto loading features. Assuming you have another remote object called `User`, you could:

    @implementation BlogPost : WLRemoteObject
    {
        User owner @accessors;
    }

    + (CPArray)remoteProperties
    {
        return [
            ['pk', 'id'],
            ['owner', 'owner_id', [WLForeignObjectByIdTransformer forObjectClass:User]]
        ];
    }

    + (BOOL)automaticallyLoadsRemoteObjectsForUser
    {
        // Whenever `owner` is set, automatically  send `[owner ensureLoaded]`.
        return YES;
    }

    @end

Note that even with auto loading you will want to use observation or bindings for actually displaying values from the `owner` relationship. It will immediately be scheduled for loading, but loading is still asynchronous and could finish much later than the loading of the `BlogPost` itself.

## XML based APIs and other non-JSON APIs ##
While Ratatosk is meant for JSON based APIs you can provide your own per resource encoding and decoding support, which should take JSON and transform it to the appropriate format, and then take the response and turn it back into JSON.

Note that since Ratatosk is meant to work with typical JSON APIs it expects fairly flat dictionaries of properties for each resource. So a deeply nested XML structure with a lot of tag attributes would not map naturally to Ratatosk.

Ratatosk includes a JXON implementation which makes the mapping process easier. Here's an example of a `WLRemoteObject` mapping to an XML resource:

    @implementation XmlMoneyResource : WLRemoteObject
    {
        float    value @accessors;
        CPString currency @accessors;
    }

    + (CPArray)remoteProperties
    {
        return [
            ['pk', 'id'],
            ['value'],
            ['currency', '@currency'] // use leading @ for attribute notation.
        ];
    }

    - (CPString)remoteActionContentType:(WLRemoteAction)anAction
    {
        return @"application/xml; charset=utf-8";
    }

    - (CPString)remoteAction:(WLRemoteAction)anAction encodeRequestBody:(Object)aRequestBody
    {
        return JXON.toXML(aRequestBody, "money");
    }

    - (CPString)remoteAction:(WLRemoteAction)anAction decodeResponseBody:(Object)aResponseBody
    {
        var r = JXON.fromXML(aResponseBody)['money'];
        return r;
    }

    @end

    function test()
    {
        var someMoney = [XmlMoneyResource new];
        [someMoney setValue:95];
        [someMoney setCurrency:@"GBP"];
        [someMoney ensureCreated];
        // ... will POST '<money currency="GBP"><id/><value>95</value></money>'
    }

## License ##

Free to use and modify under the terms of the BSD open source license.
