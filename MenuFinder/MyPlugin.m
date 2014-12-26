//
//  MyPlugin.m
//  MenuFinder
//
//  Created by chuthan20 on 2014-12-25.
//
//

#import "MyPlugin.h"
#import <AppKit/AppKit.h>
#import "PopupWindow.h"


@interface MyPlugin () <NSMenuDelegate>
{
    PopupWindow *_popupWindow;
}

@end

@implementation MyPlugin

+ (void) load
{
    MyPlugin *plugin= [MyPlugin sharedInstance];
    [plugin enableMenu];
}

+ (MyPlugin *) sharedInstance
{
    static MyPlugin* plugin = nil;

    if (plugin == nil)
    {
        plugin = [[MyPlugin alloc] init];
    }

    return plugin;
}

- (void) enableMenu
{
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"ARC Menu Search" action:@selector(searchForMenu:) keyEquivalent:@""];
    [item setTarget:self];
    [item setEnabled:YES];
    [[NSApp mainMenu] setDelegate:self];
    [[[[NSApp mainMenu] itemWithTitle:@"Help"] submenu] addItem:item];
}

- (void) searchForMenu:(id)menu
{
    _popupWindow = [[PopupWindow alloc] init];
    [_popupWindow.window makeKeyAndOrderFront:nil];
}



@end
