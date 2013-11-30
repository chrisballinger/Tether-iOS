//
//  CBAppDelegate.h
//  Tether
//
//  Created by Christopher Ballinger on 11/30/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SOCKSProxy;

@interface CBAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, strong) SOCKSProxy *socksProxy;

@end
