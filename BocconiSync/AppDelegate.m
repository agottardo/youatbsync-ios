//
//  AppDelegate.m
//  BocconiSync
//
//  Created by Andrea Gottardo on 2/24/16.
//  Copyright © 2016 Andrea Gottardo. All rights reserved.
//

#import "AppDelegate.h"
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>
#import "RoomsBrain.h"
@import EventKit;

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    [Fabric with:@[[Crashlytics class]]];
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:43200];
    return YES;
}

-(void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    NSLog(@"you@B fetch started");
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    EKEventStore *calStore = [EKEventStore new];
    NSMutableArray *createdEventsStorage;
    if ([standardDefaults valueForKey:@"createdEventsStorage"]) {
        createdEventsStorage = [[standardDefaults valueForKey:@"createdEventsStorage"] mutableCopy];
    } else {
        createdEventsStorage = [[NSMutableArray alloc] init];
    }
    RoomsBrain *roomsBrain = [[RoomsBrain alloc] init];
    
    
    NSData *authData = [[NSString stringWithFormat:@"%@:%@", [standardDefaults valueForKey:@"username"], [standardDefaults valueForKey:@"password"]] dataUsingEncoding:NSUTF8StringEncoding];
    
    // Get NSString from NSData object in Base64
    NSString *base64AuthString = [authData base64EncodedStringWithOptions:0];
    
    // Let's go with the first network request: we are asking Bocconi's servers for our user ID. That's a number which apparently identifies each student on the university database. And it's different from the usual student ID.
    // We need the number to be able to ask for the calendar in JSON format.
    
    // I'm sorry, Apple, but I need to cheat here. I still love you though.
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://ks3-mobile.unibocconi.it/universityapp_prod/api/v6/app/init?os=android"]];
    
    [request setHTTPMethod:@"GET"];
    
    // That's really a nice and secure password nobody can guess, congratulations.
    [request setValue:@"b0cc0n1s3cr3t" forHTTPHeaderField:@"auth_secret"];
    
    // This feels very 1990s.
    [request setValue:[NSString stringWithFormat:@"Basic %@", base64AuthString] forHTTPHeaderField:@"Authorization"];
    
    // Technical iOS stuff. We are launching a network request on the main thread since, well, the app doesn't really do anything else.
    
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&response
                                                     error:&error];
    if (!data) {
        NSLog(@"%s: sendSynchronousRequest error: %@", __FUNCTION__, error);
        return;
    } else if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode != 200) {
            return;
        }
    }
    
    NSError *parseError = nil;
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    if (!dictionary) {
        return;
    }
    
    // OK. That's exactly what we need.
    NSNumber *bocconiStrangeId = [[[dictionary objectForKey:@"auth_session"] objectForKey:@"careers"] valueForKey:@"id"][0];
    
    // Now back to the calendar. Same procedure, but with a different URL.
    // We fetch events for two months from now.
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyyMMdd"];
    NSDate *todayDate = [NSDate date];
    NSDate *goalDate = [todayDate dateByAddingTimeInterval:1296000];
    NSString *bocconiFormatTodayDate = [dateFormat stringFromDate:todayDate];
    NSString *bocconiFormatGoalDate = [dateFormat stringFromDate:goalDate];
    
    NSMutableURLRequest *calendarRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://ks3-mobile.unibocconi.it/universityapp_prod/api/v6/students/%@/agenda?rl=en&start=%@&end=%@", bocconiStrangeId, bocconiFormatTodayDate, bocconiFormatGoalDate]]];
    
    [calendarRequest setHTTPMethod:@"GET"];
    
    // "30 e lode" to the guy who came up with this, seriously.
    [calendarRequest setValue:@"b0cc0n1s3cr3t" forHTTPHeaderField:@"auth_secret"];
    
    // Feels very 1990s: https://en.wikipedia.org/wiki/Basic_access_authentication
    [calendarRequest setValue:[NSString stringWithFormat:@"Basic %@", base64AuthString] forHTTPHeaderField:@"Authorization"];
    
    response = nil;
    error = nil;
    data = [NSURLConnection sendSynchronousRequest:calendarRequest
                                 returningResponse:&response
                                             error:&error];
    if (!data) {
        NSLog(@"%s: sendSynchronousRequest error: %@", __FUNCTION__, error);
        return;
    } else if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode != 200) {
            
            return;
        }
    }
    
    parseError = nil;
    NSDictionary *calendarDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    if (!calendarDictionary) {
        
        return;
    }
    
    // Before adding new events, we delete all events that BocconiSync had created previously.
    for (NSString *eventIdentifier in createdEventsStorage) {
        EKEvent* eventToRemove = [calStore eventWithIdentifier:eventIdentifier];
        if (eventToRemove) {
            NSError *err = nil;
            [calStore removeEvent:eventToRemove span:EKSpanThisEvent commit:YES error:&err];
        }
    }
    
    [createdEventsStorage removeAllObjects];
    [standardDefaults setObject:createdEventsStorage forKey:@"createdEventsStorage"];
    [standardDefaults synchronize];
    
    for (NSDictionary *dayDictionary in calendarDictionary) {
        NSMutableArray *dayArray = [dayDictionary objectForKey:@"events"];
        for (NSDictionary *lectureDictionary in dayArray) {
            if ([[lectureDictionary valueForKey:@"type"] isEqual:@2]) {
                
            } else {
                
                // Working a little bit on the date, to convert it to NSDate format.
                
                NSString *dateStart = [lectureDictionary valueForKey:@"date_start"];
                NSString *dateStartTrimmed = [dateStart substringFromIndex:6];
                NSString *dateStartTrimmed2 = [dateStartTrimmed substringToIndex:10];
                NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:[dateStartTrimmed2 doubleValue]];
                NSString *dateEnd = [lectureDictionary valueForKey:@"date_end"];
                NSString *dateEndTrimmed = [dateEnd substringFromIndex:6];
                NSString *dateEndTrimmed2 = [dateEndTrimmed substringToIndex:10];
                NSDate *endDate = [NSDate dateWithTimeIntervalSince1970:[dateEndTrimmed2 doubleValue]];
                
                NSLog(@"A lecture was found: %@. It will be held in %@ from %@ to %@.", [lectureDictionary valueForKey:@"title"], [lectureDictionary valueForKey:@"supertitle"], startDate, endDate);
                
                // We create a new calendar event for the lecture, and we add it to the default calendar.
                
                EKEvent *event = [EKEvent eventWithEventStore:calStore];
                
                event.title = [lectureDictionary valueForKey:@"title"];
                
                // Room location done nicely! :-)
                
                EKStructuredLocation *lectureLocation = [EKStructuredLocation locationWithTitle:[lectureDictionary valueForKey:@"supertitle"]];
                lectureLocation.geoLocation = [roomsBrain locationWithRoomString:[lectureDictionary valueForKey:@"supertitle"]];
                [event setValue:lectureLocation forKey:@"structuredLocation"];
                
                event.startDate = startDate;
                event.endDate = endDate;
                
                event.calendar = [calStore defaultCalendarForNewEvents];
                
                event.notes = @"Added by you@B Sync";
                
                EKAlarm *eventAlarm = [[EKAlarm alloc] init];
                [eventAlarm setRelativeOffset:-(15*60)]; // alarm 15 minutes before
                [event addAlarm:eventAlarm];
                
                NSError *err = nil; // we need an error, apparently
                [calStore saveEvent:event span:EKSpanThisEvent commit:YES error:&err];
                
                // We save the identifier for the newly created event, so that we can delete it in the future (during the next sync!).
                NSString *savedEventId = event.eventIdentifier;
                [createdEventsStorage addObject:savedEventId];
                
            }
            
        }
    }
    
    [standardDefaults setObject:createdEventsStorage forKey:@"createdEventsStorage"];
    NSNumber *count = [NSNumber numberWithUnsignedLong:createdEventsStorage.count];
    [Answers logCustomEventWithName:@"SyncComplete" customAttributes:@{@"Events Count":count}];
    
    [standardDefaults setObject:[NSDate date] forKey:@"lastSync"];
    [standardDefaults setObject:@"auto" forKey:@"reason"];
    [standardDefaults synchronize];
    
    // Set up Local Notifications
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    UILocalNotification *localNotification = [[UILocalNotification alloc] init];
    NSDate *now = [NSDate date];
    localNotification.fireDate = now;
    localNotification.alertBody = @"Your calendar has been updated automatically.";
    [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
    
    completionHandler(UIBackgroundFetchResultNewData);
    NSLog(@"Fetch completed");
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
