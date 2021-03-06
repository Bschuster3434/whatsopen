//
//  listViewController.h
//  WhatsOpen
//
//  Created by Bryan Gaston on 12/25/12.
//  Copyright (c) 2012 UNC-CH. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UMAAppDelegate.h"
#import "queryController.h"

@interface listViewController : UITableViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, weak) IBOutlet UINavigationItem *navBar;
@property (nonatomic, readonly) IBOutlet UITableView *restaurantTableView;
@property (nonatomic, readonly) IBOutlet UIActivityIndicatorView *spinner;

//-(void)reloadRestaurantArrays;
@end