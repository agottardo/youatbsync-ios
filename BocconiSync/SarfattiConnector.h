//
//  SarfattiConnector.h
//  you@B Sync
//
//  Created by Andrea Gottardo on 2/25/16.
//  Copyright © 2016 Andrea Gottardo. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 SarfattiConnector is a bridge between Objective-C and the Bocconi APIs.
 **/
@interface SarfattiConnector : NSObject

typedef void (^SarfattiAuthRequestCompleteBlock) (BOOL wasSuccessful, NSString *errorMessage, NSNumber *authID);
typedef void (^SarfattiCalendarRequestCompleteBlock) (BOOL wasSuccessful, NSString *errorMessage, NSDictionary *calendarDictionary);

-(NSString*)generateBasicHTTPAuthHeaderWithUsername:(NSString*)username AndPassword:(NSString*)password;

-(void)requestAuthIDWithUsername:(NSString*)username AndPassword:(NSString*)password WithBlock:(SarfattiAuthRequestCompleteBlock)block;

-(void)retrieveTimeTableWithAuthID:(NSString*)authID AndUsername:(NSString*)username AndPassword:(NSString*)password WithBlock:(SarfattiCalendarRequestCompleteBlock)block;

@end
