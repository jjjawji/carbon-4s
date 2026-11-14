#import "AppDelegate.h"
#import "RootViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    RootViewController *root = [[RootViewController alloc] init];
    self.root = root;
    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];

    if ([application respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        UIUserNotificationType types = UIUserNotificationTypeAlert | UIUserNotificationTypeSound;
        [application registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:types categories:nil]];
    }
    [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    return YES;
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
