#import "CalciteModBrowser.h"
#import "PLProfiles.h"
#import "LauncherPreferences.h"
#import "ios_uikit_bridge.h"
#import "utils.h"

@interface CalciteModBrowser ()
@property(nonatomic) NSArray<NSDictionary *> *hits;
@property(nonatomic) NSString *loader, *mcVersion, *modsDir;
@property(nonatomic) NSUInteger searchToken;
@property(nonatomic) UISearchBar *searchBar;
@end

@implementation CalciteModBrowser

+ (void)presentFrom:(UIViewController *)presenter {
    NSString *versionId = PLProfiles.current.selectedProfile[@"lastVersionId"] ?: @"";
    if ([versionId isEqualToString:@"latest-release"] || [versionId isEqualToString:@"latest-snapshot"] || versionId.length == 0) {
        showDialog(@"Pick a modded profile", @"Select a Fabric, Quilt, Forge or NeoForge profile first. Vanilla profiles can't load mods.");
        return;
    }
    CalciteModBrowser *vc = [[CalciteModBrowser alloc] initWithStyle:UITableViewStylePlain];
    NSString *lower = versionId.lowercaseString;
    vc.loader = [lower containsString:@"neoforge"] ? @"neoforge" : [lower containsString:@"forge"] ? @"forge"
              : [lower containsString:@"quilt"] ? @"quilt" : @"fabric";
    BOOL lastIsMC = [vc.loader isEqualToString:@"fabric"] || [vc.loader isEqualToString:@"quilt"];
    NSString *found = nil;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"^\\d+\\.\\d+(\\.\\d+)?$" options:0 error:nil];
    NSArray *parts = [versionId componentsSeparatedByString:@"-"];
    for (NSString *p in (lastIsMC ? parts.reverseObjectEnumerator.allObjects : parts)) {
        if ([re numberOfMatchesInString:p options:0 range:NSMakeRange(0, p.length)]) { found = p; break; }
    }
    vc.mcVersion = found ?: versionId;
    NSString *gameDir = [NSString stringWithFormat:@"%s/instances/%@/%@", getenv("AME_HOME"),
        getPrefObject(@"general.game_directory"), [PLProfiles resolveKeyForCurrentProfile:@"gameDir"]];
    vc.modsDir = [[gameDir stringByStandardizingPath] stringByAppendingPathComponent:@"mods"];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [presenter presentViewController:nav animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [NSString stringWithFormat:@"Mods · %@ %@", [self.loader capitalizedString], self.mcVersion];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
        target:self action:@selector(close)];
    self.searchBar = [UISearchBar new];
    self.searchBar.placeholder = @"Search Modrinth";
    self.searchBar.delegate = self;
    self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    [self.searchBar sizeToFit];
    self.tableView.tableHeaderView = self.searchBar;
    [self runSearch:@""];
}

- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }

+ (NSData *)fetch:(NSURL *)url {
    __block NSData *result = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.timeoutInterval = 30;
    [req setValue:@"ethandadev/Calcite (https://github.com/ethandadev/Calcite)" forHTTPHeaderField:@"User-Agent"];
    [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (!e && [(NSHTTPURLResponse *)r statusCode] == 200) result = d;
        dispatch_semaphore_signal(sem);
    }] resume];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}

static NSString *enc(NSString *s) {
    return [s stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
}

- (void)runSearch:(NSString *)text {
    NSUInteger token = ++self.searchToken;
    NSString *facets = [NSString stringWithFormat:@"[[\"project_type:mod\"],[\"categories:%@\"],[\"versions:%@\"]]", self.loader, self.mcVersion];
    NSString *url = [NSString stringWithFormat:@"https://api.modrinth.com/v2/search?limit=40&index=%@&query=%@&facets=%@",
        text.length ? @"relevance" : @"downloads", enc(text), enc(facets)];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSData *d = [CalciteModBrowser fetch:[NSURL URLWithString:url]];
        NSDictionary *json = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
        NSArray *hits = [json[@"hits"] isKindOfClass:NSArray.class] ? json[@"hits"] : @[];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (token != self.searchToken) return;
            self.hits = hits;
            [self.tableView reloadData];
        });
    });
}

- (void)searchBar:(UISearchBar *)bar textDidChange:(NSString *)text {
    NSUInteger token = self.searchToken + 1;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (token == self.searchToken + 1) [self runSearch:text];
    });
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)bar { [bar resignFirstResponder]; [self runSearch:bar.text]; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return self.hits.count; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"mod"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"mod"];
    NSDictionary *h = self.hits[ip.row];
    cell.textLabel.text = h[@"title"];
    cell.detailTextLabel.text = h[@"description"];
    cell.detailTextLabel.numberOfLines = 2;
    cell.accessoryType = UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSDictionary *h = self.hits[ip.row];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:h[@"title"]
        message:[NSString stringWithFormat:@"%@\n\n%@ downloads", h[@"description"], h[@"downloads"]] preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Install" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
        [self install:h[@"project_id"] title:h[@"title"]];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

/// Installs project + required deps. Returns installed names; failures go in `failed`.
- (void)installProject:(NSString *)pid depth:(int)depth done:(NSMutableSet *)done
             installed:(NSMutableArray *)ok failed:(NSMutableArray *)bad {
    if ([done containsObject:pid] || depth > 3) return;
    [done addObject:pid];
    NSString *q = [NSString stringWithFormat:@"https://api.modrinth.com/v2/project/%@/version?loaders=%@&game_versions=%@",
        pid, enc([NSString stringWithFormat:@"[\"%@\"]", self.loader]), enc([NSString stringWithFormat:@"[\"%@\"]", self.mcVersion])];
    NSData *d = [CalciteModBrowser fetch:[NSURL URLWithString:q]];
    NSArray *vers = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
    if (![vers isKindOfClass:NSArray.class] || !vers.count) { [bad addObject:pid]; return; }
    NSDictionary *v = vers[0], *file = nil;
    for (NSDictionary *f in v[@"files"]) if ([f[@"primary"] boolValue]) { file = f; break; }
    file = file ?: [v[@"files"] firstObject];
    if (!file) { [bad addObject:pid]; return; }
    [NSFileManager.defaultManager createDirectoryAtPath:self.modsDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *dest = [self.modsDir stringByAppendingPathComponent:file[@"filename"]];
    NSString *name = file[@"filename"];
    if (![NSFileManager.defaultManager fileExistsAtPath:dest]) {
        NSData *jar = [CalciteModBrowser fetch:[NSURL URLWithString:file[@"url"]]];
        if (!jar || ![jar writeToFile:dest atomically:YES]) { [bad addObject:name]; return; }
    }
    [ok addObject:name];
    for (NSDictionary *dep in v[@"dependencies"]) {
        if ([dep[@"dependency_type"] isEqualToString:@"required"] && [dep[@"project_id"] isKindOfClass:NSString.class]) {
            [self installProject:dep[@"project_id"] depth:depth + 1 done:done installed:ok failed:bad];
        }
    }
}

- (void)install:(NSString *)pid title:(NSString *)title {
    UIAlertController *p = [UIAlertController alertControllerWithTitle:@"Installing" message:title preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:p animated:YES completion:nil];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray *ok = [NSMutableArray new], *bad = [NSMutableArray new];
        [self installProject:pid depth:0 done:[NSMutableSet new] installed:ok failed:bad];
        dispatch_async(dispatch_get_main_queue(), ^{
            [p dismissViewControllerAnimated:YES completion:^{
                NSMutableString *m = [NSMutableString new];
                if (ok.count) [m appendFormat:@"Added: %@", [ok componentsJoinedByString:@", "]];
                if (bad.count) [m appendFormat:@"\n\nCouldn't get: %@ (no build for %@ %@).", [bad componentsJoinedByString:@", "], self.loader, self.mcVersion];
                showDialog(ok.count ? @"Installed" : @"Not available", m);
            }];
        });
    });
}

@end
