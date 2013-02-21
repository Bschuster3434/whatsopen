//
//  listViewController.m
//  WhatsOpen
//
//  Created by Bryan Gaston on 12/25/12.
//  Copyright (c) 2012 UNC-CH. All rights reserved.
//


/*
to-do: move querying into different file and set up as a singleton
 //to-do: will queries fail gracefully if there's no location found?
//to-do: what happens if there are none open now in 3 pages?
//to-do: what if there are none open later today?
//to-do: what if Google returns null result? Will it crash?
//to-do: what if factual returns null result? will it crash?
 to-do: comment out test location code
 to-do: I occasionally get a data is nil exception. Be sure to implement success and failure blocks for the API calls.
*/
 
#import "listViewController.h"
#import "placeDetailViewController.h"
#import "UMAAppDelegate.h"

@interface listViewController ()
{
    UIActivityIndicatorView *spinner;
    NSMutableArray *_placesArray;
    NSMutableArray *openNowPlaces;
    NSMutableArray *openLaterPlaces;
    NSString *googleTypesString;
    int pageNum;
    bool isFirstTimeLocationServicesEnabled;
}

@end

@implementation listViewController

@synthesize queryResult=_queryResult;
@synthesize placeTableView;
@synthesize locationMeasurements;
@synthesize bestEffortAtLocation;
@synthesize queryCategories;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    queryCategories = [NSArray arrayWithObjects:@"cafe", @"restaurant", @"bakery", nil];
    openNowPlaces = [[NSMutableArray alloc]init];
    openLaterPlaces = [[NSMutableArray alloc]init];
    
    //set up pull to refresh
    UIRefreshControl *pullToRefresh = [[UIRefreshControl alloc]init];
    [pullToRefresh addTarget:self action:@selector(refreshResults) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = pullToRefresh;
    
    //display spinner to indicate to the user that the query is still running
    spinner = [[UIActivityIndicatorView alloc]
               initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    spinner.center = CGPointMake(160, 200);
    spinner.hidesWhenStopped = YES;
    spinner.color = [UIColor blackColor];
    [self.view addSubview:spinner];
    
    //set up device location manager and get current location
    locationManager = [[CLLocationManager alloc] init];
    [locationManager setDelegate:self];
    //Restaurant list will update only if user pulls down to refresh. I'm setting the
    //distance filter to an arbitrarily high number to ensure that didUpdateToLocation is
    //called only once each time I want to get an updated location. When it was set to none,
    //I wasn't always able to stopUpdatingLocation before the location was detected more than
    //once, triggering multiple calls to queryGooglePlaces.
    [locationManager setDistanceFilter:500.0f];
    [locationManager startUpdatingLocation];
    
    //set pg to 1 since initial Google Places query will pull the 1st page of results
    pageNum = 1;
    
    //add "powered by Google"
    //to-do: make this float or at least format right dimensions
    UIImage *footerImage = [UIImage imageNamed:@"google.png"];
    UIImageView *footerImageView = [[UIImageView alloc] initWithImage:footerImage];
//    footerImageView.frame = CGRectMake(10,10,1,30);
    self.tableView.tableFooterView = footerImageView;
}
#pragma mark user authorized/denied location services
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    UIAlertView *locationDisabled = [[UIAlertView alloc]initWithTitle:@"Location Services Disabled" message:@"You have chosen to disable location services for WhatsUp, but the app cannot run without knowing your current location. Please enable location services for WhatsUp in the Settings menu, force the app to quit, and reopen it." delegate:self cancelButtonTitle:@"Dismiss" otherButtonTitles: nil];
    
    switch (status)
    {
        case kCLAuthorizationStatusNotDetermined:
            isFirstTimeLocationServicesEnabled = TRUE;
            break;
        case kCLAuthorizationStatusDenied:
            [locationDisabled show];
            break;
        case kCLAuthorizationStatusRestricted:
            [locationDisabled show];
            break;
        case kCLAuthorizationStatusAuthorized:
            if (isFirstTimeLocationServicesEnabled == TRUE)
            {
                [self queryGooglePlaces:queryCategories nextPageToken:nil];
            }
            break;
    }
}

//this is deprecated in iOS 6, but I want to also support 5, so I'm using it for now
- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{    
//    NSLog(@"got a location: %f,%f", newLocation.coordinate.latitude, newLocation.coordinate.longitude);

    //to-do: is the location accurate? How to make it more accurate? If I set desiredAccuracy, how do I get the app to wait to perform the query until after obtaining sufficient accuracy?
    
    //ensure that this measurement isn't cached (> 2 seconds old)
    [locationMeasurements addObject:newLocation];
    NSTimeInterval locationAge = -[newLocation.timestamp timeIntervalSinceNow];
    if (locationAge > 2.0) return;

    // test that the horizontal accuracy does not indicate an invalid measurement
    if (newLocation.horizontalAccuracy < 0) return;
    
    // ensure measurement is at least as accurate as previous measurement
    if (bestEffortAtLocation == nil || (bestEffortAtLocation.horizontalAccuracy >= newLocation.horizontalAccuracy))
    {
        self.bestEffortAtLocation = newLocation;
        deviceLocation = bestEffortAtLocation.coordinate;
        
//        UNCOMMENT THIS CODE TO TEST THE APP WITH A CHAPEL HILL, NC LOCATION
        deviceLocation = CLLocationCoordinate2DMake(35.913164,-79.055765);
        
        [locationManager stopUpdatingLocation];
        
        NSLog(@"location: %f,%f", deviceLocation.latitude, deviceLocation.longitude);
        
        //find restaurants based on the new location
        [self queryGooglePlaces:queryCategories nextPageToken:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)refreshResults
{
    // find updated device lat/long and queryGooglePlaces upon finding updated location
    [locationManager startUpdatingLocation];
      
    [self.refreshControl endRefreshing];
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // section 0 is "open now," and section 1 is "open later today"
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section)
    {
        case 0:
            return @"Open Now";
            break;
        case 1:
            return @"Open Later Today";
            break;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section)
    {
        case 0:
            return openNowPlaces.count;
            break;
        case 1:
            return openLaterPlaces.count;
            break;
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row %2 == 0)
    {
        UIColor *lightBlue = [UIColor colorWithRed:0.5 green:0.8 blue:1.0 alpha:0.35];
        cell.backgroundColor = lightBlue;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"placeCell"];
        
    if (indexPath.section == 0)
    {
        cell.textLabel.text = [[openNowPlaces objectAtIndex:indexPath.row] objectForKey:@"name"];
        cell.detailTextLabel.text = [[openNowPlaces objectAtIndex:indexPath.row] objectForKey:@"proximity"];
    }
    else {
        cell.textLabel.text = [[openLaterPlaces objectAtIndex:indexPath.row] valueForKey:@"name"];
        cell.detailTextLabel.text = [[openLaterPlaces objectAtIndex:indexPath.row] valueForKey:@"proximity"];
    }
    return cell;
}

- (float)calculateDistanceFromDeviceLatitudeInMiles:(float)deviceLatitude deviceLongitude:(float)deviceLongitude toPlaceLatitude:(float)placeLat placeLongitude:(float)placeLng
{
    
    float latDiffFloat = deviceLatitude - placeLat;
    float lngDiffFloat = deviceLongitude - placeLng;
    float latSquaredFloat = powf(latDiffFloat, 2);
    float lngSquaredFlaot = powf(lngDiffFloat, 2);
    
    float distanceInMilesFloat = sqrtf(latSquaredFloat + lngSquaredFlaot) * (10000/90) * .621371;
    float distance = [[NSString stringWithFormat:@"%.2f", distanceInMilesFloat] floatValue];
    
    return distance;
}

/*
 // Override to support conditional editing of the table view.
 - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
 {
 // Return NO if you do not want the specified item to be editable.
 return YES;
 }
 */

/*
 // Override to support editing the table view.
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
 {
 if (editingStyle == UITableViewCellEditingStyleDelete) {
 // Delete the row from the data source
 [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
 }
 else if (editingStyle == UITableViewCellEditingStyleInsert) {
 // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
 }
 }
 */

/*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
 {
 }
 */

/*
 // Override to support conditional rearranging of the table view.
 - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
 {
 // Return NO if you do not want the item to be re-orderable.
 return YES;
 }
 */

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     */
}

#pragma mark - Google Places Query
-(void)queryGooglePlaces:(NSArray *)googleTypes nextPageToken:(NSString *)nextPageToken
{    
    /* queryGooglePlaces is potentially called multiple times with different
     pageTokens for a full refresh of the restaurant data in the table. Here, I test whether
     this is the initial query in a full refresh of the data or part way through a refresh.
     */
    if (nextPageToken.length < 1)
    {
        if ([openNowPlaces count] > 0)
        {
            [openNowPlaces removeAllObjects];
        }
        if ([openLaterPlaces count] > 0)
        {
            [openLaterPlaces removeAllObjects];
        }
    }
    
//    NSLog(@"query executing");
        
    //Google Places API allows searching by "types," which we specify in the queryCategories array in this app.
    //Here, we build a string of all categories ("types") we want to search with Google Places API.
    googleTypesString = [[NSString alloc]initWithString:[googleTypes objectAtIndex:0]];
    
    //if more than 1 type is supplied
    if ([googleTypes count] >1 )
    {
        googleTypesString = [googleTypesString stringByAppendingString:@"%7C"];
        
        for (int i=1; i<[googleTypes count]; i++)
        {
            googleTypesString = [googleTypesString stringByAppendingString:[googleTypes objectAtIndex:i]];
            
            //add | character to end of googleTypesString if this is not the last string in the googleTypes array
            if (i!=[googleTypes count]-1)
            {
                googleTypesString = [googleTypesString stringByAppendingString:@"%7C"];
            }
        }
    }
    
    NSString *url = [[NSString alloc]init];
    
    //Google Places will return up to 3 pages of results.
    if ( [nextPageToken length] == 0)
    {
        url = [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/place/search/json?location=%f,%f&types=%@&rankby=distance&sensor=true&key=%@&hasNextPage=true&nextPage()=true", deviceLocation.latitude, deviceLocation.longitude, googleTypesString, GOOGLE_API_KEY];
    }
    else
    {
        url = [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/place/search/json?location=%f,%f&types=%@&rankby=distance&sensor=true&key=%@&hasNextPage=true&nextPage()=true&pagetoken=%@", deviceLocation.latitude, deviceLocation.longitude, googleTypesString, GOOGLE_API_KEY, nextPageToken];
    }

    NSURL *googleRequestURL=[NSURL URLWithString:url];
    

/* to-do: remove this
    // Retrieve the results of the query
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData* data = [NSData dataWithContentsOfURL: googleRequestURL];
        [self performSelectorOnMainThread:@selector(fetchedGoogleData:) withObject:data waitUntilDone:YES];
    });
*/
    NSData* data = [NSData dataWithContentsOfURL: googleRequestURL];
    [self performSelectorOnMainThread:@selector(fetchedGoogleData:) withObject:data waitUntilDone:YES];
    
}

- (void)fetchedGoogleData:(NSData *)responseData
{   
    NSError* error;
    NSDictionary* json = [NSJSONSerialization
                          JSONObjectWithData:responseData
                          options:kNilOptions
                          error:&error];
    NSString *nextPageToken = [json objectForKey:@"next_page_token"];
    
    _placesArray = [json objectForKey:@"results"];
    
//    NSLog(@"all Google results: %@", _placesArray);
    
    //to-do: if < 1 open place, set value for "name" key for object 0 of openNowPlaces to @"None open within %@", farthestPlaceString
    // to-do: if all places are open, there are none "open later today", so check for count of 0
    
    int numOpenNow = 0;
    NSString *farthestPlaceString = [[NSString alloc]init];
    
    /*Look at each restaurant from Google to see if it's open. If open, add to openNowPlaces, which displays in the table
     under the section "Open Now".  If not currently open (or if Google doesn't make it clear whether or not it's open), 
     find the restaurant in Factual's database to see if it's open (or open later today, in which case we'll add it to
     the openLaterPlaces array to display under the section "Open Later Today.")     
     */
    for (int i=0; i<_placesArray.count; i++)
    {
        NSMutableDictionary *place = [[NSMutableDictionary alloc]initWithDictionary:[_placesArray objectAtIndex:i]];
        
        //Get distance of farthest place in the results. Since results are ordered by distance, we'll look at the last result.
        if (i == (_placesArray.count - 1))
        {
            //calculate the proximity of the mobile device to the establishment
            float placeLat = [[[[place objectForKey:@"geometry"]objectForKey:@"location"]objectForKey:@"lat"]floatValue];
            float placeLng = [[[[place objectForKey:@"geometry"]objectForKey:@"location"]objectForKey:@"lng"]floatValue];
            float deviceLatitude = [[NSString stringWithFormat:@"%f", deviceLocation.latitude]floatValue];
            float deviceLongitude = [[NSString stringWithFormat:@"%f", deviceLocation.longitude]floatValue];
            farthestPlaceString = [NSString stringWithFormat:@"%.2f miles",[self calculateDistanceFromDeviceLatitudeInMiles:deviceLatitude deviceLongitude:deviceLongitude toPlaceLatitude:placeLat placeLongitude:placeLng]];
            NSString *proximityMessage = [NSString stringWithFormat:@"Open restaurants within %@:",farthestPlaceString];
            
            //set message to farthest place distance. Example: "Open restaurants within 1.24 miles:"
            UIFont *font = [UIFont boldSystemFontOfSize:14.0];
            CGRect frame = CGRectMake(0, 0, [proximityMessage sizeWithFont:font].width, 44);
            UILabel *titleLabel = [[UILabel alloc]initWithFrame:frame];
            titleLabel.backgroundColor = [UIColor clearColor];
            titleLabel.font = font;
            titleLabel.textColor = [UIColor whiteColor];
            titleLabel.text = proximityMessage;
            self.navBar.titleView = titleLabel;
        }
        
        //calculate the proximity of the mobile device to the establishment
        float placeLat = [[[[place objectForKey:@"geometry"]objectForKey:@"location"]objectForKey:@"lat"]floatValue];
        float placeLng = [[[[place objectForKey:@"geometry"]objectForKey:@"location"]objectForKey:@"lng"]floatValue];
        float deviceLatitude = [[NSString stringWithFormat:@"%f", deviceLocation.latitude]floatValue];
        float deviceLongitude = [[NSString stringWithFormat:@"%f", deviceLocation.longitude]floatValue];
        NSString *proximity = [NSString stringWithFormat:@"Distance: %.2f miles",[self calculateDistanceFromDeviceLatitudeInMiles:deviceLatitude deviceLongitude:deviceLongitude toPlaceLatitude:placeLat placeLongitude:placeLng]];
        [place setValue:proximity forKey:@"proximity"];
        
        //make sure opening_hours key and open_now key exist for this restaurant, and then put currently open restaurants into openNowPlaces array
        if ([place objectForKey:@"opening_hours"])
        {
            if ([[place objectForKey:@"opening_hours"] objectForKey:@"open_now"])
            {
                BOOL isOpen = [[[place objectForKey:@"opening_hours"] objectForKey:@"open_now"]boolValue];
                
                if (isOpen == TRUE)
                {    
                    numOpenNow++;
                    [openNowPlaces addObject:place];
                }
                else if (isOpen == FALSE)
                {
                    /*
                     If Google claims this restaurant is not open, find the restaurant in Factual's database to get the opening hours.
                     Although Google has a key for opening_hours, it is almost always empty, so we have to query Factual to get the full
                     hours for the restaurant. We'll then determine if the restaurant is open currently (Google was wrong), open later 
                     today, or not open at all today.
                     */
                    [self queryFactualWithRestaurantName:[place objectForKey:@"name"] streetAddress:[place objectForKey:@"vicinity"] latitude:placeLat longitude:placeLng];
                }
            }
            
            //want to sort these by proximity or soonest one to open later today???? - to-do
            
            else 
            {
                /*
                 If there's no open_now key in Google results for this restaurant, find the restaurant in Factual's database to see if it's
                 open now or later today (or not open at all today).
                 */
                [self queryFactualWithRestaurantName:[place objectForKey:@"name"] streetAddress:[place objectForKey:@"vicinity"] latitude:placeLat longitude:placeLng];
            }
        }
        else
        {
            /* 
             If there's no opening_hours key in Google results for this restaurant, find the restaurant in Factual's database to see if it's
             open now or later today (or not open at all today). 
             */
            [self queryFactualWithRestaurantName:[place objectForKey:@"name"] streetAddress:[place objectForKey:@"vicinity"] latitude:placeLat longitude:placeLng];
        }
    }//end for loop
    
    //to-do: spinner not actually visible for some reason
    [spinner stopAnimating];
    [[self placeTableView] reloadData];
    
    //if <9 restaurants are currently open, get next 20 results (unless we've already fetched page 3 of 3)
    //to-do: change to <9 becuase 9 is the max number that can be displayed in one screen on iPhone 4
    if ( numOpenNow <1 && pageNum <3)
    {
        //to-do: spinner not working properly 
        [spinner startAnimating];
        
        //the Google pageToken doesn't become valid for some unspecified period of time after requesting the first page, so we have to delay the next request
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.5 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self queryGooglePlaces:queryCategories nextPageToken:nextPageToken];
        });
        
        //increment with each new set of 20 results fetched from Google
        pageNum++;
    }
} //end fetchedGoogleData

#pragma mark - Factual Query
- (void)queryFactualWithRestaurantName:(NSString *)restaurantFullName streetAddress:(NSString *)address latitude:(float)lat longitude:(float)lng
{    
    //make sure valid values were passed in
    if ((restaurantFullName.length > 0) &
        (address.length > 0) &
        (fabsf(lat) > 0) &
        (fabsf(lng) > 0))
    {
        NSLog(@"to get from Factual: %@", restaurantFullName);
        
        //to-do: if Factual finds a restaurant with hours that Google didn't have hours for, see if it's open now because we need to add it to openNowPlaces array if so!
        
        FactualQuery* queryObject = [FactualQuery query];

        //clean restaurant name from Google before using the name to search Factual
        NSString *queryString = restaurantFullName;
        queryString = [queryString lowercaseString];
        queryString = [queryString stringByReplacingOccurrencesOfString:@"'" withString:@""];
        queryString = [queryString stringByReplacingOccurrencesOfString:@" & " withString:@" "];
        NSArray *restaurantNameExploded = [queryString componentsSeparatedByString:@" "];
        
        //use the first non "a", "an", or "the" word of the restaurant full name (from Google) to search Factual
        if (!([[restaurantNameExploded objectAtIndex:0] isEqualToString:@"a"] ||
              [[restaurantNameExploded objectAtIndex:0] isEqualToString:@"an"] ||
              [[restaurantNameExploded objectAtIndex:0] isEqualToString:@"the"]))
        {
            queryString = [restaurantNameExploded objectAtIndex:0];
        }
        else
        {
            queryString = [restaurantNameExploded objectAtIndex:1];
        }
        [queryObject addRowFilter:[FactualRowFilter fieldName:@"name" search:queryString]];
        
        //filter Factual results by the street number of the Google-supplied address
        NSArray *addressParts = [address componentsSeparatedByString:@" "];
        NSString *streetNumber = [addressParts objectAtIndex:0];
        [queryObject addRowFilter:[FactualRowFilter fieldName:@"address" beginsWith:streetNumber]];
        
        //filter by restaurants within 110 meters of Google's claimed restaurant location
        CLLocationCoordinate2D geoFilterCoords = {
            lat, lng
        };
        [queryObject setGeoFilter:geoFilterCoords radiusInMeters:110.0];
        
        //execute the Factual request
        _activeRequest = [[UMAAppDelegate getAPIObject] queryTable:@"restaurants" optionalQueryParams:queryObject withDelegate:self];
    }
    else
    {
        NSLog(@"invalid data passed into queryFactualWithRestaurantName");
    }
}

-(void) requestComplete:(FactualAPIRequest *)request receivedQueryResult:(FactualQueryResult *)queryResultObj {
    
    self.queryResult = queryResultObj;
    
//    NSLog(@"queryresult object 0: %@", [self.queryResult.rows objectAtIndex:0]);
    
    if ((self.queryResult != nil) & ([self.queryResult.rows objectAtIndex:0] != nil))
    {
        //use the first restaurant that matches the query
        FactualRow *row = [self.queryResult.rows objectAtIndex:0];
        
//        NSLog(@"from factual: %@", self.queryResult.rows);
        
        //to-do: need to check if these are open later today. For now, I'm adding all matches with Factual instead of checking hours first.
        
        //set values for restaurant object
        NSMutableDictionary *openLaterRestaurant = [[NSMutableDictionary alloc]init];
        NSString *restaurantName = [row valueForName:@"name"];
        
        //calculate proximity of mobile device to the restaurant
        float lat = [[row valueForName:@"latitude"]floatValue];
        float lng = [[row valueForName:@"longitude"]floatValue];
        NSString *proximity = [NSString stringWithFormat:@"Distance: %.2f miles",[self calculateDistanceFromDeviceLatitudeInMiles:deviceLocation.latitude deviceLongitude:deviceLocation.longitude toPlaceLatitude:lat placeLongitude:lng]];
        [openLaterRestaurant setValue:proximity forKey:@"proximity"];
        [openLaterRestaurant setValue:restaurantName forKey:@"name"];
        [openLaterRestaurant setValue:[row rowId] forKey:@"factual_id"];
        [openLaterRestaurant setValue:[row valueForName:@"hours"] forKey:@"hours"];
        
        //run query to factual with row filter "factual_id" and value [openLaterRestaurant valueForKey:@"factual_id"] to get the restaurant details
//        NSLog(@"factual id for %@: %@", [openLaterRestaurant valueForKey:@"name"], [openLaterRestaurant valueForKey:@"factual_id"]);
        
//        NSLog(@"factual hours for %@: %@", [openLaterRestaurant valueForKey:@"name"], [openLaterRestaurant valueForKey:@"hours"]);
        
        
        [openLaterPlaces addObject:openLaterRestaurant];
        
        //to-do: sort openLaterPlaces array by proximity asc
        //to-do: sort openNowPlaces array by proximity asc (the Google results are sorted that way since I queried based on proximity. However, I may be adding some Factual results in to openNowPlaces because the restaurant didn't have an opening_hours key in Google but is known to be open now based on Factual's data).

        [placeTableView reloadData];
    }
    
//    NSLog(@"openLaterPlaces: %d", [openLaterPlaces count]);
}

-(void) requestComplete:(FactualAPIRequest *)request failedWithError:(NSError *)error {
    NSLog(@"Factual request FAILED with error: ");
    NSLog(@"%@", error);
}

- (void)viewDidUnload
{
    [self setPlaceTableView:nil];
    [super viewDidUnload];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"detailSegue"])
    {
        // Get reference to the destination view controller
        placeDetailViewController *destinationVC = [segue destinationViewController];
        
        NSIndexPath *indexPath = [self.placeTableView indexPathForSelectedRow];
        NSUInteger section = [indexPath section];
        
        switch (section)
        {
                
            //to-do: some items in openNowPlaces may have been added from Factual. Do we want to pull the info from Google or Factual for the details page? If pulling from Google, we need to somehow get the "reference" value from Google into the NSMutableDictionary containing the restaurant that we added to openNowPlaces from Factual.  We would then query Google with the reference to get the details.
                
            //open now
            case 0:
                destinationVC.placeReference = [[openNowPlaces objectAtIndex:indexPath.row]objectForKey:@"reference"];
                destinationVC.placeRating = [[openNowPlaces objectAtIndex:indexPath.row]objectForKey:@"rating"];
                destinationVC.deviceLat = [NSString stringWithFormat:@"%f",deviceLocation.latitude];
                destinationVC.deviceLng = [NSString stringWithFormat:@"%f",deviceLocation.longitude];
                destinationVC.proximity = [[openNowPlaces objectAtIndex:indexPath.row]objectForKey:@"proximity"];
                destinationVC.placeLat = [[[[openNowPlaces objectAtIndex:indexPath.row]objectForKey:@"geometry"]objectForKey:@"location"]objectForKey:@"lat"];
                destinationVC.placeLng = [[[[openNowPlaces objectAtIndex:indexPath.row]objectForKey:@"geometry"]objectForKey:@"location"]objectForKey:@"lng"];
                break;
            //open later today
            case 1:
//                destinationVC.placeReference = [[openLaterPlaces objectAtIndex:indexPath.row]objectForKey:@"reference"];
                //to-do: make sure tapping a place takes you to the right details page!
                //to-do: should I get rating from Google or Factual? Need to set up openLaterPlace mutable dict for this entire implementation and set value for it within G query if using Google
                //                destinationVC.placeRating = [[openLaterPlaces objectAtIndex:indexPath.row]objectForKey:@"rating"];
                destinationVC.deviceLat = [NSString stringWithFormat:@"%f",deviceLocation.latitude];
                destinationVC.deviceLng = [NSString stringWithFormat:@"%f",deviceLocation.longitude];
                destinationVC.proximity = [[openLaterPlaces objectAtIndex:indexPath.row]objectForKey:@"proximity"];
                destinationVC.placeLat = [[openLaterPlaces objectAtIndex:indexPath.row]objectForKey:@"latitude"];
                destinationVC.placeLng = [[openLaterPlaces objectAtIndex:indexPath.row]objectForKey:@"longitude"];
                break;
        } //end switch
    }
}
@end
