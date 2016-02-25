//
//  RoomsBrain.m
//  you@B Sync
//
//  Created by Andrea Gottardo on 2/25/16.
//  Copyright © 2016 Andrea Gottardo. All rights reserved.
//

#import "RoomsBrain.h"

@implementation RoomsBrain

-(CLLocation*)locationWithRoomString:(NSString*)room{
    
    CLLocation *roomLocation;
    
    // This method is gorgeous. Calendar apps can be much more interactive, if we associate each room with
    // real geographic coordinates. For instance, Siri or Google Now can send a notification before a lecture
    // is about to start, with the walking time expected. Really cool.
    
    // aula or room is 4 characters long, plus the space: by subtracting the first 5 characters we obtain the room number
    NSString *roomNumber = [room substringFromIndex:5]; // N22, InfoAS03, 201, etc.
    
    // Now, just by looking at the first character of the room number, we can deduce where the building
    // where the lecture will be held.
    
    NSString *firstCharacter = [roomNumber substringToIndex:1];
    
    if ([firstCharacter isEqualToString:@"N"]) {
        // Velodromo
        roomLocation = [[CLLocation alloc] initWithLatitude:45.45029 longitude:9.188647];
    } else if ([firstCharacter isEqualToString:@"I"] | [firstCharacter isEqualToString:@"A"]) {
        // Roentgen Building
        roomLocation = [[CLLocation alloc] initWithLatitude:45.450761 longitude:9.187564];
    } else {
        // Fall-back to Via Sarfatti for all other situations
        roomLocation = [[CLLocation alloc] initWithLatitude:45.448446 longitude:9.189935];
    }
    
    return roomLocation;
}

@end
