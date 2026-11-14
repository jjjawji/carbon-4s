#import "RootViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface RootViewController ()
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, copy) NSString *baseURL;
@property (nonatomic, copy) NSString *token;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, strong) UIButton *micButton;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) AVSpeechSynthesizer *speaker;
@property (nonatomic, assign) BOOL pageLoaded;
@end

@implementation RootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.063 green:0.086 blue:0.353 alpha:1.0];

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

    self.webView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 20, 320, 404)];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.delegate = self;
    self.webView.opaque = NO;
    self.webView.backgroundColor = [UIColor colorWithRed:0.063 green:0.086 blue:0.353 alpha:1.0];
    self.webView.scrollView.bounces = NO;
    self.webView.scrollView.showsVerticalScrollIndicator = NO;
    self.webView.dataDetectorTypes = 0;
    [self.view addSubview:self.webView];

    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, 424, 320, 56)];
    bar.backgroundColor = [UIColor colorWithRed:0.043 green:0.063 blue:0.271 alpha:1.0];
    bar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:bar];

    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 0.5)];
    line.backgroundColor = [UIColor colorWithRed:0.184 green:0.231 blue:0.647 alpha:1.0];
    [bar addSubview:line];

    self.micButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.micButton.frame = CGRectMake(16, 8, 120, 40);
    self.micButton.layer.cornerRadius = 20;
    self.micButton.backgroundColor = [UIColor colorWithRed:1.0 green:0.353 blue:0.212 alpha:1.0];
    [self.micButton setTitle:@"Talk" forState:UIControlStateNormal];
    [self.micButton setTitleColor:[UIColor colorWithRed:0.063 green:0.086 blue:0.353 alpha:1.0] forState:UIControlStateNormal];
    self.micButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.micButton addTarget:self action:@selector(toggleRecording) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:self.micButton];

    UIButton *reload = [UIButton buttonWithType:UIButtonTypeCustom];
    reload.frame = CGRectMake(268, 6, 44, 44);
    reload.layer.cornerRadius = 22;
    reload.backgroundColor = [UIColor clearColor];
    [reload setTitleColor:[UIColor colorWithRed:0.725 green:0.745 blue:0.949 alpha:1.0] forState:UIControlStateNormal];
    [reload setTitle:@"\u21BB" forState:UIControlStateNormal];
    reload.titleLabel.font = [UIFont systemFontOfSize:22];
    [reload addTarget:self action:@selector(loadJarvis) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:reload];

    self.hintLabel = [[UILabel alloc] initWithFrame:CGRectMake(148, 6, 116, 44)];
    self.hintLabel.text = @"Tap Talk to speak";
    self.hintLabel.font = [UIFont fontWithName:@"Menlo-Regular" size:10] ?: [UIFont systemFontOfSize:10];
    self.hintLabel.textColor = [UIColor colorWithRed:0.725 green:0.745 blue:0.949 alpha:1.0];
    self.hintLabel.numberOfLines = 2;
    [bar addSubview:self.hintLabel];

    self.speaker = [[AVSpeechSynthesizer alloc] init];

    [self loadJarvis];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)loadJarvis {
    NSString *base = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"JarvisURL"];
    NSString *urlString = [NSString stringWithFormat:@"%@&cb=%lld", base ?: @"", (long long)([[NSDate date] timeIntervalSince1970])];
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) { return; }
    self.loading = YES;
    NSURLRequest *request = [NSURLRequest requestWithURL:url
                                             cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                         timeoutInterval:20];
    [self.webView loadRequest:request];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    self.loading = NO;
    self.pageLoaded = YES;
    [self fetchReminders];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    self.loading = NO;
    if (error.code == NSURLErrorCancelled) { return; }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.loading) { [self loadJarvis]; }
    });
}

#pragma mark - Voice

- (void)toggleRecording {
    if (self.recorder && self.recorder.isRecording) {
        [self stopRecording];
        return;
    }
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryRecord error:nil];
    [session requestRecordPermission:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!granted) {
                self.hintLabel.text = @"microphone denied";
                return;
            }
            [self startRecording];
        });
    }];
}

- (void)startRecording {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"jarvis.wav"];
    NSDictionary *settings = @{
        AVFormatIDKey: @(kAudioFormatLinearPCM),
        AVSampleRateKey: @16000.0,
        AVNumberOfChannelsKey: @1,
        AVLinearPCMBitDepthKey: @16,
        AVLinearPCMIsFloatKey: @NO,
        AVLinearPCMIsBigEndianKey: @NO
    };
    NSError *error = nil;
    self.recorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:path] settings:settings error:&error];
    if (error || ![self.recorder record]) {
        self.hintLabel.text = @"recorder error";
        self.recorder = nil;
        return;
    }
    self.micButton.backgroundColor = [UIColor colorWithRed:0.953 green:0.929 blue:0.878 alpha:1.0];
    [self.micButton setTitleColor:[UIColor colorWithRed:0.063 green:0.086 blue:0.353 alpha:1.0] forState:UIControlStateNormal];
    [self.micButton setTitle:@"Stop" forState:UIControlStateNormal];
    self.hintLabel.text = @"Listening. Tap Stop when done.";
}

- (void)stopRecording {
    [self.recorder stop];
    self.recorder = nil;
    self.micButton.backgroundColor = [UIColor colorWithRed:1.0 green:0.353 blue:0.212 alpha:1.0];
    [self.micButton setTitleColor:[UIColor colorWithRed:0.063 green:0.086 blue:0.353 alpha:1.0] forState:UIControlStateNormal];
    [self.micButton setTitle:@"Talk" forState:UIControlStateNormal];
    self.hintLabel.text = @"Thinking";

    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"jarvis.wav"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data.length == 0) {
        self.hintLabel.text = @"Tap Talk to speak";
        return;
    }
    NSString *encoded = [data base64EncodedStringWithOptions:0];
    NSDictionary *payload = @{@"audio": encoded, @"format": @"wav"};
    NSData *body = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];

    NSString *endpoint = [NSString stringWithFormat:@"%@/api/voice", self.baseURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:endpoint]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:self.token forHTTPHeaderField:@"X-Jarvis-Token"];
    [request setHTTPBody:body];
    request.timeoutInterval = 90;

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *respData, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (respData.length == 0) {
                self.hintLabel.text = @"network error";
                return;
            }
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:respData options:0 error:nil];
            NSString *heard = [json isKindOfClass:[NSDictionary class]] ? json[@"text"] : nil;
            NSString *reply = [json isKindOfClass:[NSDictionary class]] ? json[@"reply"] : nil;
            if (heard.length > 0) { [self injectMessage:@"user" text:heard]; }
            if (reply.length > 0) {
                [self injectMessage:@"jarvis" text:reply];
                [self speak:reply];
            }
            self.hintLabel.text = @"Tap Talk to speak";
        });
    }] resume];
}

- (void)injectMessage:(NSString *)role text:(NSString *)text {
    NSData *d = [NSJSONSerialization dataWithJSONObject:@[text ?: @""] options:0 error:nil];
    NSString *arr = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    NSString *js = [NSString stringWithFormat:@"window.jarvisAdd && window.jarvisAdd('%@', %@[0]);", role, arr];
    [self.webView stringByEvaluatingJavaScriptFromString:js];
}

- (void)speak:(NSString *)text {
    if (text.length == 0) { return; }
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    [session setActive:YES error:nil];
    NSString *clean = [text stringByReplacingOccurrencesOfString:@"*" withString:@""];
    clean = [clean stringByReplacingOccurrencesOfString:@"`" withString:@""];
    AVSpeechUtterance *u = [AVSpeechUtterance speechUtteranceWithString:clean];
    u.rate = AVSpeechUtteranceDefaultSpeechRate;
    u.pitchMultiplier = 0.92;
    AVSpeechSynthesisVoice *voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"en-GB"];
    if (voice) { u.voice = voice; }
    [self.speaker speakUtterance:u];
}

#pragma mark - Reminders

- (void)fetchReminders {
    [self fetchRemindersWithCompletion:nil];
}

- (void)sendBriefing {
    [self.webView stringByEvaluatingJavaScriptFromString:@"window.jarvisSend && window.jarvisSend('Give me a briefing');"];
}

- (void)fetchRemindersWithCompletion:(void (^)(BOOL))completion {
    if (!self.pageLoaded || self.baseURL.length == 0 || self.token.length == 0) {
        if (completion) { completion(NO); }
        return;
    }
    NSString *encodedToken = [self.token stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"%@/api/reminders?mark=0&token=%@", self.baseURL, encodedToken];
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
                NSMutableArray *dueSoon = [NSMutableArray array];
                NSMutableDictionary *announced = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"jarvisAnnounced"] mutableCopy];
                if (!announced) { announced = [NSMutableDictionary dictionary]; }
                UIApplication *app = [UIApplication sharedApplication];
                for (NSDictionary *item in items) {
                    if (![item isKindOfClass:[NSDictionary class]]) { continue; }
                    NSTimeInterval due = [item[@"due"] doubleValue];
                    NSString *text = item[@"text"];
                    if (due < now - 900 || text.length == 0) { continue; }
                    if (due <= now + 60) {
                        NSString *akey = [NSString stringWithFormat:@"%@", item[@"id"] ?: text];
                        if (!announced[akey]) {
                            [dueSoon addObject:[NSString stringWithFormat:@"Reminder: %@", text]];
                            announced[akey] = @(now);
                        }
                    }
                    if (due > now + 5) {
                        NSNumber *rid = item[@"id"] ?: @0;
                        for (UILocalNotification *old in [app.scheduledLocalNotifications copy]) {
                            if ([old.userInfo[@"reminder_id"] isEqual:rid]) { [app cancelLocalNotification:old]; }
                        }
                        UILocalNotification *note = [[UILocalNotification alloc] init];
                        note.fireDate = [NSDate dateWithTimeIntervalSince1970:due];
                        note.alertBody = text;
                        note.soundName = UILocalNotificationDefaultSoundName;
                        note.userInfo = @{@"jarvis": @YES, @"reminder_id": rid};
                        [app scheduleLocalNotification:note];
                        gotNew = YES;
                    }
                }
                for (NSString *k in [announced allKeys]) {
                    if (now - [announced[k] doubleValue] > 7 * 86400) { [announced removeObjectForKey:k]; }
                }
                [[NSUserDefaults standardUserDefaults] setObject:announced forKey:@"jarvisAnnounced"];
                if (dueSoon.count > 0) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        for (NSString *msg in dueSoon) {
                            [self injectMessage:@"jarvis" text:msg];
                            [self speak:msg];
                        }
                    });
                }
            }
        }
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(gotNew); });
        }
    }] resume];
}

@end
