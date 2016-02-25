//
//  ViewController.m
//  BocconiSync
//
//  Created by Andrea Gottardo on 2/24/16.
//  Copyright © 2016 Andrea Gottardo. All rights reserved.
//

#import "ViewController.h"
@import EventKit;

@implementation ViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    [self.progressBar setProgress:0];
    
    // Geolocation module for rooms locations
    self.roomsBrain = [[RoomsBrain alloc] init];
    
    // Defining NSUserDefaults, the iOS easy to use data storage. We'll use that for passwords.
    
    self.defaults = [NSUserDefaults standardUserDefaults];
    
    // Copying data from the storage to the text fields, if available.
    
    if ([self.defaults valueForKey:@"username"]) {
        [self.usernameField setText:[self.defaults valueForKey:@"username"]];
    }
    
    if ([self.defaults valueForKey:@"password"]) {
        [self.passwordField setText:[self.defaults valueForKey:@"password"]];
    }
    
    if ([self.defaults valueForKey:@"createdEventsStorage"]) {
        self.createdEventsStorage = [[self.defaults valueForKey:@"createdEventsStorage"] mutableCopy];
    } else {
        self.createdEventsStorage = [[NSMutableArray alloc] init];
    }
    
    self.calStore = [EKEventStore new];
    
    [self.calStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError *error) {
        if (!granted) {
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Unable to access the calendar" message:@"BocconiSync cannot access the iOS calendar. This might happen if you have denied BocconiSync authorization to access the calendar. Please re-authorize BocconiSync in the iOS Privacy settings. BocconiSync won't work correctly until you fix this issue." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        
        } }];
    
    if ([self.defaults valueForKey:@"lastSync"]) {
        [self.lastSyncLabel setText:[NSString stringWithFormat:@"Last sync: %@", [[self.defaults valueForKey:@"lastSync"] description]]];
    } else {
        [self.lastSyncLabel setText:@"Last sync: N/A"];
    }
    
}

- (IBAction)didPressSyncButton:(id)sender {
    
    // Let's sanitize the username and password fields first. We need to make sure a user cannot trigger a sync unless both credentials are available.
    
    if ([self.usernameField.text isEqual: @""]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Invalid username" message:@"Please insert a valid username. It is the same you use to access the you@B agenda or the university Wi-Fi network, and should also be the same as your student ID." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    } else {
        [self.defaults setObject:self.usernameField.text forKey:@"username"];
    }
    
    if ([self.passwordField.text isEqual: @""]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Invalid password" message:@"Please insert a valid password. It is the same you use to access the you@B agenda or the university Wi-Fi network." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    } else {
        [self.defaults setObject:self.passwordField.text forKey:@"password"];
        [self.defaults synchronize];
    }
    
    if(![self.usernameField.text isEqual: @""] | ![self.passwordField.text isEqual: @""]) {
        
        // And here we go.
        
        [self startSync];
        
    }
    
}

-(void)startSync{
    
    [_progressBar setProgress:0.2];
    
    [self.syncButton setEnabled:false];
    [self.syncButton setTitle:@"Syncing..." forState:UIControlStateDisabled];
    
    // Now that our login data is clear, let's have fun.
    
    // We first need to convert our username and password to base64, which Bocconi uses to "securely" encode the auth data. :-)
    
    // We create a NSData object, with the required username:password format
    NSData *authData = [[NSString stringWithFormat:@"%@:%@", [self.defaults valueForKey:@"username"], [self.defaults valueForKey:@"password"]] dataUsingEncoding:NSUTF8StringEncoding];
    
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
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Server problem - Auth" message:[NSString stringWithFormat:@"The Bocconi server is not returning the auth data as I expected. Maybe maintenance is in progress. I received this error code: %@.", response] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            return;
        }
    }
    
    NSError *parseError = nil;
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    if (!dictionary) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"JSON decoding problem - Auth" message:@"The Bocconi server is not returning data as I expected, and therefore I cannot convert it to NSData. Most probably, Bocconi has changed its data format. This is a serious issue, and you'll need to update this app. Check on the App Store to see if an update is available." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    // OK. That's exactly what we need.
    NSNumber *bocconiStrangeId = [[[dictionary objectForKey:@"auth_session"] objectForKey:@"careers"] valueForKey:@"id"][0];
    
    [_progressBar setProgress:0.5];
    
    // Now back to the calendar. Same procedure, but with a different URL.
    // We fetch events for two months from now.
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyyMMdd"];
    NSDate *todayDate = [NSDate date];
    NSDate *goalDate = [todayDate dateByAddingTimeInterval:5184000];
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
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Server problem - Calendar" message:[NSString stringWithFormat:@"The Bocconi server is not returning the calendar data as I expected. Maybe maintenance is in progress. I received this error code: %@.", response] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            return;
        }
    }
    
    parseError = nil;
    NSDictionary *calendarDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    if (!calendarDictionary) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"JSON decoding problem - Calendar" message:@"The Bocconi server is not returning data as I expected, and therefore I cannot convert it to NSData. Most probably, Bocconi has changed its data format. This is a serious issue, and you'll need to update this app. Check on the App Store to see if an update is available." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    [_progressBar setProgress:0.7];
    
    // Before adding new events, we delete all events that BocconiSync had created previously.
    [self deleteAllBocconiEvents];
    [self clearEventStorage];
    
    [_progressBar setProgress:0.8];
    
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
                
                EKEvent *event = [EKEvent eventWithEventStore:self.calStore];
                
                event.title = [lectureDictionary valueForKey:@"title"];
                
                // Room location done nicely! :-)

                EKStructuredLocation *lectureLocation = [EKStructuredLocation locationWithTitle:[lectureDictionary valueForKey:@"supertitle"]];
                lectureLocation.geoLocation = [self.roomsBrain locationWithRoomString:[lectureDictionary valueForKey:@"supertitle"]];
                [event setValue:lectureLocation forKey:@"structuredLocation"];
                
                event.startDate = startDate;
                event.endDate = endDate;
                
                event.calendar = [self.calStore defaultCalendarForNewEvents];
                
                event.notes = @"Added by you@B Sync";
                
                EKAlarm *eventAlarm = [[EKAlarm alloc] init];
                [eventAlarm setRelativeOffset:-(15*60)]; // alarm 15 minutes before
                [event addAlarm:eventAlarm];
                
                NSError *err = nil; // we need an error, apparently
                [self.calStore saveEvent:event span:EKSpanThisEvent commit:YES error:&err];
                
                // We save the identifier for the newly created event, so that we can delete it in the future (during the next sync!).
                NSString *savedEventId = event.eventIdentifier;
                [self.createdEventsStorage addObject:savedEventId];
                
            }
            
        }
    }
    
    [self.defaults setObject:self.createdEventsStorage forKey:@"createdEventsStorage"];
    
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Yeah!" message:[NSString stringWithFormat:@"The sync has been completed successfully. %lu events were added to the iOS calendar. Go and check it out!", (unsigned long)self.createdEventsStorage.count] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
    
    [_progressBar setProgress:1];
    
    [self.defaults setObject:[NSDate date] forKey:@"lastSync"];
    [self.defaults setObject:@"manual" forKey:@"reason"];
    [self.defaults synchronize];
    
    [self.lastSyncLabel setText:[NSString stringWithFormat:@"Last sync: %@", [[NSDate date] description]]];
    
    [self.syncButton setEnabled:true];
    [self.syncButton setTitle:@"Sync Now!" forState:UIControlStateNormal];
    
}

-(void)deleteAllBocconiEvents {
    for (NSString *eventIdentifier in self.createdEventsStorage) {
        EKEvent* eventToRemove = [self.calStore eventWithIdentifier:eventIdentifier];
        if (eventToRemove) {
            NSError *err = nil;
            [self.calStore removeEvent:eventToRemove span:EKSpanThisEvent commit:YES error:&err];
        }
    }
}

-(void)clearEventStorage{
    [self.createdEventsStorage removeAllObjects];
    [self.defaults setObject:self.createdEventsStorage forKey:@"createdEventsStorage"];
    [self.defaults synchronize];
}

@end
