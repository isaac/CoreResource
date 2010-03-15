//
//  CoreDeserializer.m
//  Core Resource
//
//  Created by Mike Laurence on 3/11/10.
//  Copyright 2010 Mike Laurence.
//

#import "CoreDeserializer.h"
#import "CoreResult.h"
#import "NSObject+Core.h"


@implementation CoreDeserializer

@synthesize source, format, coreManager, resourceClass;
@synthesize target, action;

- (void) main {
    // Get Core Manager from resource class if it hasn't been defined yet
    if (coreManager == nil)
        coreManager = [resourceClass performSelector:@selector(coreManager)];

    // Create "scratchpad" object context; we will merge this context into the main context once deserialization is complete
    NSManagedObjectContext *managedObjectContext = [[NSManagedObjectContext alloc] init];
    [managedObjectContext setPersistentStoreCoordinator:[coreManager persistentStoreCoordinator]];
    [[NSNotificationCenter defaultCenter] addObserver:self 
        selector:@selector(contextDidSave:) 
        name:NSManagedObjectContextDidSaveNotification 
        object:managedObjectContext];
        
    //NSArray* resources = [resourceClass performSelector:@selector(deserializeFromString:) withObject:json];
    
    // Attempt to save object context; if there's an error, it will be placed in the CoreResult (which is sent to the target)
    NSError *error = nil;
    [managedObjectContext save:&error];
        
    // Remove context save observer
    [[NSNotificationCenter defaultCenter] removeObserver:self 
        name:NSManagedObjectContextDidSaveNotification object:managedObjectContext];
        
    // Perform action on target if possible
    if (target && action && [target respondsToSelector:action]) {
        CoreResult *result = error != nil ?
            [[CoreResult alloc] initWithResources:resources] :
            [[CoreResult alloc] initWithError:error];
        [target performSelector:action withObject:result];
        [result release];
    }
}


/**
    When the context saves, send a message to our Core Manager to merge in the updated data
*/
- (void)contextDidSave:(NSNotification*)notification {
    [coreManager performSelectorOnMainThread:@selector(mergeContext:) 
        withObject:notification 
        waitUntilDone:NO];
}



#pragma mark -
#pragma mark Source

- (NSString*) sourceString {
    if (sourceString == nil) {
        sourceString = [[[source isKindOfClass:[NSString class]] ? source : [source get:@selector(responseString)] 
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] retain];
    return sourceString;
}



#pragma mark -
#pragma mark Format determination

- (NSString*) format {
    if (format != nil)
        return format;

    static NSArray* allowedFormats = $A(@"json", @"xml");

    NSString* dFormat = nil;
    
    // Attempt to determine format using response content type
    if (dFormat == nil)
        dFormat = [self formatFromHeader:@"Content-Type" inDictionary:@selector(responseHeaders);
        
    // Attempt to determine format using request accept header
    if (dFormat == nil)
        dFormat = [self formatFromHeader:@"Accept" inDictionary:@selector(requestHeaders);
        
    // Attempt to determine format using URL extension
    if (dFormat == nil) {
        NSURL *url = [source get:@selector(url)];
        if (url != nil)
            dFormat = [self allowedFormatsFromString:[url relativePath]];
    }
    
    // Attempt to determine format by looking at first content character
    if (dFormat == nil) {
        NSString *trimmedSourceString = [[self sourceString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *firstContentChar = [trimmedSourceString
        NSRange firstContentRange = [sourceString rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"{[<"]];
        if (firstContentRange.location != NSNotFound) {
            NSString* firstContentChar = [sourceString substringWithRange:firstContentRange];
            if ([firstContentChar isE
        }
    }
    
    return dFormat;
}

- (NSString*) formatFromHeader:(NSString*)header inDictionary:(SEL)dictionarySelector {
    NSDictionary *headers = [source get:dictionarySelector];
    if (headers != nil) {
        NSString *headerValue = [headers objectForKey:header];
        if (headerValue != nil)
            return [self allowedFormatsFromString:headerValue];
    }
    return nil;
}

- (NSString*) allowedFormatsFromString:(NSString*)string {
    for (NSString* allowedFormat in allowedFormats) {
        if ([string rangeOfString:allowedFormat options:NSCaseInsensitiveSearch].location != NSNotFound)
            return allowedFormat;
    }
    return nil;
}


#pragma mark -
#pragma mark Lifecycle end

- (void) dealloc {
    [source release];
    [sourceString release];
    [format release];
    [coreManager release];
    [target release];
    [super dealloc];
}

@end
