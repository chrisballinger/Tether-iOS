//
//  CBRootViewController.m
//  Tether
//
//  Created by Christopher Ballinger on 11/30/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import "CBRootViewController.h"
#import "UIView+AutoLayout.h"
#import "FormatterKit/TTTUnitOfInformationFormatter.h"

@interface CBRootViewController ()
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, strong) TTTUnitOfInformationFormatter *dataFormatter;
@end

@implementation CBRootViewController

- (id)init
{
    self = [super init];
    if (self) {
        self.socksProxy = [[SOCKSProxy alloc] init];
        [_socksProxy startProxyOnPort:8123];
        [self setupDataFormatter];
    }
    return self;
}

- (void) setupDataFormatter {
    self.dataFormatter = [[TTTUnitOfInformationFormatter alloc] init];
}

- (void) refreshTimerDidFire:(NSTimer*)timer {
    NSNumber *bytesRead = @(self.socksProxy.totalBytesRead);
    NSNumber *bytesWritten = @(self.socksProxy.totalBytesWritten);
    self.totalBytesReadLabel.text = [NSString stringWithFormat:@"Bytes read: %@", [self.dataFormatter stringFromNumber:bytesRead ofUnit:TTTByte]];
    self.totalBytesWrittenLabel.text = [NSString stringWithFormat:@"Bytes written: %@", [self.dataFormatter stringFromNumber:bytesWritten ofUnit:TTTByte]];
    self.connectionCountLabel.text = [NSString stringWithFormat:@"Connections: %d", self.socksProxy.connectionCount];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setupBytesReadLabel];
    [self setupBytesWrittenLabel];
    [self setupConnectionCountLabel];
    
	// Do any additional setup after loading the view.
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(refreshTimerDidFire:) userInfo:nil repeats:YES];
    
}

- (void) setupBytesReadLabel {
    self.totalBytesReadLabel = [[UILabel alloc] init];
    [self setupLabel:self.totalBytesReadLabel];
    [self.totalBytesReadLabel autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:20.0f];
}

- (void) setupLabel:(UILabel*)label {
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:label];
    [label autoSetDimensionsToSize:[self labelSize]];
    [label autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:10.0f];
}

- (void) setupBytesWrittenLabel {
    self.totalBytesWrittenLabel = [[UILabel alloc] init];
    [self setupLabel:self.totalBytesWrittenLabel];
    [self.totalBytesWrittenLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.totalBytesReadLabel];
}

- (void) setupConnectionCountLabel {
    self.connectionCountLabel = [[UILabel alloc] init];
    [self setupLabel:self.connectionCountLabel];
    [self.connectionCountLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.totalBytesWrittenLabel];
}

- (CGSize) labelSize {
    return CGSizeMake(200, 30);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
