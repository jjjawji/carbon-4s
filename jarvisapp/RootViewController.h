#import <UIKit/UIKit.h>

@interface RootViewController : UIViewController <UIWebViewDelegate>
- (void)fetchReminders;
- (void)fetchRemindersWithCompletion:(void (^)(BOOL gotNew))completion;
@end
