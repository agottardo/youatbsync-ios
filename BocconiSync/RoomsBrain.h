//
//  RoomsBrain.h
//  you@B Sync
//
//  Created by Andrea Gottardo on 2/25/16.
//  Copyright © 2016 Andrea Gottardo. All rights reserved.
//

#import <Foundation/Foundation.h>
@import CoreLocation;

@interface RoomsBrain : NSObject

-(CLLocation*)locationWithRoomString:(NSString*)room;

@end
