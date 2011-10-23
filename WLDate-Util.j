/*
 * WLDate-Util.j
 * RemoteObject
 *
 * Created by Alexander Ljungberg on October 23, 2011.
 * Copyright 2009, WireLoad Inc. All rights reserved.
 */

@implementation CPDate (UTC)
{

}

/*!
    Returns the date as a string in the international format
    YYYY-MM-DD HH:MM:SS +0000.
*/
- (CPString)utcDescription
{
    var offset = self.getTimezoneOffset() * 60000,
        utcDate = new Date(self.getTime() + offset);

    return [CPString stringWithFormat:@"%04d-%02d-%02d %02d:%02d:%02d +0000", utcDate.getFullYear(), utcDate.getMonth()+1, utcDate.getDate(), utcDate.getHours(), utcDate.getMinutes(), utcDate.getSeconds()];
}

@end
