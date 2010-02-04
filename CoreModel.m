//
//  CoreModel.m
//  CoreResource
//
//  Created by Mike Laurence on 12/24/09.
//  Copyright Mike Laurence 2010. All rights reserved.
//

#import "CoreModel.h"
#import "CoreUtils.h"
#import "CoreRequest.h"
#import "CoreResult.h"
#import "JSON.h"
#import "NSString+InflectionSupport.h"

@implementation CoreModel

#pragma mark -
#pragma mark Configuration

+ (CoreManager*) coreManager {
    return [CoreManager main];
}

+ (BOOL) useBundleRequests {
    return [[self coreManager] useBundleRequests];
}

+ (NSString*) remoteSiteURL {
    return [[self coreManager] remoteSiteURL];
}

+ (NSString*) remoteCollectionName {
    return [[[NSStringFromClass(self) deCamelizeWith:@"_"] substringFromIndex:1] stringByAppendingString:@"s"];
}

+ (NSString*) remoteURLForCollectionAction:(Action)action {
    return [NSString stringWithFormat:@"%@/%@", [self remoteSiteURL], [self remoteCollectionName]];
}

+ (NSString*) remoteURLForResource:(id)resourceId action:(Action)action {
    return [NSString stringWithFormat:@"%@/%@/%@", [[self class] remoteSiteURL], [[self class] remoteCollectionName], resourceId]; 
}

- (NSString*) remoteURLForAction:(Action)action {
    return [[self class] remoteURLForResource:[self localId] action:action];
}

+ (NSString*) bundlePathForCollectionAction:(Action)action {
    return [NSString stringWithFormat:@"%@", [self remoteCollectionName]];
}

+ (NSString*) bundlePathForResource:(id)resourceId action:(Action)action {
    return [NSString stringWithFormat:@"%@.%@", [[self class] remoteCollectionName], resourceId];
}

- (NSString*) bundlePathForAction:(Action)action {
    return [[self class] bundlePathForResource:[self localId] action:action];
}



#pragma mark -
#pragma mark Serialization

+ (NSString*) localNameForRemoteField:(NSString*)name {
    return name;
}

+ (NSString*) remoteNameForLocalField:(NSString*)name {
    return name;
}

+ (NSString*) localIdField {
    return @"resourceId";
}

- (id) localId {
    return [self performSelector:NSSelectorFromString([[self class] localIdField])];
}

+ (NSString*) remoteIdField {
    return @"id";
}

+ (NSDateFormatter*) dateParser {
    return [[self coreManager] defaultDateParser];
}

+ (NSDateFormatter*) dateParserForField:(NSString*)field {
    return [self dateParser];
}

+ (NSArray*) deserializeFromString:(NSString*)serializedString {
    //NSLog(@"Serialized data: %@", serializedString);
    id deserialized = [serializedString JSONValue];
    if (deserialized != nil) {
        // Turn into array if not already one
        if ([deserialized isKindOfClass:[NSDictionary class]])
            deserialized = [NSArray arrayWithObject:deserialized];

        NSArray* data = [self dataCollectionFromDeserializedCollection:deserialized];
        if (data != nil) {
            NSLog(@"Deserializing %@ %@", [NSNumber numberWithInt:[deserialized count]], [self remoteCollectionName]);
            NSMutableArray *objs = [NSMutableArray arrayWithCapacity:[(NSArray*)data count]];
            for (NSMutableDictionary *dict in (NSArray*)deserialized) {
                id obj = [self createOrUpdateWithDictionary:dict];
                if (obj != nil)
                    [objs addObject:obj];
            }
            return objs;
        }
    }
    return nil;
}

/**
    Retrieves the actual data collection from the initial deserialized collection.
    This should be used, for example. if your response has its data objects nested, e.g.:
    
    { results: [{ name: 'Mike' }, { name: 'Mork' }] }
    
    It could also just be used to fine-tune the deserialized data before it's converted to model objects.
    
    Defaults to just returning the initial collection, which would work if you have no nested-ness, e.g.:
    
    [{ name: 'Mike' }, { name: 'Mork' }]
*/
+ (NSArray*) dataCollectionFromDeserializedCollection:(id)deserializedCollection {
    return deserializedCollection;
}



#pragma mark -
#pragma mark Core Data

+ (NSManagedObjectContext*) managedObjectContext {
    return [[self coreManager] managedObjectContext];
}

+ (NSString*) entityName {
    return [NSString stringWithFormat:@"%@", self];
}

+ (NSEntityDescription*) entityDescription {
    return [NSEntityDescription entityForName:[self entityName] inManagedObjectContext:[[self coreManager] managedObjectContext]];
}

+ (NSDictionary*) relationshipsByName {
    NSDictionary* rels = [[[CoreManager main] modelRelationships] objectForKey:self];
    if (rels == nil) {
        // Cache relationships dictionary if not yet extant
        rels = [[self entityDescription] relationshipsByName];
        [[[CoreManager main] modelRelationships] setObject:rels forKey:self];
    }
    return rels;
}

+ (BOOL) hasRelationships {
    return [[self relationshipsByName] count] > 0;
}

+ (NSDictionary*) propertiesByName {
    NSDictionary* props = [[[CoreManager main] modelProperties] objectForKey:self];
    if (props == nil) {
        // Cache properties dictionary if not yet extant
        props = [[self entityDescription] propertiesByName];
        [[[CoreManager main] modelProperties] setObject:props forKey:self];
    }
    return props;
}

/**
    Returns the property description for a given property in a given model.
    By default, this caches the resulting dictionaries provided by Core Data
    in order to maximize efficiency (caching performed in #propertiesByName).
*/
+ (NSPropertyDescription*) propertyDescriptionForField:(NSString*)field inModel:(Class)modelClass {
    return [[modelClass propertiesByName] objectForKey:field];
}

+ (NSPropertyDescription*) propertyDescriptionForField:(NSString*)field {
    return [self propertyDescriptionForField:field inModel:self];
}


#pragma mark -
#pragma mark Create

+ (id) create:(id)parameters {
	return [self createWithDictionary:parameters];
}

+ (id) createWithDictionary:(NSDictionary*)dict {
    CoreModel *newObject = [[self alloc] initWithEntity:[self entityDescription] 
        insertIntoManagedObjectContext:[[self coreManager] managedObjectContext]];
    [newObject updateWithDictionary:dict];
    NSLog(@"Created new %@ with id %@", self, [newObject valueForKey:[self localIdField]]);
    return newObject;
}

+ (id) createOrUpdateWithDictionary:(NSDictionary*)dict {
    
    // Get remote ID
    id resourceId = [dict objectForKey:[self remoteIdField]];
    
    // If there is an ID, attempt to find existing record by using ById fetch template
    if (resourceId != nil) {
        NSFetchRequest* fetch = [[[self coreManager] managedObjectModel] 
            fetchRequestFromTemplateWithName:[NSString stringWithFormat:@"%@ById", self] 
            substitutionVariables:[NSDictionary dictionaryWithObject:resourceId forKey:@"id"]
        ];
        if (fetch == nil) {
            fetch = [self fetchRequestWithSort:nil andPredicate:
                [NSPredicate predicateWithFormat:[NSString stringWithFormat:@"%@ = %@", [self localIdField], resourceId]]];
        }
        [fetch setFetchLimit:1];

        NSError* fetchError = nil;
        NSMutableArray* fetchResults = [[[[self coreManager] managedObjectContext] executeFetchRequest:fetch error:&fetchError] mutableCopy];

        if (fetchError == nil) {
            // If there is a result, check to see whether we should update it or not
            if ([fetchResults count] > 0) {
                CoreModel *existingObject = [fetchResults objectAtIndex:0];
                [existingObject updateWithDictionary:dict];
                return existingObject;
            }
        }
        else {
            NSLog(@"Error in fetching with dictionary %@ for update comparison: %@", dict, [fetchError localizedDescription]);
        }
    }
    
    // Otherwise, no existing record found, so create a new object
    return [self createWithDictionary:dict];
}

+ (id) createOrUpdateWithDictionary:(NSDictionary*)dict andRelationship:(NSRelationshipDescription*)relationship toObject:(CoreModel*)object {
    id otherObject = [self createOrUpdateWithDictionary:dict];
    if (otherObject)
        [otherObject setValue:object forKey:[relationship name]];
    return otherObject;
}


/**
    Determines whether or not an existing (local) record should be updated with data from the provided dictionary
    (presumably retrieved from a remote source.) The most likely determinant would be if the new data is newer
    than the object.
*/
- (BOOL) shouldUpdateWithDictionary:(NSDictionary*)dict { 
    if ([self respondsToSelector:@selector(updated_at)]) {
        NSDate *updatedAt = (NSDate*)[self performSelector:@selector(updated_at)];
        if (updatedAt != nil) {
            return [updatedAt compare:
                [[[self class] dateParserForField:@"updated_at"] dateFromString:[dict objectForKey:@"updated_at"]]] == NSOrderedAscending;
        }
    }
    return YES;
}

- (void) updateWithDictionary:(NSDictionary*)dict {

    // Determine whether this object needs to be updated (relationships will still be checked no matter what)
    BOOL shouldUpdateRoot = [self shouldUpdateWithDictionary:dict];
    if (shouldUpdateRoot)
        NSLog(@"Updating %@ with id %@", [self class], [self valueForKey:[[self class] localIdField]]);
    else {
        NSLog(@"Skipping update of %@ with id %@ because it is already up-to-date", [self class], [self valueForKey:[[self class] localIdField]]);
        // If we won't be updating the root object and there are no relationships, cancel out for efficiency's sake
        if (![[self class] hasRelationships])
            return;
    }

    // Mutable-ize dictionary if necessary
    if (![dict isKindOfClass:[NSMutableDictionary class]])
        dict = [dict mutableCopy];

    // Change remote ID field to local ID field
    id remoteIdValue = [dict objectForKey:[[self class] remoteIdField]];
    if (remoteIdValue != nil) {
        [(NSMutableDictionary*)dict removeObjectForKey:[[self class] remoteIdField]];
        [(NSMutableDictionary*)dict setObject:remoteIdValue forKey:[[self class] localIdField]];
    }

    // Loop through and apply fields in dictionary (if they exist on the object)
    for (NSString* field in [dict allKeys]) {
    
        // Get local field name (by default, this is the same as the remote name)
        NSString* localField = [[self class] localNameForRemoteField:field];
        
        NSPropertyDescription *propertyDescription = [[self class] propertyDescriptionForField:localField inModel:[self class]];
        //NSLog(@"Property description for %@.%@ is %@", [self class], field, propertyDescription);
        
        if (propertyDescription != nil) {
            id value = [dict objectForKey:field];
            
            // If property is a relationship, do some cascading object creation/updation (occurs regardless of shouldUpdateRoot)
            if ([propertyDescription isKindOfClass:[NSRelationshipDescription class]]) {
                Class relationshipClass = NSClassFromString([[(NSRelationshipDescription*)propertyDescription destinationEntity] managedObjectClassName]);
                NSRelationshipDescription* inverseRelationship = [(NSRelationshipDescription*)propertyDescription inverseRelationship];
                
                // Create/update relationship items and assign this object to their inverse relationship (to link them)
                if ([value isKindOfClass:[NSArray class]]) {
                    for (NSDictionary *dict in value)
                        [relationshipClass createOrUpdateWithDictionary:dict andRelationship:inverseRelationship toObject:self];
                }
                else if ([value isKindOfClass:[NSDictionary class]])
                    [relationshipClass createOrUpdateWithDictionary:value andRelationship:inverseRelationship toObject:self];
            }
            
            // If it's an attribute, just assign the value to the object (unless the object is up-to-date)
            else if ([propertyDescription isKindOfClass:[NSAttributeDescription class]] && shouldUpdateRoot) {                
                //NSLog(@"Setting property: %@ %@", field, value);
                // Check if value is NSNull, which should be set as nil on fields (since NSNull is just used as a collection placeholder)
                if ([value isEqual:[NSNull null]])
                    [self setValue:nil forKey:localField];

                else {
                    // Perform additional processing on value based on attribute type
                    switch ([(NSAttributeDescription*)propertyDescription attributeType]) {
                        case NSDateAttributeType:
                            value = [[[self class] dateParserForField:localField] dateFromString:value];
                            break;
                    }
                    [self setValue:value forKey:localField];
                }
            }
        }
    }
}



#pragma mark -
#pragma mark Read

+ (CoreResult*) find:(id)resourceId {
    return [self find:resourceId andNotify:nil withSelector:nil];
}

+ (CoreResult*) find:(id)resourceId andNotify:(id)del withSelector:(SEL)selector {
    CoreResult* localResult = [self findLocal:resourceId];
    if ([localResult hasAnyResources])
        return localResult;
    [self findRemote:resourceId andNotify:del withSelector:selector];
    return [[CoreResult alloc] init];
}

+ (CoreResult*) findAll {
    return [self findAll:nil andNotify:nil withSelector:nil];
}

+ (CoreResult*) findAll:(id)parameters {
    return [self findAll:parameters andNotify:nil withSelector:nil];
}

+ (CoreResult*) findAll:(id)parameters andNotify:(id)del withSelector:(SEL)selector {
    CoreResult* localResult = [self findAllLocal];
    [self findAllRemote:parameters andNotify:del withSelector:selector];
    return localResult;
}

+ (CoreResult*) findLocal:(id)resourceId {
    return [self findAllLocal:[NSString stringWithFormat:@"%@ = %@", [self localIdField], resourceId]];
}

+ (CoreResult*) findAllLocal {
    return [self findAllLocal:nil];
}

+ (CoreResult*) findAllLocal:(id)parameters {
    NSError* error = nil;
    NSFetchRequest* fetch = [self fetchRequestWithSort:nil andPredicate:[self predicateWithParameters:parameters]];
    NSArray* resources = [[self managedObjectContext] executeFetchRequest:fetch error:&error];

    CoreResult* result = [[CoreResult alloc] initWithResources:resources];
    if (error != nil)
        result.error = error;
    return result;
}

+ (void) findRemote:(id)resourceId {
    [self findRemote:resourceId andNotify:nil withSelector:nil];
}

+ (void) findRemote:(id)resourceId andNotify:(id)del withSelector:(SEL)selector {
    CoreRequest *request = [[CoreRequest alloc] initWithURL:
        [CoreUtils URLWithSite:[self remoteURLForResource:resourceId action:Read] andFormat:@"json" andParameters:nil]];
    request.delegate = self;
    request.didFinishSelector = @selector(findRemoteDidFinish:);
    request.didFailSelector = @selector(findRemoteDidFail:);
    request.coreDelegate = del;
    request.coreSelector = selector;

    // If we're using bundle requests, just attempt to find the data within the project
    if ([self useBundleRequests]) {
        request.bundleDataPath = [self bundlePathForResource:resourceId action:Read];
        [request executeAsBundleRequest];
    }
    
    // Enqueue as remote HTTP request 
    else
        [[self coreManager] enqueueRequest:request];
}

+ (void) findAllRemote {
    [self findAllRemote:nil];
}

+ (void) findAllRemote:(id)parameters {
    [self findAllRemote:parameters andNotify:nil withSelector:nil];
}

+ (void) findAllRemote:(id)parameters andNotify:(id)del withSelector:(SEL)selector {
    CoreRequest *request = [[CoreRequest alloc] initWithURL:
        [CoreUtils URLWithSite:[self remoteURLForCollectionAction:Read] andFormat:@"json" andParameters:parameters]];
    request.delegate = self;
    request.didFinishSelector = @selector(findRemoteDidFinish:);
    request.didFailSelector = @selector(findRemoteDidFail:);
    request.coreDelegate = del;
    request.coreSelector = selector;

    // If we're using bundle requests, just attempt to find the data within the project
    if ([self useBundleRequests]) {
        request.bundleDataPath = [self bundlePathForCollectionAction:Read];
        [request executeAsBundleRequest];
    }
    
    // Enqueue as remote HTTP request 
    else
        [[self coreManager] enqueueRequest:request];
}

+ (void) findRemoteDidFinish:(CoreRequest*)request {
    NSArray* resources = [self deserializeFromString:[request responseString]];
    //[[self coreManager] save]; // TO-DO: Optional save after request?
    
    // Notify core delegate of request (if any)
    if (request.coreDelegate && request.coreSelector && [request.coreDelegate respondsToSelector:request.coreSelector]) {
        CoreResult* result = [[CoreResult alloc] init];
        result.resources = resources;
        [request.coreDelegate performSelector:request.coreSelector withObject:result];
    }
}

+ (void) findRemoteDidFail:(CoreRequest*)request {
    NSLog(@"[%@#findRemoteDidFail] Find remote request failed: %@", self, [[request error] localizedDescription]);
}


#pragma mark -
#pragma mark Delete

+ (void) destroyAllLocal {
    for (CoreModel* model in [[[self class] findAllLocal] resources])
        [[self managedObjectContext] deleteObject:model];
}



#pragma mark -
#pragma mark Results Management

+ (NSFetchRequest*) fetchRequest {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[self entityDescription]];
    return fetchRequest;
}

+ (NSFetchRequest*) fetchRequestWithDefaultSort {
    NSFetchRequest *fetchRequest = [self fetchRequest];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:
        [[NSSortDescriptor alloc] initWithKey:[self localIdField] ascending:YES]]];
    return fetchRequest;
}

+ (NSFetchRequest*) fetchRequestWithSort:(NSString*)sorting andPredicate:(NSPredicate*)predicate {
    NSFetchRequest *fetchRequest = [self fetchRequest];
    [fetchRequest setSortDescriptors:[CoreUtils sortDescriptorsFromString:sorting]];
    [fetchRequest setPredicate:predicate];
    return fetchRequest;
}

+ (NSPredicate*) predicateWithParameters:(id)parameters {
    // If parameters are a string, just reuse it in the predicate
    if ([parameters isKindOfClass:[NSString class]])
        return [NSPredicate predicateWithFormat:parameters];

    return nil;
}

+ (CoreResultsController*) coreResultsControllerWithSort:(NSString*)sorting andSectionKey:(NSString*)sectionKey {
    NSFetchRequest *fetchRequest = [self fetchRequestWithSort:sorting andPredicate:nil];
    return [self coreResultsControllerWithRequest:fetchRequest andSectionKey:sectionKey];
}

+ (CoreResultsController*) coreResultsControllerWithRequest:(NSFetchRequest*)fetchRequest andSectionKey:(NSString*)sectionKey {
    CoreResultsController* coreResultsController = [[[CoreResultsController alloc] initWithFetchRequest:fetchRequest 
        managedObjectContext:[[self coreManager] managedObjectContext] 
        sectionNameKeyPath:sectionKey 
        cacheName:@"Root"] autorelease];
    coreResultsController.entityClass = self;
    return coreResultsController;
}

@end

