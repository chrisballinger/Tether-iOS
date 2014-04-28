//
//  CBRootViewController.h
//  Tether
//
//  Created by Christopher Ballinger on 11/30/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SOCKSProxy.h"

@interface CBRootViewController : UIViewController

@property (nonatomic, strong) UILabel *connectionCountLabel;
@property (nonatomic, strong) UILabel *totalBytesWrittenLabel;
@property (nonatomic, strong) UILabel *totalBytesReadLabel;
@property (nonatomic, strong) SOCKSProxy *socksProxy;


@end
