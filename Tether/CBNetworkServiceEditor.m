//
//  CBNetworkServiceEditor.m
//  Tether
//
//  Created by Christopher Ballinger on 3/31/14.
//  Copyright (c) 2014 Christopher Ballinger. All rights reserved.
//

#import "CBNetworkServiceEditor.h"

static NSString * const kPreferencesFilePath = @"/Library/Preferences/SystemConfiguration/preferences.plist";

@interface CBNetworkServiceEditor()
@property (nonatomic, strong) NSDictionary *preferencesDictionary;
@end

@implementation CBNetworkServiceEditor

- (id) init {
    if (self = [super init]) {
        
    }
    return self;
}



@end
