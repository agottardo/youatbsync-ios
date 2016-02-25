//
//  SarfattiConnector.m
//  you@B Sync
//
//  Created by Andrea Gottardo on 2/25/16.
//  Copyright © 2016 Andrea Gottardo. All rights reserved.
//

#import "SarfattiConnector.h"

@implementation SarfattiConnector

/**
 Generate the content for the Authorization HTTP header used by the Bocconi APIs.
 @see https://en.wikipedia.org/wiki/Basic_access_authentication
 @param username
        Same as the student ID, in most of the cases
 @param password
        The user's password
 */
-(NSString*)generateBasicHTTPAuthHeaderWithUsername:(NSString*)username AndPassword:(NSString*)password{
    // For all API requests, we first need to convert our username and password to base64, which Bocconi uses to "securely" encode the auth data. :-)
    // We create a NSData object, with the required username:password format.
    
    NSData *authData = [[NSString stringWithFormat:@"%@:%@", username, password] dataUsingEncoding:NSUTF8StringEncoding];
    
    // Get NSString from NSData object in Base64
    NSString *base64AuthString = [authData base64EncodedStringWithOptions:0];
    
    return [NSString stringWithFormat:@"Basic %@", base64AuthString];
}

/**
 Retrieves the UserID used by the Bocconi APIs to perform requests. It is NOT the same as the student ID.
 @param username
 Same as the student ID, in most of the cases
 @param password
 The user's password
 */
-(void)requestAuthIDWithUsername:(NSString*)username AndPassword:(NSString*)password WithBlock:(BocconiAuthRequestCompleteBlock)block {
    
    // Let's go with the first network request: we are asking Bocconi's servers for our user ID. That's a number which apparently identifies each student on the university database. And it's different from the usual student ID.
    // We need the number to be able to ask for the calendar in JSON format.
    
    // I'm sorry, Apple, but I need to cheat here. I still love you though.
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://ks3-mobile.unibocconi.it/universityapp_prod/api/v6/app/init?os=android"]];
    
    [request setHTTPMethod:@"GET"];
    
    // That's really a nice and secure password nobody can guess, congratulations.
    [request setValue:@"b0cc0n1s3cr3t" forHTTPHeaderField:@"auth_secret"];
    
    // This feels very 1990s.
    [request setValue:[self generateBasicHTTPAuthHeaderWithUsername:username AndPassword:password] forHTTPHeaderField:@"Authorization"];
    
    // Technical iOS stuff. We are launching a network request on the main thread since, well, the app doesn't really do anything else.
    
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&response
                                                     error:&error];
    if (!data) {
        block(NO, [NSString stringWithFormat:@"The Bocconi server is not returning the auth data as I expected. Maybe maintenance is in progress. I received this error code: %@.", error], nil);
    } else if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode != 200) {
            block(NO, [NSString stringWithFormat:@"The Bocconi server is not returning the auth data as I expected. Maybe maintenance is in progress. I received this error code: %@.", response], nil);
        }
    }
    
    NSError *parseError = nil;
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    if (!dictionary) {
        block(NO, @"The Bocconi server is not returning data as I expected, and therefore I cannot convert it to NSData. Most probably, Bocconi has changed its data format. This is a serious issue, and you'll need to update this app. Check on the App Store to see if an update is available.", nil);
    } else {
        // OK. That's exactly what we need.
        NSNumber *bocconiStrangeId = [[[dictionary objectForKey:@"auth_session"] objectForKey:@"careers"] valueForKey:@"id"][0];
        block(YES, nil, bocconiStrangeId);
    }
    
}

/**
 Retrieves a calendar with all scheduled lectures in the next 15 days.
 @param authID
        The API authentication ID. Can be retrieved by calling -(void)requestAuthIDWithUsername:(NSString*)username AndPassword:(NSString*)password WithBlock:(BocconiAuthRequestCompleteBlock)block;
 @param username
        Same as the student ID, in most of the cases
 @param password
        The user's password
 */
-(void)retrieveTimeTableWithAuthID:(NSString*)authID AndUsername:(NSString*)username AndPassword:(NSString*)password WithBlock:(BocconiCalendarRequestCompleteBlock)block{
    
    // Now back to the calendar.
    // We fetch events for 15 days from now.
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyyMMdd"];
    NSDate *todayDate = [NSDate date];
    NSDate *goalDate = [todayDate dateByAddingTimeInterval:1296000];
    NSString *bocconiFormatTodayDate = [dateFormat stringFromDate:todayDate];
    NSString *bocconiFormatGoalDate = [dateFormat stringFromDate:goalDate];
    
    NSMutableURLRequest *calendarRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://ks3-mobile.unibocconi.it/universityapp_prod/api/v6/students/%@/agenda?rl=en&start=%@&end=%@", authID, bocconiFormatTodayDate, bocconiFormatGoalDate]]];
    
    [calendarRequest setHTTPMethod:@"GET"];
    
    // "30 e lode" to the guy who came up with this, seriously.
    [calendarRequest setValue:@"b0cc0n1s3cr3t" forHTTPHeaderField:@"auth_secret"];
    
    [calendarRequest setValue:[self generateBasicHTTPAuthHeaderWithUsername:username AndPassword:password] forHTTPHeaderField:@"Authorization"];
    
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:calendarRequest
                                 returningResponse:&response
                                             error:&error];
    if (!data) {
        block(NO, [NSString stringWithFormat:@"sendSynchronousRequest error: %@", error], nil);
    } else if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode != 200) {
            block(NO, [NSString stringWithFormat:@"The Bocconi server is not returning the calendar data as I expected. Maybe maintenance is in progress. I received this error code: %@.", response], nil);
        }
    }
    
    NSError *parseError = nil;
    NSDictionary *calendarDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    if (!calendarDictionary) {
        block(NO, @"The Bocconi server is not returning data as I expected, and therefore I cannot convert it to NSData. Most probably, Bocconi has changed its data format. This is a serious issue, and you'll need to update this app. Check on the App Store to see if an update is available.", nil);
    } else {
        block(YES, nil, calendarDictionary);
    }
    
}



@end
