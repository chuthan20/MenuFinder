//
//  HighlightingViewController.m
//  MenuFinder
//
//  Created by chuthan20 on 2014-12-26.
//
//

#import "HighlightingViewController.h"
#import "HighlightingView.h"

@interface HighlightingViewController ()

@end

@implementation HighlightingViewController

- (void)loadView
{
    HighlightingView *hv = [[HighlightingView alloc] initWithFrame:NSZeroRect];
    self.view = hv;
}

@end
