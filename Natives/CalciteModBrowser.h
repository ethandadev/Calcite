#import <UIKit/UIKit.h>

/// Searchable Modrinth browser. Installs the newest compatible file (plus required
/// dependencies) into the selected profile's mods folder.
@interface CalciteModBrowser : UITableViewController <UISearchBarDelegate>
+ (void)presentFrom:(UIViewController *)presenter;
@end
