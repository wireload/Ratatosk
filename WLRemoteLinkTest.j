@import "WLRemoteLink.j"

@implementation WLRemoteLinkTest : OJTestCase

- (void)testIsSecure
{
    var link = [WLRemoteLink new];
    [link setBaseUrl:'http://wireload.net/'];
    [self assertFalse:[link isSecure]];

    [link setBaseUrl:'https://wireload.net/'];
    [self assertTrue:[link isSecure]];

    [link setBaseUrl:'/api/'];
    [self assertFalse:[link isSecure]];
}

- (void)testUrlWithSslIffNeeded
{
    var link = [WLRemoteLink new];

    [link setBaseUrl:'http://wireload.net/'];
    [self assert:[link urlWithSslIffNeeded:'http://bob.com'] equals:'http://bob.com'];
    [self assert:[link urlWithSslIffNeeded:'https://bob.com'] equals:'http://bob.com'];
    [self assert:[link urlWithSslIffNeeded:'https://chronicle-dev.s3.amazonaws.com/user/1/1A?AWSAccessKeyId=AKIAJBFB4CAIFFTR6OMA&Expires=1277683200&Signature=w3SUFvN5Q%2B9ZEExy4hO3Tgywlo4%3D'] equals:'http://chronicle-dev.s3.amazonaws.com/user/1/1A?AWSAccessKeyId=AKIAJBFB4CAIFFTR6OMA&Expires=1277683200&Signature=w3SUFvN5Q%2B9ZEExy4hO3Tgywlo4%3D'];

    [link setBaseUrl:'https://wireload.net/'];
    [self assert:[link urlWithSslIffNeeded:'http://bob.com'] equals:'https://bob.com'];
    [self assert:[link urlWithSslIffNeeded:'https://bob.com'] equals:'https://bob.com'];

    [self assert:[link urlWithSslIffNeeded:'/bob/'] equals:'/bob/'];
    [self assert:[link urlWithSslIffNeeded:'hTTp://bob.com'] equals:'https://bob.com'];

}

@end
