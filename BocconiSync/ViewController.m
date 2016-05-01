//
//  ViewController.m
//  BocconiSync
//
//  Created by Andrea Gottardo on 2/24/16.
//  Copyright © 2016 Andrea Gottardo. All rights reserved.
//

#import "ViewController.h"
#import <Crashlytics/Answers.h>
#import "NSDate+RelativeTime.h"
@import EventKit;

@implementation ViewController

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    if ([self.defaults valueForKey:@"lastSync"]) {
        [self.lastSyncLabel setText:[NSString stringWithFormat:@"Last sync: %@", [[self.defaults valueForKey:@"lastSync"] relativeTime]]];
    } else {
        [self.lastSyncLabel setText:@"Last sync: N/A"];
    }
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    [self.progressBar setProgress:0];
    
    // Geolocation module for rooms locations
    self.roomsBrain = [[RoomsBrain alloc] init];
    
    self.sarfattiConnector = [[SarfattiConnector alloc] init];
    
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
    
    self.calStore = [[EKEventStore alloc] init];
    
    [self.calStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError *error) {
        if (!granted) {
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Unable to access the calendar" message:@"BocconiSync cannot access the iOS calendar. This might happen if you have denied BocconiSync authorization to access the calendar. Please re-authorize BocconiSync in the iOS Privacy settings. BocconiSync won't work correctly until you fix this issue." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        
        } }];
    
    if ([self.defaults valueForKey:@"lastSync"]) {
        [self.lastSyncLabel setText:[NSString stringWithFormat:@"Last sync: %@", [[self.defaults valueForKey:@"lastSync"] relativeTime]]];
    } else {
        [self.lastSyncLabel setText:@"Last sync: N/A"];
    }
    
}

- (IBAction)didPressSyncButton:(id)sender {
    
    [self.view endEditing:YES];
    
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
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    [_progressBar setProgress:0.2];
    
    [self.syncButton setEnabled:false];
    [self.syncButton setTitle:@"Syncing..." forState:UIControlStateDisabled];
    
    // Now that our login data is clear, let's have fun.
    
    [self.sarfattiConnector requestAuthIDWithUsername:[self.defaults valueForKey:@"username"] AndPassword:[self.defaults valueForKey:@"password"] WithBlock:^(BOOL wasSuccessful, NSString *errorMessage, NSNumber *authID) {
        if (!wasSuccessful) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:errorMessage delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            [_progressBar setProgress:0.0];
            
            [self.syncButton setEnabled:true];
            [self.syncButton setTitle:@"Sync now!" forState:UIControlStateDisabled];
        } else {
            
            [_progressBar setProgress:0.5];
            
            [self.sarfattiConnector retrieveTimeTableWithAuthID:authID AndUsername:[self.defaults valueForKey:@"username"] AndPassword:[self.defaults valueForKey:@"password"] WithBlock:^(BOOL wasSuccessful, NSString *errorMessage, NSDictionary *calendarDictionary) {
                
                [_progressBar setProgress:0.7];
                
                // Before adding new events, we delete all events that BocconiSync had created previously.
                [self deleteAllBocconiEvents];
                [self clearEventStorage];
                
                [_progressBar setProgress:0.8];
                
                [self.calStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError *error) {
                    if (!granted) {
                        
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Unable to access the calendar" message:@"BocconiSync cannot access the iOS calendar. This might happen if you have denied BocconiSync authorization to access the calendar. Please re-authorize BocconiSync in the iOS Privacy settings. BocconiSync won't work correctly until you fix this issue." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        [alert show];
                        
                    } else if (granted) {
                        
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
                                    
                                    //NSLog(@"A lecture was found: %@. It will be held in %@ from %@ to %@.", [lectureDictionary valueForKey:@"title"], [lectureDictionary valueForKey:@"supertitle"], startDate, endDate);
                                    
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
                        [self.defaults setObject:[NSDate date] forKey:@"lastSync"];
                        [self.defaults setObject:@"manual" forKey:@"reason"];
                        [self.defaults synchronize];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Yeah!" message:[NSString stringWithFormat:@"The sync has been completed successfully. %lu events were added to the iOS calendar. Go and check it out!", (unsigned long)self.createdEventsStorage.count] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                            NSNumber *count = [NSNumber numberWithUnsignedLong:self.createdEventsStorage.count];
                            [alert show];
                            [_progressBar setProgress:1];
                            [self.lastSyncLabel setText:[NSString stringWithFormat:@"Last sync: %@", [[NSDate date] relativeTime]]];
                            [self.syncButton setEnabled:true];
                            [self.syncButton setTitle:@"Sync Now!" forState:UIControlStateNormal];
                            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                            [Answers logCustomEventWithName:@"SyncComplete" customAttributes:@{@"Events Count":count}];
                        });
                        
                        
                        
                    }
                }];
                
            }];
            
        }
        
    }];
    
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

- (IBAction)forceDelete:(id)sender {
    if ([self.defaults valueForKey:@"createdEventsStorage"]) {
        self.createdEventsStorage = [[self.defaults valueForKey:@"createdEventsStorage"] mutableCopy];
    } else {
        self.createdEventsStorage = [[NSMutableArray alloc] init];
    }
    [self deleteAllBocconiEvents];
    [self clearEventStorage];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Deletion completed" message:@"All events created by you@B Sync have been deleted from the iOS calendar." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
}

-(void)clearEventStorage{
    [self.createdEventsStorage removeAllObjects];
    [self.defaults setObject:self.createdEventsStorage forKey:@"createdEventsStorage"];
    [self.defaults synchronize];
}

@end
