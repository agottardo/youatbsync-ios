//
//  SarfattiConnector.m
//  you@B Sync
//
//  Created by Andrea Gottardo on 2/25/16.
//  Copyright © 2016 Andrea Gottardo. All rights reserved.
//

#import "SarfattiConnector.h"
#import <AFNetworking/AFNetworking.h>

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
    
    // Get a NSString from the NSData object in base64
    NSString *base64AuthString = [authData base64EncodedStringWithOptions:0];
    
    // As by HTTP specifics.
    return [NSString stringWithFormat:@"Basic %@", base64AuthString];
}

/**
 Retrieves the UserID used by the Bocconi APIs to perform requests. It is NOT the same as the student ID.
 @param username
 Same as the student ID, in most of the cases
 @param password
 The user's password
 */
-(void)requestAuthIDWithUsername:(NSString*)username AndPassword:(NSString*)password WithBlock:(SarfattiAuthRequestCompleteBlock)block {
    
    // Let's go with the first network request: we are asking Bocconi's servers for our user ID. That's a number which apparently identifies each student on the university database. And it's different from the usual student ID.
    // We need the number to be able to ask for the calendar in JSON format.
    
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFHTTPSessionManager *manager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:configuration];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    [manager.requestSerializer setValue:@"b0cc0n1s3cr3t" forHTTPHeaderField:@"auth_secret"];
    [manager.requestSerializer setValue:[self generateBasicHTTPAuthHeaderWithUsername:username AndPassword:password] forHTTPHeaderField:@"Authorization"];
    
    [manager GET:@"http://ks3-mobile.unibocconi.it/universityapp_prod/api/v6/app/init?os=android" parameters:nil progress:^(NSProgress * _Nonnull downloadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        // OK. That's exactly what we need.
        if ([[responseObject objectForKey:@"auth_session"] class] == [NSNull class]) {
            block(NO, @"Wrong credentials", nil);
        } else {
            NSNumber *bocconiStrangeId = [[[responseObject objectForKey:@"auth_session"] objectForKey:@"careers"] valueForKey:@"id"][0];
            block(YES, nil, bocconiStrangeId);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        block(NO, [NSString stringWithFormat:@"The Bocconi server is not returning the auth data as I expected. Maybe maintenance is in progress, or your network connection is down. I received this error code: %@.", error], nil);
    }];
    
}

/**
 Retrieves a calendar with all scheduled lectures in the next 30 days, and passes it inside a block.
 @param authID
        The API authentication ID. Can be retrieved by calling -(void)requestAuthIDWithUsername:(NSString*)username AndPassword:(NSString*)password WithBlock:(BocconiAuthRequestCompleteBlock)block;
 @param username
        Same as the student ID, in most of the cases
 @param password
        The user's password
 */
-(void)retrieveTimeTableWithAuthID:(NSString*)authID AndUsername:(NSString*)username AndPassword:(NSString*)password WithBlock:(SarfattiCalendarRequestCompleteBlock)block{
    
    // Now back to the calendar.
    // We fetch events for 30 days from now.
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyyMMdd"];
    NSDate *todayDate = [NSDate date];
    NSDate *goalDate = [todayDate dateByAddingTimeInterval:1296000*2];
    NSString *bocconiFormatTodayDate = [dateFormat stringFromDate:todayDate];
    NSString *bocconiFormatGoalDate = [dateFormat stringFromDate:goalDate];
    
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFHTTPSessionManager *manager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:configuration];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    [manager.requestSerializer setValue:@"b0cc0n1s3cr3t" forHTTPHeaderField:@"auth_secret"];
    [manager.requestSerializer setValue:[self generateBasicHTTPAuthHeaderWithUsername:username AndPassword:password] forHTTPHeaderField:@"Authorization"];
    
    [manager GET:[NSString stringWithFormat:@"http://ks3-mobile.unibocconi.it/universityapp_prod/api/v6/students/%@/agenda?rl=en&start=%@&end=%@", authID, bocconiFormatTodayDate, bocconiFormatGoalDate] parameters:nil progress:^(NSProgress * _Nonnull downloadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        block(YES, nil, responseObject);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        block(NO, [NSString stringWithFormat:@"AFNetworking error while fetching the calendar: %@", error], nil);
    }];
    
}

@end
