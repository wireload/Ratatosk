Ratatosk
========

Ratatosk is a Cappuccino remote object proxy for RESTful JSON based APIs.

Features:

* Download remote object JSON representation and transform it to local Objective-J objects.
* Partial downloads or 'lazy loading' (deferred loading of some properties.)
* Autosaving where changing an existing object leads to automatic PUT updates to the server.
* Autoloading which can be configured to pull related resources of an object automatically.
* Generates GET, POST, PUT and DELETE actions properly.
* Resolves multiple references to the same remote object to a single local proxy.
* Maintains a sequential, retriable operations queue.
* Easily set up error handling with retries and application error handling (retries are automatic and `isInErrorState` is an observable property).
* Undo manager friendly.
* Backend agnostic: works just as well with a Ruby on Rails API as a Django Piston one.
* Optional XML API support.

## Installation

Check out Ratatosk as a Git submodule in your app's `Frameworks` folder, or copy or link the folder into place. Then import Ratatosk:

    @import <Ratatosk/Ratatosk.j>

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

## CSRF and Authentication Headers

If you need to send special HTTP headers to the servers, such as `Authorization` or Cross Site Request Forgery protection tokens, you can configure this at the "link" level. `WLRemoteLink` represents the link to your server.

### Simple Authorisation

    [[WLRemoteLink sharedRemoteLink] setAuthorizationHeader:@"ApiKey user:DEADCAFE1234"];

This will add an unchanging HTTP `Authorization` header to every server request.

### CSRF or Complex Headers

If you need to do something more advanced, such as signing your requests or adding a CSRF token only for certain requests you can set a `WLRemoteLink` delegate and respond to the `remoteLink:willSendRequest:withDelegate:context:` delegate message.

This is an example for how to do CSRF headers:

    - (void)applicationDidFinishLaunching:(CPNotification)aNotification
    {
        [[WLRemoteLink sharedRemoteLink] setDelegate:self];
    }

    #pragma mark WLRemoteLink Delegate

    - (void)remoteLink:(WLRemoteLink)aLink willSendRequest:(CPURLRequest)aRequest withDelegate:(id)aDelegate context:(id)aContext
    {
        switch ([[aRequest HTTPMethod] uppercaseString])
        {
            case "POST":
            case "PUT":
            case "PATCH":
            case "DELETE":
                var csrfToken = [[[CPCookie alloc] initWithName:"csrftoken"] value];
                [aRequest setValue:csrfToken forHTTPHeaderField:@"X-CSRFToken"];
                break;
       }
    }

This assumes the CSRF token is available as a cookie named `csrftoken`.

You could also use this delegate method as a final opportunity to make general changes to requests.

### PUT vs PATCH

By default Ratatosk will transmit any changes you make using `PATCH` requests which only contain the properties which were actually changed. This minimises traffic and reduces problems related to rewriting data considered read-only.

If your server does not support the `PATCH` verb you can use `PUT` instead. With `PUT` requests the whole serialised form of the resource is "put" to the server for each change.

    [[WLRemoteLink sharedRemoteLink] setSaveAction:WLRemoteActionPutType];

## License ##

Free to use and modify under the terms of the BSD open source license.
