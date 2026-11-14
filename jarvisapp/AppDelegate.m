#import "AppDelegate.h"
#import "RootViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    CGRect frame = CGRectMake(0, 0, 320, 480);
    self.window = [[UIWindow alloc] initWithFrame:frame];
    RootViewController *root = [[RootViewController alloc] init];
    self.root = root;
    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];

    if ([application respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        UIUserNotificationType types = UIUserNotificationTypeAlert | UIUserNotificationTypeSound;
        [application registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:types categories:nil]];
    }
    [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    [application setIdleTimerDisabled:YES];
    [self scheduleDailyBriefing];
    return YES;
}

- (void)scheduleDailyBriefing {
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDate *now = [NSDate date];
    NSDateComponents *comp = [cal components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:now];
    comp.hour = 8;
    comp.minute = 0;
    comp.second = 0;
    NSDate *fire = [cal dateFromComponents:comp];
    if ([fire timeIntervalSinceDate:now] < 0) {
        fire = [cal dateByAddingUnit:NSCalendarUnitDay value:1 toDate:fire options:0];
    }
    UILocalNotification *daily = [[UILocalNotification alloc] init];
    daily.fireDate = fire;
    daily.repeatInterval = NSCalendarUnitDay;
    daily.alertBody = @"Good morning. Tap for your briefing.";
    daily.soundName = UILocalNotificationDefaultSoundName;
    daily.userInfo = @{@"briefing": @YES};
    [[UIApplication sharedApplication] scheduleLocalNotification:daily];
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    if ([notification.userInfo[@"briefing"] boolValue]) {
        if ([self.root respondsToSelector:@selector(sendBriefing)]) {
            [self.root sendBriefing];
        }
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    if ([self.root respondsToSelector:@selector(fetchReminders)]) {
        [self.root fetchReminders];
    }
}

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    if ([self.root respondsToSelector:@selector(fetchRemindersWithCompletion:)]) {
        [self.root fetchRemindersWithCompletion:^(BOOL gotNew) {
            completionHandler(gotNew ? UIBackgroundFetchResultNewData : UIBackgroundFetchResultNoData);
        }];
    } else {
        completionHandler(UIBackgroundFetchResultNoData);
    }
}

@end
