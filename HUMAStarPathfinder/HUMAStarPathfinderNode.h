//
//  HUMAStarPathfinderNode.h
//  HUMAStarPathfinder
//
//  Created by Colin Humber on 7/29/13.
//  Copyright (c) 2013 Colin Humber. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HUMAStarPathfinderNode : NSObject

@property (nonatomic, strong) HUMAStarPathfinderNode *parentNode;

@property (nonatomic, assign) CGFloat hValue;
@property (nonatomic, assign) CGFloat gCost;
@property (nonatomic, readonly) CGFloat fValue;
@property (nonatomic, assign) CGPoint tileLocation;

+ (instancetype)nodeWithLocation:(CGPoint)location;
- (id)initWithLocation:(CGPoint)location;

@end
