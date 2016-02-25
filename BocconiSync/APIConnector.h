//
//  APIConnector.h
//  you@B Sync
//
//  Created by Andrea Gottardo on 2/25/16.
//  Copyright © 2016 Andrea Gottardo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface APIConnector : NSObject

typedef void (^BocconiAuthRequestCompleteBlock) (BOOL wasSuccessful, NSString *errorMessage, NSNumber *authID);
typedef void (^BocconiCalendarRequestCompleteBlock) (BOOL wasSuccessful, NSString *errorMessage, NSDictionary *calendarDictionary);

-(NSString*)generateBasicHTTPAuthHeaderWithUsername:(NSString*)username AndPassword:(NSString*)password;

-(void)requestAuthIDWithUsername:(NSString*)username AndPassword:(NSString*)password WithBlock:(BocconiAuthRequestCompleteBlock)block;

-(void)retrieveTimeTableWithAuthID:(NSString*)authID AndUsername:(NSString*)username AndPassword:(NSString*)password WithBlock:(BocconiCalendarRequestCompleteBlock)block;

@end
