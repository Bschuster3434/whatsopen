//
//  queryController.m
//  WhatsOpen
//
//  Created by Bryan Gaston on 2/22/13.
//  Copyright (c) 2013 UNC-CH. All rights reserved.
//

#import "queryController.h"

@implementation queryController
{
    //to-do: for naming convention, should these have underscores?
    NSInteger pageNum;
    CLLocationCoordinate2D deviceLocation;
    listViewController *listView;
    NSInteger numberOfResultsToCheck;
}
@synthesize queryCategories;
//@synthesize listView;
@synthesize openNow;
@synthesize openLater;


-(id)init
{
    _locationService = [[locationServices alloc]init];
    listView = [[listViewController alloc]init];
    
    queryCategories = [NSArray arrayWithObjects:@"cafe", @"restaurant", @"bakery", nil];
    openNow = [[NSMutableArray alloc]init];
    openLater = [[NSMutableArray alloc]init];
    
    //set pg to 1 since initial Google Places query will pull the 1st page of results
    pageNum = 1;
    
    return self;
}

-(void)getRestaurants
{
/*
    - begins google query, which also starts Facutal queries
    - populates local openNow and openLater mutable arrays with restaurant objects as it goes
    - each time openNow or openLater is updated, it is re-sorted
    - each time either array is updated, listViewController is contacted:
        - set property nsmutablearray openNow or openLater (whichever is updated just now)
        - reload the table
        - stop the spinner at some point
        - if user set this off by refreshing, figure out when to stop showing that it's refreshing
 
 
 
 What if I have openNow and openLater both stored in queryController.
 - when addObject to an array, call method from listVC telling it to get openNow (or openLater) from queryController and reload table
 */

    [self queryGooglePlacesWithTypes:queryCategories nextPageToken:nil];
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
        default:
            return nil;
            break;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section)
    {
        case 0:
            return openNow.count;
            break;
        case 1:
            return openLater.count;
            break;
        default:
            return nil;
            break;
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row %2 == 0)
    {
        UIColor *lightBlue = [UIColor colorWithRed:0.05 green:0.1 blue:0.15 alpha:0.15];
        cell.backgroundColor = lightBlue;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"placeCell"];
    
    if (indexPath.section == 0)
    {
        cell.textLabel.text = [[openNow objectAtIndex:indexPath.row] objectForKey:@"name"];
        cell.detailTextLabel.text = [[openNow objectAtIndex:indexPath.row] objectForKey:@"proximity"];
    }
    else {
        cell.textLabel.text = [[openLater objectAtIndex:indexPath.row] objectForKey:@"name"];
        //        cell.detailTextLabel.text = [[openLater objectAtIndex:indexPath.row] objectForKey:@"proximity"];
        NSDate *openNext = [[openLater objectAtIndex:indexPath.row] objectForKey:@"openNext"];
        NSDateFormatter *openNextFormatter = [[NSDateFormatter alloc]init];
        [openNextFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
        [openNextFormatter setDateFormat:@"h:mm a"];
        NSString *openNextString = [openNextFormatter stringFromDate:openNext];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Opening at %@", openNextString];
    }
    
    //remove halo effect in background color
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.detailTextLabel.backgroundColor = [UIColor clearColor];
    
    return cell;
}
#pragma mark - Google Places Query
-(void)queryGooglePlacesWithTypes:(NSArray *)googleTypes nextPageToken:(NSString *)nextPageToken
{
    deviceLocation = [_locationService getCurrentLocation];
    
    /* queryGooglePlaces is potentially called multiple times with different
     pageTokens for a full refresh of the restaurant data in the table. Here, I test whether
     this is the initial query in a full refresh of the data or part way through a refresh.
     */
    if (nextPageToken.length < 1)
    {
        pageNum = 1;
        
        if ([openNow count] > 0)
        {
            [openNow removeAllObjects];
        }
        if ([openLater count] > 0)
        {
            [openLater removeAllObjects];
        }
    }
    
    NSLog(@"query executing");
    
    //Google Places API allows searching by "types," which we specify in the queryCategories array in this app.
    //Here, we build a string of all categories ("types") we want to search with Google Places API.
    NSString *googleTypesString = [[NSString alloc]initWithString:[googleTypes objectAtIndex:0]];
    
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
    
    NSMutableArray *placesArray = [json objectForKey:@"results"];
    
    NSLog(@"all Google results: %@", placesArray);
    
    //get the number of results so that we can check whether we've looked at the hours for all of them
    numberOfResultsToCheck = placesArray.count;
    
    //to-do: if < 1 open place, set value for "name" key for object 0 of openNow to @"None open within %@", farthestPlaceString
    // to-do: if all places are open, there are none "open later today", so check for count of 0
    
    int numOpenNow = 0;
    NSString *farthestPlaceString = [[NSString alloc]init];
    
    /*Look at each restaurant from Google to see if it's open. If open, add to openNow, which displays in the table
     under the section "Open Now".  If not currently open (or if Google doesn't make it clear whether or not it's open),
     find the restaurant in Factual's database to see if it's open (or open later today, in which case we'll add it to
     the openLater array to display under the section "Open Later Today.")
     */
    for (int i=0; i<placesArray.count; i++)
    {
        NSMutableDictionary *place = [[NSMutableDictionary alloc]initWithDictionary:[placesArray objectAtIndex:i]];
        
        
        //to-do: ensure that distance on detail view for the Factual results matches the distance shown in the main table view
        //Get distance of farthest place in the results. Since results are ordered by distance, we'll look at the last result.
        if (i == (placesArray.count - 1))
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
            
            //to-do: is it bad practice to use the built-in setter (as a property) instead of using a homemade method?
            listView.navBar.titleView = titleLabel;
        }
        
        //calculate the proximity of the mobile device to the establishment
        float placeLat = [[[[place objectForKey:@"geometry"]objectForKey:@"location"]objectForKey:@"lat"]floatValue];
        float placeLng = [[[[place objectForKey:@"geometry"]objectForKey:@"location"]objectForKey:@"lng"]floatValue];
        float deviceLatitude = [[NSString stringWithFormat:@"%f", deviceLocation.latitude]floatValue];
        float deviceLongitude = [[NSString stringWithFormat:@"%f", deviceLocation.longitude]floatValue];
        NSString *proximity = [NSString stringWithFormat:@"Distance: %.2f miles",[self calculateDistanceFromDeviceLatitudeInMiles:deviceLatitude deviceLongitude:deviceLongitude toPlaceLatitude:placeLat placeLongitude:placeLng]];
        [place setValue:proximity forKey:@"proximity"];
        
        //make sure opening_hours key and open_now key exist for this restaurant, and then put currently open restaurants into openNow array
        if ([place objectForKey:@"opening_hours"])
        {
            if ([[place objectForKey:@"opening_hours"] objectForKey:@"open_now"])
            {
                BOOL isOpen = [[[place objectForKey:@"opening_hours"] objectForKey:@"open_now"]boolValue];
                
                if (isOpen == TRUE)
                {
                    numOpenNow++;
                    [place setObject:@"google" forKey:@"provider"];
                    [openNow addObject:place];
                    numberOfResultsToCheck--;
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
    
    //to-do: spinner not actually visible on screen for some reason
//    [[listView spinner] stopAnimating];
//    [[listView restaurantTableView] reloadData];
    
    //if <9 restaurants are currently open, get next 20 results (unless we've already fetched page 3 of 3)
    //to-do: change to <9 becuase 9 is the max number that can be displayed in one screen on iPhone 4
    //to-do: make sure there aren't strange duplicate cell issues after changing it to <9
    if ((numOpenNow <1) & (pageNum <3))
    {
        NSLog(@"getting more results");
        //to-do: spinner not working properly
//        [[listView spinner] startAnimating];
        
        //the Google pageToken doesn't become valid for some unspecified period of time after requesting the first page, so we have to delay the next request
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.5 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self queryGooglePlacesWithTypes:queryCategories nextPageToken:nextPageToken];
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
        
        //to-do: if Factual finds a restaurant with hours that Google didn't have hours for, see if it's open now because we need to add it to openNow array if so!
        
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

-(NSDate *) getDateWithHour:(NSInteger)hour minute:(NSInteger)minute second:(NSInteger)second onDate:(NSDate *)date withGMTOffset:(NSInteger)GMTOffset withDayOffset:(NSInteger)dayOffset
{
    NSDateComponents *timeComponents = [[NSCalendar currentCalendar] components:NSUIntegerMax fromDate:date];
    [timeComponents setHour:hour];
    [timeComponents setMinute:minute];
    [timeComponents setSecond:second];
    NSDate *timeDate = [[NSCalendar currentCalendar] dateFromComponents:timeComponents];
    
    if (dayOffset != 0)
    {
        NSDateComponents *dayOffsetComponent = [[NSDateComponents alloc]init];
        [dayOffsetComponent setDay:dayOffset];
        timeDate = [[NSCalendar currentCalendar] dateByAddingComponents:dayOffsetComponent toDate:timeDate options:0];
    }
    
    timeDate = [NSDate dateWithTimeInterval:GMTOffset sinceDate:timeDate];
    
    return timeDate;
}

//Returns an array with two elements: open time date object and a close time date object
-(NSArray *) getHoursWithOpenTime:(NSString *)openTimeString closeTime:(NSString *)closeTimeString onDate:(NSDate *)date withGMTOffset:(NSInteger)GMTOffset
{
    //Get integer values for the opening and closing hour/minute of the restaurant
    NSInteger openHour;
    NSInteger openMinute;
    NSInteger closeHour;
    NSInteger closeMinute;
    
    if ([openTimeString length] > 4)
    {
        //it's after 9:59, so it's HH:mm instead of H:mm
        openHour = [[openTimeString substringToIndex:2]integerValue];
        openMinute = [[openTimeString substringWithRange:NSMakeRange(3, 2)]integerValue];
    }
    else
    {
        //it's before 10:00, so it's H:mm
        openHour = [[openTimeString substringToIndex:1]integerValue];
        openMinute = [[openTimeString substringWithRange:NSMakeRange(2, 2)]integerValue];
    }
    if ([closeTimeString length] > 4)
    {
        //it's after 9:59, so it's HH:mm instead of H:mm
        closeHour = [[closeTimeString substringToIndex:2]integerValue];
        closeMinute = [[closeTimeString substringWithRange:NSMakeRange(3, 2)]integerValue];
    }
    else
    {
        //it's before 10:00, so it's H:mm
        closeHour = [[closeTimeString substringToIndex:1]integerValue];
        closeMinute = [[closeTimeString substringWithRange:NSMakeRange(2, 2)]integerValue];
    }
    
    //Create a date object representing the opening time of the restaurant
    NSDate *openTimeDate = [self getDateWithHour:openHour
                                          minute:openMinute
                                          second:0
                                          onDate:date
                                   withGMTOffset:GMTOffset
                                   withDayOffset:0];
    NSLog(@"open time date: %@", openTimeDate);
    
    //Create a date object representing the closing time of the restaurant
    NSDate *closeTimeDate = [self getDateWithHour:closeHour
                                           minute:closeMinute
                                           second:0
                                           onDate:date
                                    withGMTOffset:GMTOffset
                                    withDayOffset:0];
    
    //If the restaurant closes after midnight, set the close date to the close hour on the NEXT day
    //example: ["11:00","2:00"] opens at 11am, closes at 2am the next day
    if (closeHour < openHour)
    {
        closeTimeDate = [self getDateWithHour:closeHour
                                       minute:closeMinute
                                       second:0
                                       onDate:date
                                withGMTOffset:GMTOffset
                                withDayOffset:1];
    }
    
    NSArray *openAndCloseHours = [NSArray arrayWithObjects:openTimeDate, closeTimeDate, nil];
    
    return openAndCloseHours;
}

//Answers questions like this: Is restaurant with hours ["11:00","4:00"] on Thursday open now (Friday early morning at 2:30)?
-(BOOL) restaurantWithOpeningHoursRange:(NSArray *)hours onDate:(NSDate *)dateOfSpecifiedHours isOpenAtTime:(NSDate *)dateToCheck
{
    BOOL isOpen;
    
    //Get timezone of the mobile device
    NSDate* GMTDate = [NSDate date];
    NSTimeZone* systemTimeZone = [NSTimeZone systemTimeZone];
    NSInteger deviceGMTOffset = [systemTimeZone secondsFromGMTForDate:GMTDate];
    
    //Get opening hours of restaurant
    //Example open time: "10:00"     Example close time: "2:00"
    NSString *openTimeString = [hours objectAtIndex:0];
    NSString *closeTimeString = [hours objectAtIndex:1];
    
    //Get date objects for open and close times
    NSDate *openTimeDate = [[self getHoursWithOpenTime:openTimeString
                                             closeTime:closeTimeString
                                                onDate:dateOfSpecifiedHours
                                         withGMTOffset:deviceGMTOffset]
                            objectAtIndex:0];
    NSDate *closeTimeDate = [[self getHoursWithOpenTime:openTimeString
                                              closeTime:closeTimeString
                                                 onDate:dateOfSpecifiedHours
                                          withGMTOffset:deviceGMTOffset]
                             objectAtIndex:1];
    
    NSLog(@"close time date: %@", closeTimeDate);
    
    //Is the restaurant still open now (hasn't closed since it opened yesterday)?
    if (([dateToCheck compare:closeTimeDate] == NSOrderedAscending) &
        ([dateToCheck compare:openTimeDate] == NSOrderedDescending))
    {
        NSLog(@"It is open.");
        isOpen = TRUE;
    }
    else
    {
        NSLog(@"It is not open");
        isOpen = FALSE;
    }
    
    return  isOpen;
}

-(void) requestComplete:(FactualAPIRequest *)request receivedQueryResult:(FactualQueryResult *)queryResultObj
{
    
    self.queryResult = queryResultObj;
    
    BOOL addedAlready = FALSE;
    
    //run only if we have a valid response from Factual
    if ((self.queryResult != nil) & ([self.queryResult.rows objectAtIndex:0] != nil))
    {
        //use the first restaurant that matches the query (if there's more than one result, such as in the case of a duplicate database entry)
        FactualRow *row = [self.queryResult.rows objectAtIndex:0];
        
        //to-do: sort openLater array by proximity asc
        //to-do: sort openNow array by proximity asc (the Google results are sorted that way since I queried based on proximity. However, I may be adding some Factual results in to openNow because the restaurant didn't have an opening_hours key in Google but is known to be open now based on Factual's data).
        
        //if there is a value for the hours key
        if ([[row valueForName:@"hours"] length] > 0)
        {
            //set values for restaurant object
            NSMutableDictionary *restaurant = [[NSMutableDictionary alloc]init];
            NSString *restaurantName = [row valueForName:@"name"];
            
            //calculate proximity of mobile device to the restaurant
            float lat = [[row valueForName:@"latitude"]floatValue];
            float lng = [[row valueForName:@"longitude"]floatValue];
            NSString *proximity = [NSString stringWithFormat:@"Distance: %.2f miles",[self calculateDistanceFromDeviceLatitudeInMiles:deviceLocation.latitude deviceLongitude:deviceLocation.longitude toPlaceLatitude:lat placeLongitude:lng]];
            [restaurant setValue:proximity forKey:@"proximity"];
            [restaurant setValue:restaurantName forKey:@"name"];
            [restaurant setValue:[row rowId] forKey:@"factual_id"];
            [restaurant setValue:[row valueForName:@"hours"] forKey:@"hours"];
            [restaurant setObject:@"factual" forKey:@"provider"];
            
            //hours from Factual are in string format, so we convert them to JSON for key-value compliance
            NSData *hoursData = [[restaurant objectForKey:@"hours"] dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *hours = [NSJSONSerialization JSONObjectWithData:hoursData
                                                                  options:NSJSONReadingMutableContainers
                                                                    error:nil];
            if (!hours)
            {
                NSLog(@"Error parsing hours JSON from Factual");
            }
            else
            {
                //to-do: how should I display to users the optional string after the pair of hours? Example: ["11:00","16:00","Lunch"]. Factual says that these are just a guess if they say "lunch," "dinner," "breakfast," etc.  In their documentation, they also say that some say things like "only after Labor Day." How to display that to user? Show that it's open now (or later today), but if it has a message, display that message prominently on the details page?
                
                NSLog(@"----------------------------------");
                
                //get current date/time in the timezone of the mobile device
                NSDate* GMTDate = [NSDate date];
                NSTimeZone* systemTimeZone = [NSTimeZone systemTimeZone];
                NSInteger deviceGMTOffset = [systemTimeZone secondsFromGMTForDate:GMTDate];
                NSDate* dateTimeInSystemLocalTimezone = [[NSDate alloc] initWithTimeInterval:deviceGMTOffset sinceDate:GMTDate];
                
                //get current day of week
                NSDateFormatter *dayOfWeekFormatter = [[NSDateFormatter alloc]init];
                [dayOfWeekFormatter setDateFormat:@"EEEE"];
                [dayOfWeekFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
                NSString *dayToday = [[dayOfWeekFormatter stringFromDate:dateTimeInSystemLocalTimezone]lowercaseString];
                
                //to-do: will this work with [self getDate....]?
                //get previous day
                int daysToSet = -1;
                NSDateComponents *yesterdayComponents = [[NSDateComponents alloc] init];
                [yesterdayComponents setDay:daysToSet];
                NSDate *yesterdayDate = [[NSCalendar currentCalendar] dateByAddingComponents:yesterdayComponents toDate:dateTimeInSystemLocalTimezone options:0];
                NSString *dayYesterday = [[dayOfWeekFormatter stringFromDate:yesterdayDate]lowercaseString];
                
                //Is restaurant still open within last night's hour range?
                NSArray *yesterdayHours = [hours objectForKey:dayYesterday];
                
                if (yesterdayHours.count > 0)
                {
                    NSArray *lastHourRangeFromYesterday = [yesterdayHours lastObject];
                    
                    NSLog(@"last yesterday hours: %@", lastHourRangeFromYesterday);
                    NSLog(@"current time: %@", dateTimeInSystemLocalTimezone);
                    
                    //See if the restaurant is still open right now within last night's last hour range
                    BOOL restaurantIsOpen = [self restaurantWithOpeningHoursRange:lastHourRangeFromYesterday
                                                                           onDate:yesterdayDate
                                                                     isOpenAtTime:dateTimeInSystemLocalTimezone];
                    
                    if (restaurantIsOpen == TRUE)
                    {
                        NSLog(@"%@ IS OPEN from last night. Hours:%@", [restaurant valueForKey:@"name"], [yesterdayHours lastObject]);
                        
                        //Get the time comment (if any) for this range of hours for this restaurant
                        //http://developer.factual.com/display/docs/Places+API+-+Restaurants#PlacesAPI-Restaurants-OpeningHoursJSON.1
                        if ([lastHourRangeFromYesterday count] > 2)
                        {
                            //to-do: display this somehow to users - maybe highlight the cell some color if there's a comment to indicate that there's a qualifier (the comment might say that it's only open at this time on special occasions, for example)
                            
                            //this is an optional value that may not exist for most restaurants
                            NSString *optionalTimeComment = [lastHourRangeFromYesterday objectAtIndex:2];
                            NSLog(@"time comment: %@", optionalTimeComment);
                        }
                        
                        [openNow addObject:restaurant];
                        addedAlready = TRUE;
                        
                        //Re-sort by proximity and refresh table
                        NSSortDescriptor *sortByProximity = [NSSortDescriptor sortDescriptorWithKey:@"proximity" ascending:YES];
                        [openNow sortUsingDescriptors:[NSArray arrayWithObject:sortByProximity]];
                    }
                } //end if open yesterday
                
                // Is the restaurant open today? (not just from yesterday's hours carrying over to today)
                NSArray *todayHours = [hours objectForKey:dayToday];
                
                // If we know it's open from last night still, don't bother checking if it's open now based on today's hours
                if ((todayHours.count > 0) &
                    (addedAlready == FALSE))
                {
                    //check each set of opening hours today for the restaurant
                    for (int i=0; i < todayHours.count; i++)
                    {
                        
                        BOOL restaurantIsOpen = [self restaurantWithOpeningHoursRange:[todayHours objectAtIndex:i]
                                                                               onDate:dateTimeInSystemLocalTimezone
                                                                         isOpenAtTime:dateTimeInSystemLocalTimezone];
                        
                        //Get the time comment (if any) for this range of hours for this restaurant
                        //http://developer.factual.com/display/docs/Places+API+-+Restaurants#PlacesAPI-Restaurants-OpeningHoursJSON.1
                        if ([[todayHours objectAtIndex:i] count] > 2)
                        {
                            //to-do: display this somehow to users - maybe highlight the cell some color if there's a comment to indicate that there's a qualifier (the comment might say that it's only open at this time on special occasions, for example)
                            
                            //this is an optional value that may not exist for most restaurants
                            NSString *optionalTimeComment = [[todayHours objectAtIndex:i]objectAtIndex:2];
                            NSLog(@"time comment: %@", optionalTimeComment);
                        }
                        
                        if (restaurantIsOpen == TRUE)
                        {
                            NSLog(@"%@ IS OPEN. Hours:%@", [restaurant valueForKey:@"name"], todayHours);
                            
                            [openNow addObject:restaurant];
                            
                            //Re-sort by proximity
                            NSSortDescriptor *sortByProximity = [NSSortDescriptor sortDescriptorWithKey:@"proximity" ascending:YES];
                            [openNow sortUsingDescriptors:[NSArray arrayWithObject:sortByProximity]];
                        }
                        else
                        {
                            //to-do: in tableview cellForRowAtIndexPath, set detailText to [NSString stringWithFormat:@"Opening at %@", [restaurant objectForKey:@"openNext"]] (except, I need to convert to 12 hr format first and show only the time, not other date stuff).
                            
                            NSLog(@"%@ is CLOSED. Hours:%@", [restaurant valueForKey:@"name"], todayHours);
                            
                            //get date objects for when restaurant is open and closed
                            NSString *openTimeString = [[todayHours objectAtIndex:i]objectAtIndex:0];
                            NSString *closeTimeString = [[todayHours objectAtIndex:i]objectAtIndex:1];
                            NSDate *openTimeDate = [[self getHoursWithOpenTime:openTimeString
                                                                     closeTime:closeTimeString
                                                                        onDate:dateTimeInSystemLocalTimezone
                                                                 withGMTOffset:deviceGMTOffset]objectAtIndex:0];
                            NSDate *closeTimeDate = [[self getHoursWithOpenTime:openTimeString
                                                                      closeTime:closeTimeString
                                                                         onDate:dateTimeInSystemLocalTimezone
                                                                  withGMTOffset:deviceGMTOffset]objectAtIndex:1];
                            
                            NSLog(@"now:%@    open:%@    close:%@", dateTimeInSystemLocalTimezone, openTimeDate, closeTimeDate);
                            
                            // See if it's open later today
                            if ([dateTimeInSystemLocalTimezone compare:openTimeDate] == NSOrderedAscending)
                            {
                                NSLog(@"%@ is open LATER today.", [restaurant objectForKey:@"name"]);
                                //                                [restaurant setValue:[NSString stringWithFormat:@"%@", openTimeDate] forKey:@"openNext"];
                                //to-do: make sure openLater sorts properly when using the date OBJECT instead of date string
                                [restaurant setObject:openTimeDate forKey:@"openNext"];
                                [openLater addObject:restaurant];
                                
                                //re-sort by opening soonest
                                NSSortDescriptor *sortByOpeningSoonest = [NSSortDescriptor sortDescriptorWithKey:@"openNext" ascending:YES];
                                [openLater sortUsingDescriptors:[NSArray arrayWithObject:sortByOpeningSoonest]];
                                //to-do: should I move this?
                                
                                // Check the next restaurant (do not test other times for this restaurant since we already know it's open later)
                                break;
                            }
                        } //end else (see if it's open later today)
                    } //end for loop of all opening hour ranges today
                } //if open at all today
            } //end else (hours key successfully converted to JSON)
        } //end if it has a value for the hours key
    } //end if !empty query result
    
    numberOfResultsToCheck--;
    
    NSLog(@"number of Google results to check:%d", numberOfResultsToCheck);
    
    if (numberOfResultsToCheck == 0)
    {
        NSLog(@"FINISHED!!!!!");
        [[NSNotificationCenter defaultCenter] postNotificationName:@"restaurantsAcquired"
                                                            object:nil];
    }
}

-(void) requestComplete:(FactualAPIRequest *)request failedWithError:(NSError *)error {
    NSLog(@"Factual request FAILED with error: ");
    NSLog(@"%@", error);
}

- (float)calculateDistanceFromDeviceLatitudeInMiles:(float)deviceLatitude deviceLongitude:(float)deviceLongitude toPlaceLatitude:(float)placeLat placeLongitude:(float)placeLng
{
    float latDiff = deviceLatitude - placeLat;
    float lngDiff = deviceLongitude - placeLng;
    float latSquared = powf(latDiff, 2);
    float lngSquared = powf(lngDiff, 2);
    float distanceInMiles = sqrtf(latSquared + lngSquared) * (10000/90) * .621371;
    float distance = [[NSString stringWithFormat:@"%.2f", distanceInMiles] floatValue];
    
    return distance;
}

-(NSMutableArray *)getOpenNow
{
    NSLog(@"got openNow from queryController");
    return openNow;
}

-(NSMutableArray *)getOpenLater
{
    NSLog(@"got openLater from queryController");
    return openLater;
}

@end