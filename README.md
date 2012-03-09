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

## License ##

Free to use and modify under the terms of the BSD open source license.
