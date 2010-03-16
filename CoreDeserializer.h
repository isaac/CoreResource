//
//  CoreDeserializer.h
//  Core Resource
//
//  Created by Mike Laurence on 3/11/10.
//  Copyright 2010 Mike Laurence.
//

#import <Foundation/Foundation.h>
#import "CoreManager.h"

/**
    The job of CoreDeserializers is to transform serialized resource strings into 
    CoreResource-formatted collections (nested arrays & dictionaries). They do pass
    actual resources to their targets at the time of completion, but the generation
    of said resources is handed off to individual CoreResource classes, where
    customized domain logic is better placed. This also allows for direct creates
    and updates using property dictionaries and such, much like in ActiveRecord
    where you can call #update_attributes with a hash.
*/
@interface CoreDeserializer : NSOperation {
    id source;
    NSString *sourceString;
    Class resourceClass;
    NSString *format;
    CoreManager *coreManager;
    NSManagedObjectContext *managedObjectContext;
    
    // Results
    NSError *error;
    id resources;
    
    // Target
    id target;
    SEL action;
}

@property (nonatomic, retain) id source;
@property (nonatomic, assign) Class resourceClass;
@property (nonatomic, retain) NSString* format;
@property (nonatomic, retain) CoreManager *coreManager;

@property (nonatomic, retain) id target;
@property (nonatomic, assign) SEL action;

- (id) initWithSource:(id)source andResourceClass:(Class)clazz;

#pragma mark -
#pragma mark Source
- (NSString*) sourceString;

#pragma mark -
#pragma mark Format determination
- (NSString*) formatFromHeader:(NSString*)header inDictionary:(SEL)dictionarySelector;
- (NSString*) allowedFormatsFromString:(NSString*)string;

#pragma mark -
#pragma mark Deserialization
- (NSArray*) resourcesFromString:(NSString*)string;

@end


@interface CoreJSONDeserializer : CoreDeserializer @end
@interface CoreXMLDeserializer : CoreDeserializer @end