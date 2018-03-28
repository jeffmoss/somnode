//
//  AppDelegate.h
//  Somnode
//
//  Created by Jeff Moss on 3/18/18.
//  Copyright © 2018 Jeff Moss. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong) NSPersistentContainer *persistentContainer;

- (void)saveContext;


@end

