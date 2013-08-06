//
//  HelloWorldLayer.m
//  HUMAStarPathfinderExample
//
//  Created by Colin Humber on 8/5/13.
//  Copyright Colin Humber 2013. All rights reserved.
//


// Import the interfaces
#import "HelloWorldLayer.h"

// Needed to obtain the Navigation Controller
#import "AppDelegate.h"

#import "HUMAStarPathfinder.h"

@interface HelloWorldLayer () <HUMAStarPathfinderDelegate>
@property (nonatomic, strong) CCTMXTiledMap *tileMap;
@property (nonatomic, strong) CCSprite *player;
@property (nonatomic, strong) HUMAStarPathfinder *pathfinder;
@end

#pragma mark - HelloWorldLayer

// HelloWorldLayer implementation
@implementation HelloWorldLayer

// Helper class method that creates a Scene with the HelloWorldLayer as the only child.
+(CCScene *) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	HelloWorldLayer *layer = [HelloWorldLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

// on "init" you need to initialize your instance
-(id) init
{
	// always call "super" init
	// Apple recommends to re-assign "self" with the "super's" return value
	if( (self=[super init]) ) {
		self.tileMap = [[CCTMXTiledMap alloc] initWithTMXFile:@"desert.tmx"];
		[self addChild:self.tileMap];
		
		CCTMXObjectGroup *objectGroup = [self.tileMap objectGroupNamed:@"Objects"];
		NSDictionary *spawnPoint = [objectGroup objectNamed:@"spawnPoint"];
		
		self.player = [[CCSprite alloc] initWithFile:@"Icon.png"];
		self.player.scale = 32.0f/57.0f;
		self.player.position = CGPointMake([spawnPoint[@"x"] integerValue], [spawnPoint[@"y"] integerValue]);
		[self addChild:self.player];

		self.pathfinder = [HUMAStarPathfinder pathfinderWithTileMapSize:self.tileMap.mapSize
															   tileSize:self.tileMap.tileSize
															   delegate:self];
	}
	return self;
}

@end
