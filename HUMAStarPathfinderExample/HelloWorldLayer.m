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
	if( (self = [super init]) ) {
		self.touchEnabled = YES;
		self.touchMode = kCCTouchesOneByOne;
		
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

- (BOOL)ccTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event {
	return YES;
}

- (void)ccTouchEnded:(UITouch *)touch withEvent:(UIEvent *)event {
	CGPoint location = [self convertTouchToNodeSpace:touch];
	
	NSArray *path = [self.pathfinder findPathFromStart:self.player.position
												toTarget:location];
	
	NSMutableArray *actions = [NSMutableArray array];

	for (NSValue *pointValueInPath in path) {
		CGPoint point = pointValueInPath.CGPointValue;
		
		CCMoveTo *moveTo = [CCMoveTo actionWithDuration:0.5f position:point];
		[actions addObject:moveTo];
	}
	
	CCSequence *sequence = [CCSequence actionWithArray:actions];
	[self.player runAction:sequence];
}

#pragma mark - HUMAStarPathfinderDelegate
- (BOOL)pathfinder:(HUMAStarPathfinder *)pathFinder canWalkToNodeAtTileLocation:(CGPoint)tileLocation {
	CCTMXLayer *meta = [self.tileMap layerNamed:@"Meta"];
	uint8_t gid = [meta tileGIDAt:tileLocation];

	if (gid) {
		NSDictionary *properties = [self.tileMap propertiesForGID:gid];
		BOOL walkable = [properties[@"walkable"] boolValue];
		
		return walkable;
	}
	
	return YES;
}


@end
