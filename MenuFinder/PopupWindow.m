//
//  PopupWindow.m
//  MenuFinder
//
//  Created by chuthan20 on 2014-12-26.
//
//

#import "PopupWindow.h"
#import "SuggestionsWindowController.h"
#import "MyPlugin.h"
#import "SuggestibleTextFieldCell.h"
#import "RoundedCornersView.h"

@interface PopupWindow () <NSTextFieldDelegate, NSMenuDelegate>
{
    NSTextField *textfield;
    SuggestionsWindowController *_suggestionsController;
    NSArray *_allMenuItems;
}
@end

#define CONTENT_WIDTH 200
#define CONTENT_HEIGHT 60

#define DEBUG_LOG 1

@implementation PopupWindow
- (instancetype)init
{
    self = [super initWithWindow:[self setupWindow]];
    if (self)
    {
        [textfield becomeFirstResponder];
    }
    return self;
}

- (NSWindow *) setupWindow
{
    NSRect f = [[[NSApplication sharedApplication] keyWindow] frame];
    NSRect contentRect = NSMakeRect(NSMidX(f) - CONTENT_WIDTH/2.f, NSMidY(f) - CONTENT_HEIGHT/2.f, CONTENT_WIDTH, CONTENT_HEIGHT );
    NSWindow *searchBarWindow = [[CustomWindow alloc]
                                 initWithContentRect:contentRect
                                 styleMask:NSBorderlessWindowMask|NSResizableWindowMask
                                 backing:NSBackingStoreBuffered
                                 defer:YES];
    [searchBarWindow setHasShadow:YES];
    [searchBarWindow setOpaque:NO];
    [searchBarWindow setOrderedIndex:1];
    [searchBarWindow setBackgroundColor:[NSColor clearColor]];
    [searchBarWindow setMaxSize:NSMakeSize(600, CONTENT_HEIGHT)];


    RoundedCornersView *contentView = [[RoundedCornersView alloc] initWithFrame:contentRect];
    [contentView setRcvCornerRadius:5];
    [contentView addSubview:[self setupView]];

    [searchBarWindow setContentView:contentView];
    return searchBarWindow;
}

- (NSView *) setupView
{
    [NSTextField setCellClass:[SuggestibleTextFieldCell class]];

    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, CONTENT_WIDTH, CONTENT_HEIGHT)];
    textfield = [[NSTextField alloc] init];
    [textfield setTranslatesAutoresizingMaskIntoConstraints:NO];
    [textfield setDelegate:self];
    [textfield setFont:[NSFont systemFontOfSize:24]];
    [textfield setBordered:NO];
    [textfield setBezeled:NO];
    [textfield setBackgroundColor:[NSColor clearColor]];
    [textfield sizeToFit];
    [textfield setFocusRingType:NSFocusRingTypeNone];

    [view addSubview:textfield];
    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-10-[textfield]-10-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(textfield)]];
    [view addConstraint:[NSLayoutConstraint constraintWithItem:textfield attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];

    return view;
}

- (void) enableMenu
{
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Menu Search" action:@selector(searchForMenu:) keyEquivalent:@"M"];
    [item setKeyEquivalentModifierMask:NSCommandKeyMask|NSAlternateKeyMask];
    [item setTarget:self];
    [item setEnabled:YES];
    [[NSApp mainMenu] setDelegate:self];
    [[[[NSApp mainMenu] itemWithTitle:@"Help"] submenu] addItem:item];
}

- (void) searchForMenu:(id)menu
{
    if (DEBUG_LOG) NSLog(@"%@", NSStringFromSelector(_cmd));
    if (DEBUG_LOG) NSLog(@"%@", menu);
    [[self window] makeKeyAndOrderFront:nil];
}

- (void)controlTextDidBeginEditing:(NSNotification *)notification {
    // We keep the suggestionsController around, but lazely allocate it the first time it is needed.
    if (DEBUG_LOG) NSLog(@"%@", NSStringFromSelector(_cmd));
    if (!_suggestionsController)
    {
        _suggestionsController = [[SuggestionsWindowController alloc] init];
        _suggestionsController.target = self;
        _suggestionsController.action = @selector(updateWithSelectedSuggestion:);
    }
    _allMenuItems = [self allMenuItems];
    [self updateSuggestionsFromControl:notification.object];
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    /* If the suggestionController is already in a cancelled state, this call does nothing and is therefore always safe to call.
     */
    [_suggestionsController cancelSuggestions];
}

/* As the delegate for the NSTextField, this class is given a chance to respond to the key binding commands interpreted by the input manager when the field editor calls -interpretKeyEvents:. This is where we forward some of the keyboard commands to the suggestion window to facilitate keyboard navigation. Also, this is where we can determine when the user deletes and where we can prevent AppKit's auto completion.
 */
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (DEBUG_LOG) NSLog(@"%@ --> %@", NSStringFromSelector(_cmd), NSStringFromSelector(commandSelector));

    if (commandSelector == @selector(cancelOperation:))
    {
        [self.window close];
        return YES;
    }

    if (commandSelector == @selector(moveUp:)) {
        // Move up in the suggested selections list
        [_suggestionsController moveUp:textView];
        return YES;
    }

    if (commandSelector == @selector(moveDown:)) {
        // Move down in the suggested selections list
        [_suggestionsController moveDown:textView];
        return YES;
    }

    if (commandSelector == @selector(deleteForward:) || commandSelector == @selector(deleteBackward:)) {
        /* The user is deleting the highlighted portion of the suggestion or more. Return NO so that the field editor performs the deletion. The field editor will then call -controlTextDidChange:. We don't want to provide a new set of suggestions as that will put back the characters the user just deleted. Instead, set skipNextSuggestion to YES which will cause -controlTextDidChange: to cancel the suggestions window. (see -controlTextDidChange: above)
         */
        //        self.skipNextSuggestion = YES;
        return NO;
    }

    if (commandSelector == @selector(insertNewline:))
    {
        [self userPickedItem:_suggestionsController.selectedSuggestion];
        return YES;
    }

    if (commandSelector == @selector(complete:)) {
        // The user has pressed the key combination for auto completion. AppKit has a built in auto completion. By overriding this command we prevent AppKit's auto completion and can respond to the user's intention by showing or cancelling our custom suggestions window.
        if ([_suggestionsController.window isVisible])
        {
            [_suggestionsController cancelSuggestions];
        }
        else
        {
            [self updateSuggestionsFromControl:control];
        }

        return YES;
    }

    // This is a command that we don't specifically handle, let the field editor do the appropriate thing.
    return NO;
}

- (void)controlTextDidChange:(NSNotification *)notification {
    if (DEBUG_LOG) NSLog(@"%@", NSStringFromSelector(_cmd));

    NSTextField *sender = notification.object;
    NSArray *suggestions = [self suggestionsForText:sender.stringValue];

    if (suggestions.count > 0)
    {
        [_suggestionsController setSuggestions:suggestions];
        if (![_suggestionsController.window isVisible]) {
            [_suggestionsController beginForTextField:sender];
        }
    }
    else
    {
        [_suggestionsController cancelSuggestions];
    }

}

- (void)updateFieldEditor:(NSText *)fieldEditor withSuggestion:(NSString *)suggestion {
    if (DEBUG_LOG) NSLog(@"%@", NSStringFromSelector(_cmd));

    NSRange selection = NSMakeRange([fieldEditor selectedRange].location, [suggestion length]);
    [fieldEditor setString:suggestion];
    [fieldEditor setSelectedRange:selection];
}


- (void)userPickedItem:(NSDictionary *)entry
{
    if (entry)
    {
        [self performMenu:entry[kSuggestionDetailedLabel] title:entry[kSuggestionLabel]];
        [self close];
    }
}

- (IBAction)updateWithSelectedSuggestion:(id)sender {
    NSDictionary *entry = [sender selectedSuggestion];
   if (DEBUG_LOG)  NSLog(@"%@ %@", NSStringFromSelector(_cmd), entry);
    if (entry) {
        NSText *fieldEditor = [[self window] fieldEditor:NO forObject:textfield];
        if (fieldEditor) {
            [self updateFieldEditor:fieldEditor withSuggestion:[entry objectForKey:kSuggestionLabel]];

            //            _suggestedURL = [entry objectForKey:kSuggestionImageURL];
        }
    }
}
- (void)updateSuggestionsFromControl:(NSControl *)control {
    if (DEBUG_LOG) NSLog(@"%@", NSStringFromSelector(_cmd));

    NSText *fieldEditor = [[self window] fieldEditor:NO forObject:control];
    if (fieldEditor) {
        // Only use the text up to the caret position
        NSRange selection = [fieldEditor selectedRange];
        NSString *text = [[fieldEditor string] substringToIndex:selection.location];

        NSArray *suggestions = [self suggestionsForText:text];
        if ([suggestions count] > 0) {
            // We have at least 1 suggestion. Update the field editor to the first suggestion and show the suggestions window.
            NSDictionary *suggestion = [suggestions objectAtIndex:0];
            //            _suggestedURL = [suggestion objectForKey:kSuggestionImageURL];
            [self updateFieldEditor:fieldEditor withSuggestion:[suggestion objectForKey:kSuggestionLabel]];

            [_suggestionsController setSuggestions:suggestions];
            if (![_suggestionsController.window isVisible]) {
                [_suggestionsController beginForTextField:(NSTextField*)control];
            }
        } else {
            // No suggestions. Cancel the suggestion window and set the _suggestedURL to nil.
            //            _suggestedURL = nil;
            [_suggestionsController cancelSuggestions];
        }
    }
}


- (NSArray *) suggestionsForText:(NSString *)text
{
    NSMutableArray *arr = [[NSMutableArray alloc] init];

    for (NSArray *a in _allMenuItems)
    {
        for (NSDictionary *d in a)
        {
            //            NSLog(@"%@", d[@"title"]);
            //            NSLog(@"%@\r", d[@"path"]);
            //


            NSString *title = d[@"title"]?:@"";
            NSString *path = d[@"path"]?:@"";
            if ([title rangeOfString:text options:NSCaseInsensitiveSearch].length > 0 || [path rangeOfString:text options:NSCaseInsensitiveSearch].length > 0)
            {
                NSDictionary *dict = @{
                                       kSuggestionLabel: title,
                                       kSuggestionDetailedLabel:path,
                                       kSuggestionImageURL:@"file",
                                       };

                [arr addObject:dict];
            }
        }

    }


    return arr;
}

- (void) performMenu:(NSString *)path title:(NSString *)title
{
    NSArray *paths = [path componentsSeparatedByString:@" > "];

    NSMenu *m = [NSApp mainMenu];
    NSMenuItem *item = nil;
    for (NSString *p in paths)
    {
        item = [m itemWithTitle:p];
        if (item.hasSubmenu)
        {
            m = item.submenu;
        }
    }

    item = [m itemWithTitle:title];
    [m performActionForItemAtIndex:[m indexOfItem:item]];

     NSLog(@"%@ | %@ %@", NSStringFromSelector(_cmd), m.title, item.title);

    [_suggestionsController cancelSuggestions];
    [self close];
}


- (NSString *)stringForKeyModifierMask:(NSUInteger)modifer
{
    //⌫⏏⎋⏎
    NSMutableString *string = [[NSMutableString alloc] init];
    if (modifer & NSAlphaShiftKeyMask)
        [string appendString:@"⇧"];
    if (modifer & NSShiftKeyMask)
        [string appendString:@"⇧"];
    if (modifer & NSControlKeyMask)
        [string appendString:@"⌃"];
    if (modifer & NSAlternateKeyMask)
        [string appendString:@"⎇"];
    if (modifer & NSCommandKeyMask)
        [string appendString:@"⌘"];
    if (modifer & NSNumericPadKeyMask)
        [string appendString:@"NSNumericPadKeyMask "];
    if (modifer & NSFunctionKeyMask)
        [string appendString:@"NSFunctionKeyMask "];

    return string;
    //    NSAlphaShiftKeyMask         = 1 << 16,
    //    NSShiftKeyMask              = 1 << 17,
    //    NSControlKeyMask            = 1 << 18,
    //    NSAlternateKeyMask          = 1 << 19,
    //    NSCommandKeyMask            = 1 << 20,
    //    NSNumericPadKeyMask         = 1 << 21,
    //    NSHelpKeyMask               = 1 << 22,
    //    NSFunctionKeyMask           = 1 << 23,
    //    NSDeviceIndependentModifierFlagsMask    = 0xffff0000UL

}

- (NSDictionary *) dictionaryForMenuItem:(NSMenuItem *)m path:(NSString *)path
{
    return @{@"title":m.title, @"path":path};
}

- (NSMutableArray *) allMenuItems
{
    NSArray *arr = [NSApp mainMenu].itemArray;
    NSMutableArray *a = [[NSMutableArray alloc] init];
    for (NSMenuItem *m in arr)
    {
        [a addObject:[self test:[[NSApp mainMenu] itemWithTitle:m.title].submenu  path:m.title]];
    }

    return a;
}

- (NSMutableArray *) test:(NSMenu *)menu path:(NSString *)path
{
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    for (NSMenuItem *m in menu.itemArray)
    {
        if (m.isSeparatorItem) continue;
        if (m.hasSubmenu)
        {
            NSString *path1 = [path stringByAppendingFormat:@" > %@", m.title];
            [arr addObject:[self dictionaryForMenuItem:m path:path]];
            [arr addObjectsFromArray:[self test:m.submenu path:path1]];
        }
        else
        {
            [arr addObject:[self dictionaryForMenuItem:m path:path]];
        }
    }
    return arr;
}

- (NSString *) stringByRemovingLastWord:(NSString *)string
{
    NSRange range = [string rangeOfString:@" " options:NSBackwardsSearch];
    if (range.location != NSNotFound && range.length > 0)
    {
        return [string substringToIndex:range.length];
    }
    return string;
}

@end




@implementation CustomWindow

- (BOOL)canBecomeKeyWindow
{
    return YES;
}

- (BOOL)canBecomeMainWindow
{
    return NO;
}

- (BOOL)becomeFirstResponder
{
    return YES;
}

- (void)resignKeyWindow
{
    [self close];
}
@end