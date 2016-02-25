//
//  ViewController.h
//  BocconiSync
//
//  Created by Andrea Gottardo on 2/24/16.
//  Copyright © 2016 Andrea Gottardo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RoomsBrain.h"
@import EventKit;

@interface ViewController : UIViewController
@property (weak, nonatomic) IBOutlet UITextField *usernameField;
@property (weak, nonatomic) IBOutlet UITextField *passwordField;
@property (weak, nonatomic) IBOutlet UIButton *syncButton;
@property NSUserDefaults *defaults;
@property EKEventStore *calStore;
@property NSMutableArray *createdEventsStorage;
@property RoomsBrain *roomsBrain;
@property (weak, nonatomic) IBOutlet UILabel *lastSyncLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *progressBar;


@end

