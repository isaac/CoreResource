//
//  CoreResourceTestCase.h
//  CoreTest
//
//  Created by Mike Laurence on 1/19/10.
//  Copyright 2010 Punkbot LLC. All rights reserved.
//

#import "GHUnit.h"
#import "Artist.h"
#import "CoreResult.h"

@interface CoreResourceTestCase : GHAsyncTestCase {
    NSMutableDictionary* delegatesCalled;
}

@property (nonatomic, retain) NSMutableDictionary* delegatesCalled;

- (NSArray*) allLocalArtists;
- (void) validateFirstArtist:(Artist*)artist;

@end