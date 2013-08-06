//
//  HUMAStarPathfinderNode.m
//  HUMAStarPathfinder
//
//  Created by Colin Humber on 7/29/13.
//  Copyright (c) 2013 Colin Humber. All rights reserved.
//

#import "HUMAStarPathfinderNode.h"

@implementation HUMAStarPathfinderNode

+ (instancetype)nodeWithLocation:(CGPoint)location {
	return [[HUMAStarPathfinderNode alloc] initWithLocation:location];
}

- (id)initWithLocation:(CGPoint)location {
	self = [super init];
	if (self) {
		_tileLocation = location;
		_hValue = 0.0f;
		_gCost = 0.0f;
	}
	
	return self;
}

- (CGFloat)fValue {
	return self.hValue + self.gCost;
}

- (BOOL)isEqual:(HUMAStarPathfinderNode *)object {
	return CGPointEqualToPoint(self.tileLocation, object.tileLocation);
}

- (NSString *)description {
	return [NSString stringWithFormat:@"[H: %.2f | G: %.2f | F: %.2f | Location: %.0f, %.0f]", self.hValue, self.gCost, self.fValue, self.tileLocation.x, self.tileLocation.y];
}

@end
