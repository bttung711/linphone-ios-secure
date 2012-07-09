/* UICompositeViewController.m
 *
 * Copyright (C) 2012  Belledonne Comunications, Grenoble, France
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or   
 *  (at your option) any later version.                                 
 *                                                                      
 *  This program is distributed in the hope that it will be useful,     
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of      
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the       
 *  GNU Library General Public License for more details.                
 *                                                                      
 *  You should have received a copy of the GNU General Public License   
 *  along with this program; if not, write to the Free Software         
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */ 

#import "UICompositeViewController.h"

@implementation UICompositeViewDescription

- (id)copy {
    UICompositeViewDescription *copy = [UICompositeViewDescription alloc];
    copy->content = self->content;
    copy->stateBar = self->stateBar;
    copy->stateBarEnabled = self->stateBarEnabled;
    copy->tabBar = self->tabBar;
    copy->tabBarEnabled = self->tabBarEnabled;
    copy->fullscreen = self->fullscreen;
    return copy;
}

- (id)init:(NSString *)acontent stateBar:(NSString*)astateBar 
                        stateBarEnabled:(BOOL) astateBarEnabled 
                                 tabBar:(NSString*)atabBar
                          tabBarEnabled:(BOOL) atabBarEnabled
                             fullscreen:(BOOL) afullscreen {
    self->content = acontent;
    self->stateBar = astateBar;
    self->stateBarEnabled = astateBarEnabled;
    self->tabBar = atabBar;
    self->tabBarEnabled = atabBarEnabled;
    self->fullscreen = afullscreen;
    
    return self;
}

@end

@implementation UICompositeViewController

@synthesize stateBarView;
@synthesize contentView;
@synthesize tabBarView;

@synthesize viewTransition;


#pragma mark - Lifecycle Functions

- (void)initUICompositeViewController {
    self->viewControllerCache = [[NSMutableDictionary alloc] init]; 
}

- (id)init{
    self = [super init];
    if (self) {
		[self initUICompositeViewController];
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
		[self initUICompositeViewController];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
		[self initUICompositeViewController];
	}
    return self;
}	

- (void)dealloc {
    [contentView release];
    [stateBarView release];
    [tabBarView release];
    [viewControllerCache removeAllObjects];
    [currentViewDescription dealloc];
    [super dealloc];
}

#pragma mark - 

+ (void)addSubView:(UIViewController*)controller view:(UIView*)view {
    if(controller != nil) {
        [controller view]; // Load the view
        if ([[UIDevice currentDevice].systemVersion doubleValue] < 5.0) {
            [controller viewWillAppear:NO];
        }
        [view addSubview: controller.view];
        if ([[UIDevice currentDevice].systemVersion doubleValue] < 5.0) {
            [controller viewDidAppear:NO];
        }
    }
}

+ (void)removeSubView:(UIViewController*)controller {
    if(controller != nil) {
        if ([[UIDevice currentDevice].systemVersion doubleValue] < 5.0) {
            [controller viewWillDisappear:NO];
        }
        [controller.view removeFromSuperview];
        if ([[UIDevice currentDevice].systemVersion doubleValue] < 5.0) {
            [controller viewDidDisappear:NO];
        }
    }
}

- (UIViewController*)getCachedController:(NSString*)name {
    UIViewController *controller = nil;
    if(name != nil) {
        controller = [viewControllerCache objectForKey:name];
        if(controller == nil) {
            controller = [[NSClassFromString(name) alloc] init];
            [viewControllerCache setValue:controller forKey:name];
        }
    }
    return controller;
}

#define IPHONE_STATUSBAR_HEIGHT 20

- (void)update: (UICompositeViewDescription*) description tabBar:(NSNumber*)tabBar fullscreen:(NSNumber*)fullscreen {   
    
    // Copy view description
    UICompositeViewDescription *oldViewDescription = (currentViewDescription != nil)? [currentViewDescription copy]: nil;

    if(description != nil) {
        currentViewDescription = description;
        
        // Animate only with a previous screen
        if(oldViewDescription != nil && viewTransition != nil) {
            [contentView.layer addAnimation:viewTransition forKey:@"Transition"];
            if((oldViewDescription->stateBarEnabled == true && currentViewDescription->stateBarEnabled == false) ||
               (oldViewDescription->stateBarEnabled == false && currentViewDescription->stateBarEnabled == true)) {
                [stateBarView.layer addAnimation:viewTransition forKey:@"Transition"];
            }
            if(oldViewDescription->tabBar != currentViewDescription->tabBar) {
                [tabBarView.layer addAnimation:viewTransition forKey:@"Transition"];
            }
        }
        
        if(oldViewDescription != nil && contentViewController != nil && oldViewDescription->content != currentViewDescription->content) {
            [UICompositeViewController removeSubView: contentViewController];
        }
        if(oldViewDescription != nil && tabBarViewController != nil && oldViewDescription->tabBar != currentViewDescription->tabBar) {
            [UICompositeViewController removeSubView: tabBarViewController];
        }
        if(oldViewDescription != nil && stateBarViewController != nil && oldViewDescription->stateBar != currentViewDescription->stateBar) {
            [UICompositeViewController removeSubView: stateBarViewController];
        }

        stateBarViewController = [self getCachedController:description->stateBar];
        contentViewController = [self getCachedController:description->content];
        tabBarViewController = [self getCachedController:description->tabBar];
    }
    
    if(currentViewDescription == nil) {
        return;
    }
    
    if(tabBar != nil) {
        currentViewDescription->tabBarEnabled = [tabBar boolValue];
    }
    
    if(fullscreen != nil) {
        currentViewDescription->fullscreen = [fullscreen boolValue];
        [[UIApplication sharedApplication] setStatusBarHidden:currentViewDescription->fullscreen withAnimation:UIStatusBarAnimationSlide ];
    } else {
        [[UIApplication sharedApplication] setStatusBarHidden:currentViewDescription->fullscreen withAnimation:UIStatusBarAnimationNone];
    }
    
    // Start animation
    if(tabBar != nil || fullscreen != nil) {
        [UIView beginAnimations:@"resize" context:nil];
        [UIView setAnimationDuration:0.35];
        [UIView setAnimationBeginsFromCurrentState:TRUE];
    }
    
    UIView *innerView = contentViewController.view;
    
    CGRect contentFrame = contentView.frame;
    
    // Resize StateBar
    CGRect stateBarFrame = stateBarView.frame;
    int origin = 0;
    if(currentViewDescription->fullscreen)
        origin = -IPHONE_STATUSBAR_HEIGHT;
    
    if(stateBarViewController != nil && currentViewDescription->stateBarEnabled) {
        contentFrame.origin.y = origin + stateBarFrame.size.height;
        stateBarFrame.origin.y = origin;
    } else {
        contentFrame.origin.y = origin;
        stateBarFrame.origin.y = origin - stateBarFrame.size.height;
    }
    
    // Resize TabBar
    CGRect tabFrame = tabBarView.frame;
    if(tabBarViewController != nil && currentViewDescription->tabBarEnabled) {
        tabFrame.origin.y = [[UIScreen mainScreen] bounds].size.height - IPHONE_STATUSBAR_HEIGHT;
        tabFrame.origin.x = [[UIScreen mainScreen] bounds].size.width;
        tabFrame.size.height = tabBarViewController.view.frame.size.height;
        tabFrame.size.width = tabBarViewController.view.frame.size.width;
        tabFrame.origin.y -= tabFrame.size.height;
        tabFrame.origin.x -= tabFrame.size.width;
        contentFrame.size.height = tabFrame.origin.y - contentFrame.origin.y;
        for (UIView *view in tabBarViewController.view.subviews) {
            if(view.tag == -1) {
                contentFrame.size.height += view.frame.origin.y;
                break;
            }
        }
    } else {
        contentFrame.size.height = tabFrame.origin.y + tabFrame.size.height;
        tabFrame.origin.y = [[UIScreen mainScreen] bounds].size.height - IPHONE_STATUSBAR_HEIGHT;
    }
    
    if(currentViewDescription->fullscreen)
        contentFrame.size.height = [[UIScreen mainScreen] bounds].size.height + IPHONE_STATUSBAR_HEIGHT;
    
    // Resize innerView
    CGRect innerContentFrame = innerView.frame;
    innerContentFrame.size = contentFrame.size;
    
    
    // Set frames
    [contentView setFrame: contentFrame];
    [innerView setFrame: innerContentFrame];
    [tabBarView setFrame: tabFrame];
    [stateBarView setFrame: stateBarFrame];
    
    // Commit animation
    if(tabBar != nil || fullscreen != nil) {
        [UIView commitAnimations];
    }
    
    // Change view
    if(description != nil) {
        if(oldViewDescription == nil || oldViewDescription->content != currentViewDescription->content) {
            [UICompositeViewController addSubView: contentViewController view:contentView];
        }
        if(oldViewDescription == nil || oldViewDescription->tabBar != currentViewDescription->tabBar) {
            [UICompositeViewController addSubView: tabBarViewController view:tabBarView];
        }
        if(oldViewDescription == nil || oldViewDescription->stateBar != currentViewDescription->stateBar) {
            [UICompositeViewController addSubView: stateBarViewController view:stateBarView];
        }
    }
    
    // Dealloc old view description
    if(oldViewDescription != nil) {
        [oldViewDescription dealloc];
    }
}

- (void) changeView:(UICompositeViewDescription *)description {
    [self view]; // Force view load
    [self update:description tabBar:nil fullscreen:nil];
}

- (void) setFullScreen:(BOOL) enabled {
    [self update:nil tabBar:nil fullscreen:[NSNumber numberWithBool:enabled]];
}

- (void) setToolBarHidden:(BOOL) hidden {
    [self update:nil tabBar:[NSNumber numberWithBool:!hidden] fullscreen:nil];
}

- (UIViewController *) getCurrentViewController {
    return contentViewController;
}

@end