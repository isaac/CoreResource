//
//  CorePingAppDelegate.m
//  CorePing
//
//  Created by Mike Laurence on 3/8/10.
//  Copyright Punkbot LLC 2010. All rights reserved.
//

#import "CorePingAppDelegate.h"
#import "PingsController.h"


@implementation CorePingAppDelegate

@synthesize window;
@synthesize navigationController;


#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    

    // Instantiate CoreManager
    coreManager = [[CoreManager alloc] init]; 
    coreManager.remoteSiteURL = @"http://coreresource.org";
	
    // Set up window & main view
	[window addSubview:[navigationController view]];
    [window makeKeyAndVisible];
	return YES;
}


- (void)applicationWillTerminate:(UIApplication *)application {
    [coreManager save];
}


#pragma mark -
#pragma mark Memory management

- (void)dealloc {
    [coreManager release];
	[navigationController release];
	[window release];
	[super dealloc];
}


@end

