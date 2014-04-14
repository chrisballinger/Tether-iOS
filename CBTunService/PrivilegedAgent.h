//
//  PrivilegedActions.h
//  SMJobBless
//
//  Created by Ludovic Delaveau on 8/5/12.
//
//

#import <Foundation/Foundation.h>
#import "Actions.h"

@interface PrivilegedAgent : NSObject <TunHandler>

@property (nonatomic, strong) NSFileHandle *tunHandle;

@end
