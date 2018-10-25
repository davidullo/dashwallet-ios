//
//  DWAppDelegate.m
//  DashWallet
//
//  Created by Aaron Voisine for BreadWallet on 5/8/13.
//  Copyright (c) 2013 Aaron Voisine <voisine@gmail.com>
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "DWAppDelegate.h"
#import <DashSync/DashSync.h>
#import <UserNotifications/UserNotifications.h>

#if DASH_TESTNET
#pragma message "testnet build"
#endif

#if SNAPSHOT
#pragma message "snapshot build"
#endif

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

@interface DWAppDelegate ()

// the nsnotificationcenter observer for wallet balance
@property id balanceObserver;

// the most recent balance as received by notification
@property uint64_t balance;

@end

@implementation DWAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.

    // use background fetch to stay synced with the blockchain
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];

    UIPageControl.appearance.pageIndicatorTintColor = [UIColor lightGrayColor];
    UIPageControl.appearance.currentPageIndicatorTintColor = [UIColor blueColor];
    
    //This will set the Navigation Bar to the same color as the background and remove unwanted features.
    [[UINavigationBar appearance] setBarTintColor:UIColorFromRGB(0x00A0EA)];
    [[UINavigationBar appearance] setTranslucent:NO];
    [[UINavigationBar appearance] setShadowImage:[[UIImage alloc] init]];
    [[UINavigationBar appearance] setBackgroundImage:[[UIImage alloc] init]
                                      forBarPosition:UIBarPositionAny
                                          barMetrics:UIBarMetricsDefault];
    
    [[UIBarButtonItem appearanceWhenContainedInInstancesOfClasses:@[[UINavigationBar class]]]
     setTitleTextAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:18]}
     forState:UIControlStateNormal];
    UIFont * titleBarFont = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    [[UINavigationBar appearance] setTitleTextAttributes:@{
                                                           NSFontAttributeName:titleBarFont,
                                                           NSForegroundColorAttributeName: [UIColor whiteColor],
                                                           }];
    
    UIImage * backImage = [[UIImage imageNamed:@"back-button"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    [[UINavigationBar appearance] setBackIndicatorImage:backImage];
    [[UINavigationBar appearance] setBackIndicatorTransitionMaskImage:backImage];

    if (launchOptions[UIApplicationLaunchOptionsURLKey]) {
        NSData *file = [NSData dataWithContentsOfURL:launchOptions[UIApplicationLaunchOptionsURLKey]];

        if (file.length > 0) {
            [[NSNotificationCenter defaultCenter] postNotificationName:BRFileNotification object:nil
             userInfo:@{@"file":file}];
        }
    }

    // start the event manager
    [[DSEventManager sharedEventManager] up];
    
    [DSWalletManager sharedInstance];

    //TODO: bitcoin protocol/payment protocol over multipeer connectivity

    //TODO: accessibility for the visually impaired

    //TODO: fast wallet restore using webservice and/or utxo p2p message

    //TODO: ask user if they need to sweep to a new wallet when restoring because it was compromised

    //TODO: figure out deterministic builds/removing app sigs: http://www.afp548.com/2012/06/05/re-signining-ios-apps/

    //TODO: implement importing of private keys split with shamir's secret sharing:
    //      https://github.com/cetuscetus/btctool/blob/bip/bip-xxxx.mediawiki

    [BRPhoneWCSessionManager sharedInstance];
    
    [DSShapeshiftManager sharedInstance];
    
    // observe balance and create notifications
    [self setupBalanceNotification:application];
    [self setupPreferenceDefaults];
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (self.balance == UINT64_MAX) self.balance = [DSWalletManager sharedInstance].wallet.balance;
        [self registerForPushNotifications];
    });
}

- (void)applicationWillResignActive:(UIApplication *)application
{
//    BRAPIClient *client = [BRAPIClient sharedClient];
//    [client.kv sync:^(NSError *err) {
//        NSLog(@"Finished syncing. err=%@", err);
//    }];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
//    [self updatePlatformOnComplete:^{
//        NSLog(@"[DWAppDelegate] updatePlatform completed!");
//    }];
}

// Applications may reject specific types of extensions based on the extension point identifier.
// Constants representing common extension point identifiers are provided further down.
// If unimplemented, the default behavior is to allow the extension point identifier.
- (BOOL)application:(UIApplication *)application
shouldAllowExtensionPointIdentifier:(NSString *)extensionPointIdentifier
{
    return NO; // disable extensions such as custom keyboards for security purposes
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication
annotation:(id)annotation
{
    if (! [url.scheme isEqual:@"dash"] && ! [url.scheme isEqual:@"dashwallet"]) {
        UIAlertController * alert = [UIAlertController
                                     alertControllerWithTitle:@"Not a dash URL"
                                     message:url.absoluteString
                                     preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* okButton = [UIAlertAction
                                       actionWithTitle:NSLocalizedString(@"ok", nil)
                                       style:UIAlertActionStyleCancel
                                       handler:^(UIAlertAction * action) {
                                       }];

        [alert addAction:okButton];
        [[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:alert animated:YES completion:nil];
        
        return NO;
    }
    

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC/10), dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:BRURLNotification object:nil userInfo:@{@"url":url}];
    });

    return YES;
}

- (void)application:(UIApplication *)application
performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    __block id protectedObserver = nil, syncFinishedObserver = nil, syncFailedObserver = nil;
    __block void (^completion)(UIBackgroundFetchResult) = completionHandler;
    void (^cleanup)(void) = ^() {
        completion = nil;
        if (protectedObserver) [[NSNotificationCenter defaultCenter] removeObserver:protectedObserver];
        if (syncFinishedObserver) [[NSNotificationCenter defaultCenter] removeObserver:syncFinishedObserver];
        if (syncFailedObserver) [[NSNotificationCenter defaultCenter] removeObserver:syncFailedObserver];
        protectedObserver = syncFinishedObserver = syncFailedObserver = nil;
    };

    if ([DWEnvironment sharedInstance].currentChainPeerManager.syncProgress >= 1.0) {
        NSLog(@"background fetch already synced");
        if (completion) completion(UIBackgroundFetchResultNoData);
        return;
    }

    // timeout after 25 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 25*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (completion) {
            NSLog(@"background fetch timeout with progress: %f", [DWEnvironment sharedInstance].currentChainPeerManager.syncProgress);
            completion(([DWEnvironment sharedInstance].currentChainPeerManager.syncProgress > 0.1) ? UIBackgroundFetchResultNewData :
                       UIBackgroundFetchResultFailed);
            cleanup();
        }
        //TODO: disconnect
    });

    protectedObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationProtectedDataDidBecomeAvailable object:nil
        queue:nil usingBlock:^(NSNotification *note) {
            NSLog(@"background fetch protected data available");
            [[DSPeerManager sharedInstance] connect];
        }];

    syncFinishedObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSPeerManagerSyncFinishedNotification object:nil
        queue:nil usingBlock:^(NSNotification *note) {
            NSLog(@"background fetch sync finished");
            if (completion) completion(UIBackgroundFetchResultNewData);
            cleanup();
        }];

    syncFailedObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSPeerManagerSyncFailedNotification object:nil
        queue:nil usingBlock:^(NSNotification *note) {
            NSLog(@"background fetch sync failed");
            if (completion) completion(UIBackgroundFetchResultFailed);
            cleanup();
        }];

    NSLog(@"background fetch starting");
    [[DSPeerManager sharedInstance] connect];

    // sync events to the server
    [[DSEventManager sharedEventManager] sync];
    
//    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"has_alerted_buy_dash"] == NO &&
//        [WKWebView class] && [[BRAPIClient sharedClient] featureEnabled:BRFeatureFlagsBuyDash] &&
//        [UIApplication sharedApplication].applicationIconBadgeNumber == 0) {
//        [UIApplication sharedApplication].applicationIconBadgeNumber = 1;
//    }
}

- (void)setupBalanceNotification:(UIApplication *)application
{
    DSWalletManager *manager = [DSWalletManager sharedInstance];
    
    self.balance = UINT64_MAX; // this gets set in applicationDidBecomActive:
    
    self.balanceObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSWalletBalanceChangedNotification object:nil queue:nil
        usingBlock:^(NSNotification * _Nonnull note) {
            if (self.balance < manager.wallet.balance) {
                BOOL send = [[NSUserDefaults standardUserDefaults] boolForKey:USER_DEFAULTS_LOCAL_NOTIFICATIONS_KEY];
                NSString *noteText = [NSString stringWithFormat:NSLocalizedString(@"received %@ (%@)", nil),
                                      [manager stringForDashAmount:manager.wallet.balance - self.balance],
                                      [manager localCurrencyStringForDashAmount:manager.wallet.balance - self.balance]];
                
                NSLog(@"local notifications enabled=%d", send);
                
                // send a local notification if in the background
                if (application.applicationState == UIApplicationStateBackground ||
                    application.applicationState == UIApplicationStateInactive) {
                    
                    if (send) {
                        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
                        content.body = noteText;
                        content.sound = [UNNotificationSound soundNamed:@"coinflip"];
                        
                        // 4. update application icon badge number
                        content.badge = [NSNumber numberWithInteger:([UIApplication sharedApplication].applicationIconBadgeNumber + 1)];
                        // Deliver the notification in five seconds.
                        UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger
                                                                      triggerWithTimeInterval:1.0f
                                                                      repeats:NO];
                        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:@"Now"
                                                                                              content:content
                                                                                              trigger:trigger];
                        /// 3. schedule localNotification
                        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
                        [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
                            if (!error) {
                                NSLog(@"sent local notification %@", note);
                            }
                        }];
                    }
                }
                
                // send a custom notification to the watch if the watch app is up
                [[BRPhoneWCSessionManager sharedInstance] notifyTransactionString:noteText];
            }
            
            self.balance = manager.wallet.balance;
        }];
}

- (void)setupPreferenceDefaults {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    
    // turn on local notifications by default
    if (! [defs boolForKey:USER_DEFAULTS_LOCAL_NOTIFICATIONS_SWITCH_KEY]) {
        NSLog(@"enabling local notifications by default");
        [defs setBool:true forKey:USER_DEFAULTS_LOCAL_NOTIFICATIONS_SWITCH_KEY];
        [defs setBool:true forKey:USER_DEFAULTS_LOCAL_NOTIFICATIONS_KEY];
    }
}

- (void)registerForPushNotifications {
    BOOL hasNotification = [UNNotificationSettings class] != nil;
    NSString *userDefaultsKey = @"has_asked_for_push";
    BOOL hasAskedForPushNotification = [[NSUserDefaults standardUserDefaults] boolForKey:userDefaultsKey];
    
    if (hasAskedForPushNotification && hasNotification) {
        UNAuthorizationOptions options = (UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionAlert);
        [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:options completionHandler:^(BOOL granted, NSError * _Nullable error) {
            
        }];
    }
}

- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier
  completionHandler:(void (^)(void))completionHandler
{
    NSLog(@"Handle events for background url session; identifier=%@", identifier);
}

- (void)dealloc
{
    if (self.balanceObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.balanceObserver];
}

@end
