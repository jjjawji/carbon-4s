#import "RootViewController.h"

@interface RootViewController ()
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, copy) NSString *baseURL;
@property (nonatomic, copy) NSString *token;
@property (nonatomic, assign) BOOL loading;
@end

@implementation RootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    NSString *urlString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"JarvisURL"];
    NSURLComponents *comp = [NSURLComponents componentsWithString:urlString ?: @""];
    self.token = @"";
    for (NSURLQueryItem *item in comp.queryItems) {
        if ([item.name isEqualToString:@"token"]) { self.token = item.value ?: @""; }
    }
    NSString *host = comp.host ?: @"192.168.1.2";
    NSString *scheme = comp.scheme ?: @"http";
    if (comp.port) {
        self.baseURL = [NSString stringWithFormat:@"%@://%@:%@", scheme, host, comp.port];
    } else {
        self.baseURL = [NSString stringWithFormat:@"%@://%@", scheme, host];
    }

    self.webView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.delegate = self;
    self.webView.opaque = NO;
    self.webView.backgroundColor = [UIColor blackColor];
    self.webView.scrollView.bounces = NO;
    self.webView.scrollView.showsVerticalScrollIndicator = NO;
    self.webView.dataDetectorTypes = 0;
    [self.view addSubview:self.webView];

    [self loadJarvis];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)loadJarvis {
    NSString *urlString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"JarvisURL"];
    NSURL *url = [NSURL URLWithString:urlString ?: @""];
    if (!url) { return; }
    self.loading = YES;
    [self.webView loadRequest:[NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20]];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    self.loading = NO;
    [self fetchReminders];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    self.loading = NO;
    if (error.code == NSURLErrorCancelled) { return; }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.loading) { [self loadJarvis]; }
    });
}

- (void)fetchReminders {
    [self fetchRemindersWithCompletion:nil];
}

- (void)fetchRemindersWithCompletion:(void (^)(BOOL))completion {
    if (self.baseURL.length == 0 || self.token.length == 0) {
        if (completion) { completion(NO); }
        return;
    }
    NSString *encodedToken = [self.token stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"%@/api/reminders?mark=1&token=%@", self.baseURL, encodedToken];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [request setValue:self.token forHTTPHeaderField:@"X-Jarvis-Token"];
    request.timeoutInterval = 15;

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        BOOL gotNew = NO;
        if (data.length > 0) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSArray *items = [json isKindOfClass:[NSDictionary class]] ? json[@"reminders"] : nil;
            if ([items isKindOfClass:[NSArray class]]) {
                NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
                for (NSDictionary *item in items) {
                    if (![item isKindOfClass:[NSDictionary class]]) { continue; }
                    NSTimeInterval due = [item[@"due"] doubleValue];
                    NSString *text = item[@"text"];
                    if (due < now + 5 || text.length == 0) { continue; }
                    UILocalNotification *note = [[UILocalNotification alloc] init];
                    note.fireDate = [NSDate dateWithTimeIntervalSince1970:due];
                    note.alertBody = text;
                    note.soundName = UILocalNotificationDefaultSoundName;
                    note.userInfo = @{@"jarvis": @YES};
                    [[UIApplication sharedApplication] scheduleLocalNotification:note];
                    gotNew = YES;
                }
            }
        }
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(gotNew); });
        }
    }] resume];
}

@end
